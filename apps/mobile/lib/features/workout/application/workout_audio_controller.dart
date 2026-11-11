import 'dart:async';
import 'package:flutter/foundation.dart';

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
    this.quietPeriodMicros = 0,
  })  : assert(pendingStartTimeout > Duration.zero),
        _port = port,
        _arbiter = arbiter ?? AudioCueArbiter();

  final WorkoutAudioPort _port;
  final AudioCueArbiter _arbiter;
  final _boundaryArbiter = AudioCueArbiter(cooldownMicros: 0);
  WorkoutAudioTrace? trace;
  final bool boundedStarts;

  /// Opt-in cross-ID quiet period; higher-priority alerts may interrupt.
  final int quietPeriodMicros;
  int? _lastSelectedAt;
  CuePriority? _lastSelectedPriority;
  int _requestSequence = 0;
  int _diagnosticSequence = 0;
  String? _activeRequestId;
  final Set<String> _seenEvents = {};
  WorkoutFeedbackEvent? _activeEvent;
  WorkoutFeedbackEvent? _recentOutcome;
  bool _activeRestBoundary = false;
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
  Future<bool>? _warming;
  Future<void>? _playback;
  final availability = ValueNotifier(WorkoutVoiceAvailability.muted);

  void _availability(WorkoutVoiceAvailability value) {
    availability.value =
        voiceEnabled && !_closed ? value : WorkoutVoiceAvailability.muted;
  }

  /// Analysis stops at a set boundary; only the completed observation survives.
  void finishSet({String? transition, bool restScoped = false}) {
    final outcome = _recentOutcome;
    _recentOutcome = null;
    if (_activeEvent != null &&
        (outcome == null || _activeEvent!.id == outcome.id)) {
      final cue = _activeCue;
      if (transition != null &&
          outcome != null &&
          _waitingForPlayback &&
          cue?.priority == CuePriority.encouragement) {
        _activeCue =
            CueRequest(id: cue!.id, text: transition, priority: cue.priority);
        _activeRestBoundary = restScoped;
      }
      return;
    }
    _cancel(reason: 'set_boundary');
    final now = _lastInputMicros;
    if (outcome == null || now == null || !outcome.isFresh(now)) return;
    // Ordinary rep cooldown may suppress this final repetition. A distinct,
    // once-per-observation boundary cue still shares its original start budget.
    _consume(const [],
        nowMicros: now,
        trackingAvailable: _trackingAvailable,
        events: [
          WorkoutFeedbackEvent(
              id: 'boundary-${outcome.id}',
              cue: CueRequest(
                  id: 'workout_set_complete',
                  text: transition ?? 'Set complete.',
                  priority: CuePriority.encouragement),
              observedAtMicros: outcome.observedAtMicros,
              generatedAtMicros: now)
        ],
        arbiter: _boundaryArbiter);
    _activeRestBoundary =
        restScoped && _activeCue?.id == 'workout_set_complete';
    _recentOutcome = null;
  }

  /// One short, fresh transition. Busy playback and Alerts Only suppress it
  /// rather than queueing an announcement that could become obsolete.
  bool announceTransition(String id, String text, {required int nowMicros}) {
    if (!_canPlay ||
        _voiceMode != WorkoutVoiceMode.fullCoaching ||
        _activeCue != null ||
        nowMicros < (_lastInputMicros ?? 0)) {
      return false;
    }
    final previousOutcome = _recentOutcome;
    _consume(const [],
        nowMicros: nowMicros,
        trackingAvailable: _trackingAvailable,
        events: [
          WorkoutFeedbackEvent(
              id: 'transition-$id',
              cue: CueRequest(
                  id: 'workout_transition',
                  text: text,
                  priority: CuePriority.encouragement),
              observedAtMicros: nowMicros,
              generatedAtMicros: nowMicros)
        ],
        arbiter: _boundaryArbiter);
    _recentOutcome = previousOutcome;
    return _activeEvent?.id == 'transition-$id';
  }

  void cancelTransition() {
    if ((_activeRestBoundary && _activeCue != null) ||
        _activeEvent?.id.startsWith('transition-') == true) {
      _cancel(reason: 'transition_ended');
    }
  }

  /// Called after durable save. No unbounded speech wait can block teardown.
  Future<void> settleFeedback() async {
    final pending = _activeEvent == null ? null : _playback;
    if (pending == null) return;
    await pending.timeout(const Duration(milliseconds: 1500), onTimeout: () {
      _cancel(reason: 'completion_deadline');
    });
  }

  Future<void> retryVoice() async {
    if (!_canPlay ||
        availability.value != WorkoutVoiceAvailability.unavailable) {
      return;
    }
    _cancel(reason: 'voice_retry');
    await _stopBarrier;
    if (!_canPlay) return;
    _warming = null;
    await _warm(retry: true);
  }

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
    if (!voiceEnabled) _availability(WorkoutVoiceAvailability.muted);
    if (voiceEnabled && _port is! PreparedWorkoutAudioPort) {
      _availability(WorkoutVoiceAvailability.ready);
    }
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
    _consume(cues,
        nowMicros: nowMicros,
        trackingAvailable: trackingAvailable,
        events: events,
        invalidateFeedback: invalidateFeedback,
        observedAtMicros: observedAtMicros);
  }

  void _consume(
    Iterable<CueRequest> cues, {
    required int nowMicros,
    required bool trackingAvailable,
    Iterable<WorkoutFeedbackEvent> events = const [],
    bool invalidateFeedback = false,
    int? observedAtMicros,
    AudioCueArbiter? arbiter,
  }) {
    final policy = arbiter ?? _arbiter;
    _recentOutcome = null;
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
      trace?.record('exercise_event_generated',
          requestId: event.id,
          cueId: event.cue.id,
          observedAtMicros: event.observedAtMicros);
      if (invalidateFeedback || !event.isFresh(nowMicros)) {
        trace?.record('dropped',
            requestId: event.id,
            cueId: event.cue.id,
            reason: 'stale_or_invalid');
        continue;
      }
      eventByCue[event.cue.id] = event;
      _recentOutcome = event;
      batch.add(event.cue);
      trace?.record('feedback_queued',
          requestId: event.id, cueId: event.cue.id);
    }
    final diagnosticRequests = <String, String>{
      for (final event in eventByCue.values) event.cue.id: event.id,
    };
    if (_activeEvent?.id.startsWith('transition-tracking-ready-') == true &&
        eventByCue.values.any((event) => !event.id.startsWith('transition-'))) {
      _cancel(reason: 'measured_feedback_supersedes_ready');
    }
    final diagnosticDrops = <String>{};
    if (trace != null) {
      for (final cue in batch) {
        if (eventByCue.containsKey(cue.id)) continue;
        final id = 'observed-${++_diagnosticSequence}';
        diagnosticRequests[cue.id] = id;
        trace!.record('exercise_event_generated',
            requestId: id,
            cueId: cue.id,
            observedAtMicros: observedAtMicros ?? nowMicros);
      }
    }
    void observeDrop(CueRequest cue, String reason) {
      final id = diagnosticRequests[cue.id];
      if (id != null && diagnosticDrops.add(id)) {
        trace?.record('dropped', requestId: id, cueId: cue.id, reason: reason);
      }
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
    policy.clearPending();
    if (!_canPlay) {
      for (final cue in batch) {
        observeDrop(cue, 'audio_disabled');
      }
      return;
    }
    for (final cue in batch) {
      if (cue.id.isEmpty || cue.text.trim().isEmpty) {
        observeDrop(cue, 'invalid_cue');
        continue;
      }
      if (_voiceMode == WorkoutVoiceMode.alertsOnly &&
          cue.priority == CuePriority.encouragement) {
        observeDrop(cue, 'voice_mode');
        continue;
      }
      if (arbiter == null &&
          _lastSelectedAt != null &&
          nowMicros - _lastSelectedAt! < quietPeriodMicros &&
          cue.priority.weight <= _lastSelectedPriority!.weight) {
        observeDrop(cue, 'quiet_period');
        continue;
      }
      if (!trackingAvailable &&
          cue.priority != CuePriority.warning &&
          !eventByCue.containsKey(cue.id)) {
        observeDrop(cue, 'tracking_unavailable');
        continue;
      }
      final active = _activeCue;
      if (active != null &&
          (cue.id == active.id ||
              cue.priority.weight <= active.priority.weight)) {
        observeDrop(cue, 'active_priority');
        continue;
      }
      final requestId = eventByCue[cue.id]?.id ??
          diagnosticRequests[cue.id] ??
          'cue-${++_requestSequence}';
      requestByCue[cue.id] = requestId;
      policy.submit(cue);
    }
    final selected = policy.takeNext(nowMicros: nowMicros);
    policy.clearPending();
    if (selected == null) {
      for (final cue in batch) {
        observeDrop(cue, 'priority_or_cooldown');
      }
      return;
    }
    for (final cue in batch.where((c) => c.id != selected.id)) {
      observeDrop(cue, 'arbitration_priority');
    }
    if (_activeCue != null) _cancel(reason: 'higher_priority');
    _lastSelectedAt = nowMicros;
    _lastSelectedPriority = selected.priority;
    _activeCue = selected;
    _activeRestBoundary = false;
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
    _playback = _play(selected, _generation);
    unawaited(_playback!);
  }

  Future<void> _play(CueRequest cue, int generation) async {
    await _stopBarrier;
    if (!_canPlay || generation != _generation) return;
    AudioPlaybackOutcome outcome;
    try {
      final prepared = _port;
      if (prepared is PreparedWorkoutAudioPort) {
        final available = await _warm();
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
      // The same accepted boundary event can coalesce its text with the rest
      // announcement before dispatch. Keep its identity, timing and priority.
      cue = _activeCue ?? cue;
      trace?.record('tts_dispatch', requestId: _activeRequestId, cueId: cue.id);
      final timed = _port;
      outcome =
          (event != null || boundedStarts) && timed is TimedWorkoutAudioPort
              ? await timed.playCurrent(cue,
                  requestId: _activeRequestId!,
                  remainingStartTime: Duration(microseconds: remaining))
              : trace != null && timed is TracedWorkoutAudioPort
                  ? await timed.playTraced(cue, requestId: _activeRequestId!)
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
    if (outcome == AudioPlaybackOutcome.unavailable) {
      _availability(WorkoutVoiceAvailability.unavailable);
    }
    trace?.record('playback_result',
        requestId: _activeRequestId, cueId: cue.id, reason: outcome.name);
    _activeCue = null;
    _activeEvent = null;
    _recentOutcome = null;
    _activeRequestId = null;
  }

  Future<bool> _warm({bool retry = false}) {
    if (_closed || !voiceEnabled) return Future.value(false);
    _availability(WorkoutVoiceAvailability.preparing);
    if (_warming != null) {
      return _warming!.then((ready) {
        _availability(ready
            ? WorkoutVoiceAvailability.ready
            : WorkoutVoiceAvailability.unavailable);
        return ready;
      });
    }
    return _warming = () async {
      var ready = false;
      try {
        final port = _port as PreparedWorkoutAudioPort;
        ready = await (retry && port is RetryableWorkoutAudioPort
                ? port.retryPrepare()
                : port.prepare())
            .timeout(const Duration(seconds: 3));
      } catch (error) {
        if (!_closed) lastError = error;
      }
      _availability(ready
          ? WorkoutVoiceAvailability.ready
          : WorkoutVoiceAvailability.unavailable);
      return ready;
    }();
  }

  void _cancel({String reason = 'lifecycle_or_preference'}) {
    _recentOutcome = null;
    if (_activeCue != null) {
      trace?.record('cancelled',
          requestId: _activeRequestId, cueId: _activeCue?.id, reason: reason);
    }
    _generation++;
    _activeRestBoundary = false;
    _activeCue = null;
    _activeEvent = null;
    _activeRequestId = null;
    _eventWait.stop();
    _waitingForPlayback = false;
    _pendingTimeout?.cancel();
    _pendingTimeout = null;
    _arbiter.clearPending();
    _boundaryArbiter.clearPending();
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
    _availability(WorkoutVoiceAvailability.muted);
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
