import 'dart:async';

import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import '../domain/workout_audio_port.dart';

/// Session-scoped audio policy. Consume only current analyzed pose batches;
/// this controller never queues corrections from previous frames.
class WorkoutAudioController {
  WorkoutAudioController({
    required WorkoutAudioPort port,
    AudioCueArbiter? arbiter,
    this.pendingStartTimeout = const Duration(milliseconds: 500),
  })  : assert(pendingStartTimeout > Duration.zero),
        _port = port,
        _arbiter = arbiter ?? AudioCueArbiter();

  final WorkoutAudioPort _port;
  final AudioCueArbiter _arbiter;

  /// Audio request validity while waiting to start; unrelated to pose freshness.
  final Duration pendingStartTimeout;
  bool _voiceEnabled = false;
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
  bool get voiceEnabled => _voiceEnabled;
  bool get isClosed => _closed;
  AudioPlaybackOutcome? lastOutcome;
  Object? lastError;
  bool get _canPlay => !_closed && _voiceEnabled && !_paused && _foreground;

  void applyPreferences(MemberPreferences preferences) =>
      setVoiceEnabled(preferences.voiceCoaching);

  void setVoiceEnabled(bool enabled) {
    if (_closed || _voiceEnabled == enabled) return;
    _voiceEnabled = enabled;
    if (!enabled) {
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
  }) {
    if (_closed ||
        nowMicros < 0 ||
        (_lastInputMicros != null && nowMicros <= _lastInputMicros!)) {
      return;
    }
    _lastInputMicros = nowMicros;
    final batch = cues.toList(growable: false);
    // Event cues may be emitted for just one frame. Do not interrupt speech
    // already underway, but a request that has not started must remain current
    // throughout asynchronous stop/engine preparation.
    if (_waitingForPlayback &&
        _activeCue != null &&
        !batch.any((cue) =>
            cue.id == _activeCue!.id &&
            cue.text == _activeCue!.text &&
            cue.priority == _activeCue!.priority)) {
      _cancel();
    }
    if (_trackingAvailable != trackingAvailable) {
      _trackingAvailable = trackingAvailable;
      _cancel();
    }
    _arbiter.clearPending();
    if (!_canPlay) return;
    for (final cue in batch) {
      if (cue.id.isEmpty || cue.text.trim().isEmpty) continue;
      if (!trackingAvailable && cue.priority != CuePriority.warning) continue;
      final active = _activeCue;
      if (active != null &&
          (cue.id == active.id ||
              cue.priority.weight <= active.priority.weight)) {
        continue;
      }
      _arbiter.submit(cue);
    }
    final selected = _arbiter.takeNext(nowMicros: nowMicros);
    _arbiter.clearPending();
    if (selected == null) return;
    if (_activeCue != null) _cancel();
    _activeCue = selected;
    _waitingForPlayback = true;
    final generation = _generation;
    _pendingTimeout = Timer(pendingStartTimeout, () {
      if (generation == _generation && _waitingForPlayback) _cancel();
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
          lastOutcome = AudioPlaybackOutcome.unavailable;
          _pendingTimeout?.cancel();
          _pendingTimeout = null;
          _waitingForPlayback = false;
          _activeCue = null;
          return;
        }
      }
      _pendingTimeout?.cancel();
      _pendingTimeout = null;
      _waitingForPlayback = false;
      outcome = await _port.play(cue);
    } catch (error) {
      outcome = AudioPlaybackOutcome.unavailable;
      if (generation == _generation) lastError = error;
    }
    if (generation != _generation) return;
    _pendingTimeout?.cancel();
    _pendingTimeout = null;
    _waitingForPlayback = false;
    lastOutcome = outcome;
    _activeCue = null;
  }

  Future<void> _warm() async {
    try {
      await (_port as PreparedWorkoutAudioPort).prepare();
    } catch (error) {
      if (!_closed) lastError = error;
    }
  }

  void _cancel() {
    _generation++;
    _activeCue = null;
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
