import 'dart:async';

import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import '../domain/workout_audio_port.dart';
import '../domain/workout_feedback_event.dart';
import '../domain/workout_audio_trace.dart';

/// Session-scoped audio policy. Consume only current analyzed pose batches;
/// this controller never queues corrections from previous frames.
class WorkoutAudioController {
  WorkoutAudioController({
    required WorkoutAudioPort port,
    AudioCueArbiter? arbiter,
    this.pendingStartTimeout = const Duration(milliseconds: 500),
    this.trace,
    this.boundedStarts = false,
  })  : assert(pendingStartTimeout > Duration.zero),
        _port = port,
        _arbiter = arbiter ?? AudioCueArbiter();

  final WorkoutAudioPort _port;
  final AudioCueArbiter _arbiter;
  final WorkoutAudioTrace? trace;
  final bool boundedStarts;
  int _requestSequence = 0;
  String? _activeRequestId;
  final Set<String> _seenEvents = {};
  WorkoutFeedbackEvent? _activeEvent;
  final Stopwatch _eventWait = Stopwatch();
  int _eventBudgetMicros = 0;

  /// Audio request validity while waiting to start; unrelated to pose freshness.
  final Duration pendingStartTimeout;
  WorkoutVoiceMode _voiceMode = WorkoutVoiceMode.muted;
  bool _paused = false;
  bool _foreground = true;
  bool _trackingAvailable = true;
  bool _closed = false;
  int _generation = 0;
  int? _lastInputMicros;
  CueRequest? _activeCue;
  bool _waitingForPlayback = false;
  Timer? _pendingTimeout;
  Future<void> _stopBarrier = Future.value();
  bool _stopPending = false;
  Future<void>? _closeFuture;

  CueRequest? get activeCue => _activeCue;
  bool get voiceEnabled => _voiceMode != WorkoutVoiceMode.muted;
  WorkoutVoiceMode get voiceMode => _voiceMode;
  bool get isClosed => _closed;
  AudioPlaybackOutcome? lastOutcome;
  Object? lastError;
  bool get _canPlay => !_closed && voiceEnabled && !_paused && _foreground;

  void applyPreferences(MemberPreferences preferences) =>
      setVoiceEnabled(preferences.voiceCoaching);

  void setVoiceEnabled(bool enabled) => setVoiceMode(
      enabled ? WorkoutVoiceMode.fullCoaching : WorkoutVoiceMode.muted);

  void setVoiceMode(WorkoutVoiceMode mode) {
    if (_closed || _voiceMode == mode) return;
    _voiceMode = mode;
    if (!voiceEnabled ||
        (mode == WorkoutVoiceMode.alertsOnly &&
            _activeCue?.priority == CuePriority.encouragement)) {
      _cancel();
    } else if (_canPlay && _port is PreparedWorkoutAudioPort) {
      unawaited(_warm());
    }
  }

  void pause() {
    if (_closed || _paused) return;
    _paused = true;
    _cancel();
  }

  void resume() {
    if (_closed || !_paused) return;
    _paused = false;
    if (_canPlay && _port is PreparedWorkoutAudioPort) unawaited(_warm());
  }

  /// Camera geometry/source replacement invalidates speech independently of
  /// manual pause; resuming needs a fresh observation rather than old events.
  void invalidateSource() {
    if (_closed) return;
    _trackingAvailable = false;
    _cancel(reason: 'source_invalidated');
  }

  void setForeground(bool foreground) {
    if (_closed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _cancel();
    } else if (_canPlay && _port is PreparedWorkoutAudioPort) {
      unawaited(_warm());
    }
  }

  /// [nowMicros] is a monotonic session/input timestamp, supplied by analysis.
  /// Duplicate and out-of-order frames are ignored. A tracking transition
  /// cancels stale speech; only explicit warning requests survive tracking loss.
  void consume(
    Iterable<CueRequest> cues, {
    required int nowMicros,
    required bool trackingAvailable,
    Iterable<WorkoutFeedbackEvent> events = const [],
    bool invalidateFeedback = false,
    int? observedAtMicros,
  }) {
    if (_closed ||
        nowMicros < 0 ||
        (_lastInputMicros != null && nowMicros <= _lastInputMicros!)) {
      return;
    }
    _lastInputMicros = nowMicros;
    final batch = cues.toList();
    if (_waitingForPlayback &&
        _activeEvent != null &&
        !_activeEvent!.isFresh(nowMicros)) {
      _cancel(reason: 'start_deadline');
    }
    if (invalidateFeedback && _activeEvent != null) {
      _cancel(reason: 'source_invalidated');
    }
    final eventByCue = <String, WorkoutFeedbackEvent>{};
    final requestByCue = <String, String>{};
    for (final event in events) {
      if (!_seenEvents.add(event.id)) continue;
      // Finite recent IDs plus monotonic input reject repeated snapshot events.
      if (_seenEvents.length > 64) _seenEvents.remove(_seenEvents.first);
      if (invalidateFeedback || !event.isFresh(nowMicros)) {
        trace?.record('dropped',
            requestId: event.id,
            cueId: event.cue.id,
            reason: 'stale_or_invalid');
        continue;
      }
      eventByCue[event.cue.id] = event;
      batch.add(event.cue);
      trace?.record('feedback_queued',
          requestId: event.id, cueId: event.cue.id);
    }
    // Event cues may be emitted for just one frame. Do not interrupt speech
    // already underway, but a request that has not started must remain current
    // throughout asynchronous stop/engine preparation.
    if (_waitingForPlayback &&
        _activeEvent == null &&
        _activeCue != null &&
        !batch.any((cue) =>
            cue.id == _activeCue!.id &&
            cue.text == _activeCue!.text &&
            cue.priority == _activeCue!.priority)) {
      _cancel();
    }
    if (_trackingAvailable != trackingAvailable) {
      _trackingAvailable = trackingAvailable;
      // A completed observation remains true during phase reacquisition or a
      // recoverable dropout. Explicit source loss/warnings still invalidate it.
      if (_activeEvent == null) _cancel(reason: 'tracking_transition');
    }
    _arbiter.clearPending();
    if (!_canPlay) {
      for (final event in eventByCue.values) {
        trace?.record('dropped',
            requestId: event.id, cueId: event.cue.id, reason: 'audio_disabled');
      }
      return;
    }
    for (final cue in batch) {
      if (cue.id.isEmpty || cue.text.trim().isEmpty) continue;
      if (_voiceMode == WorkoutVoiceMode.alertsOnly &&
          cue.priority == CuePriority.encouragement) {
        continue;
      }
      if (!trackingAvailable &&
          cue.priority != CuePriority.warning &&
          !eventByCue.containsKey(cue.id)) {
        continue;
      }
      final active = _activeCue;
      if (active != null &&
          (cue.id == active.id ||
              cue.priority.weight <= active.priority.weight)) {
        continue;
      }
      final requestId = eventByCue[cue.id]?.id ?? 'cue-${++_requestSequence}';
      requestByCue[cue.id] = requestId;
      if (!eventByCue.containsKey(cue.id)) {
        trace?.record('exercise_event_generated',
            requestId: requestId,
            cueId: cue.id,
            observedAtMicros: observedAtMicros ?? nowMicros);
        trace?.record('feedback_queued', requestId: requestId, cueId: cue.id);
      }
      _arbiter.submit(cue);
    }
    final selected = _arbiter.takeNext(nowMicros: nowMicros);
    _arbiter.clearPending();
    if (selected == null) {
      for (final event in eventByCue.values) {
        trace?.record('dropped',
            requestId: event.id,
            cueId: event.cue.id,
            reason: _canPlay ? 'priority_or_cooldown' : 'audio_disabled');
      }
      return;
    }
    for (final event
        in eventByCue.values.where((e) => e.cue.id != selected.id)) {
      trace?.record('dropped',
          requestId: event.id,
          cueId: event.cue.id,
          reason: 'arbitration_priority');
    }
    if (_activeCue != null) _cancel(reason: 'higher_priority');
    _activeCue = selected;
    _activeEvent = eventByCue[selected.id];
    _activeRequestId = requestByCue[selected.id];
    _eventBudgetMicros = _activeEvent == null
        ? pendingStartTimeout.inMicroseconds
        : _activeEvent!.expiresAtMicros - nowMicros;
    _eventWait
      ..reset()
      ..start();
    trace?.record('arbitration_selected',
        requestId: _activeRequestId, cueId: selected.id);
    _waitingForPlayback = true;
    final generation = _generation;
    final budget = _activeEvent == null
        ? pendingStartTimeout
        : Duration(microseconds: _eventBudgetMicros);
    _pendingTimeout = Timer(budget, () {
      if (generation == _generation && _waitingForPlayback) {
        _cancel(reason: 'start_deadline');
      }
    });
    unawaited(_play(selected, _generation));
  }

  Future<void> _play(CueRequest cue, int generation) async {
    await _stopBarrier;
    if (!_canPlay || generation != _generation) return;
    AudioPlaybackOutcome outcome;
    try {
      final prepared = _port;
      if (prepared is PreparedWorkoutAudioPort) {
        final available = await prepared.prepare();
        if (!_canPlay || generation != _generation) return;
        if (!available) {
          trace?.record('dropped',
              requestId: _activeRequestId,
              cueId: cue.id,
              reason: 'tts_unavailable');
          lastOutcome = AudioPlaybackOutcome.unavailable;
          _pendingTimeout?.cancel();
          _pendingTimeout = null;
          _waitingForPlayback = false;
          _activeCue = null;
          _activeEvent = null;
          _activeRequestId = null;
          return;
        }
      }
      _pendingTimeout?.cancel();
      _pendingTimeout = null;
      _waitingForPlayback = false;
      final event = _activeEvent;
      final remaining = _eventBudgetMicros - _eventWait.elapsedMicroseconds;
      if ((event != null || boundedStarts) && remaining <= 0) {
        _cancel(reason: 'start_deadline');
        return;
      }
      trace?.record('tts_dispatch', requestId: _activeRequestId, cueId: cue.id);
      final timed = _port;
      outcome =
          (event != null || boundedStarts) && timed is TimedWorkoutAudioPort
              ? await timed.playCurrent(cue,
                  requestId: _activeRequestId!,
                  remainingStartTime: Duration(microseconds: remaining))
              : await _port.play(cue);
    } catch (error) {
      outcome = AudioPlaybackOutcome.unavailable;
      if (generation == _generation) lastError = error;
    }
    if (generation != _generation) return;
    _pendingTimeout?.cancel();
    _pendingTimeout = null;
    _waitingForPlayback = false;
    lastOutcome = outcome;
    trace?.record('playback_result',
        requestId: _activeRequestId, cueId: cue.id, reason: outcome.name);
    _activeCue = null;
    _activeEvent = null;
    _activeRequestId = null;
  }

  Future<void> _warm() async {
    try {
      await (_port as PreparedWorkoutAudioPort).prepare();
    } catch (error) {
      if (!_closed) lastError = error;
    }
  }

  void _cancel({String reason = 'lifecycle_or_preference'}) {
    if (_activeCue != null) {
      trace?.record('cancelled',
          requestId: _activeRequestId, cueId: _activeCue?.id, reason: reason);
    }
    _generation++;
    _activeCue = null;
    _activeEvent = null;
    _activeRequestId = null;
    _eventWait.stop();
    _waitingForPlayback = false;
    _pendingTimeout?.cancel();
    _pendingTimeout = null;
    _arbiter.clearPending();
    // All new plays await the same barrier. Repeated lifecycle/tracking events
    // invalidate generations without building a queue of platform stop calls.
    if (!_stopPending) {
      _stopPending = true;
      _stopBarrier = _stop();
    }
  }

  Future<void> _stop() async {
    try {
      await _port.stop();
    } catch (error) {
      lastError = error;
    } finally {
      _stopPending = false;
    }
  }

  /// Call on logout/session replacement as well as normal session disposal.
  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closed = true;
    _cancel();
    return _closeFuture = _close();
  }

  Future<void> _close() async {
    await _stopBarrier;
    try {
      await _port.close();
    } catch (error) {
      lastError = error;
    }
  }
}
