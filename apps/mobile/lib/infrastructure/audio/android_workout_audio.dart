import 'package:flutter/services.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import '../../features/workout/domain/workout_audio_port.dart';
import '../../features/workout/domain/workout_audio_trace.dart';
import '../../features/workout/domain/workout_performance_diagnostics.dart';

/// Offline Android TTS, lazily initialized only after voice coaching is enabled.
/// Native futures complete on utterance done/stop/error. Each cancellation epoch
/// invalidates playback still waiting for engine initialization.
class AndroidWorkoutAudio
    implements
        RetryableWorkoutAudioPort,
        TimedWorkoutAudioPort,
        TracedWorkoutAudioPort {
  AndroidWorkoutAudio(
      {MethodChannel? channel, String? sessionId, this.trace, this.baseline})
      : _channel = channel ?? const MethodChannel('gainpath/workout_audio'),
        _sessionId = sessionId ??
            'audio-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  static int _nextId = 0;
  final MethodChannel _channel;
  String _sessionId;
  final WorkoutAudioTrace? trace;
  final WorkoutPerformanceDiagnostics? baseline;
  bool _ttsOpened = false;
  MethodChannel? _traceChannel;
  String? _requestId, _cueId;
  Future<bool>? _ready;
  Future<bool>? _retrying;
  Future<void>? _closeFuture;
  bool _closed = false;
  int _generation = 0;
  Object? lastError;

  Map<String, Object> get _identity => {
        'sessionId': _sessionId,
        'generation': _generation,
      };

  Future<bool> _create() async {
    final creatingId = _sessionId;
    try {
      trace?.record('tts_prepare_requested');
      if (trace != null) {
        _traceChannel =
            MethodChannel('gainpath/workout_audio/events/$_sessionId');
        _traceChannel!.setMethodCallHandler((call) async {
          if (_closed ||
              creatingId != _sessionId ||
              call.method != 'trace' ||
              call.arguments is! Map) {
            return;
          }
          final row = call.arguments as Map;
          // Ignore late callbacks from an older request/session/epoch.
          if (row['requestId'] != _requestId ||
              row['generation'] != _generation) {
            return;
          }
          final stage = row['stage'];
          const allowed = {
            'native_tts_request',
            'playback_start',
            'playback_completed',
            'playback_cancelled',
            'playback_unavailable',
            'expired_before_start'
          };
          if (stage is! String || !allowed.contains(stage)) return;
          trace!.record(stage,
              requestId: _requestId,
              cueId: _cueId,
              nativeElapsedMicros: row['nativeElapsedMicros'] as int?);
        });
      }
      final ready = await _channel.invokeMethod<bool>('create', {
            ..._identity,
            if (trace != null) 'trace': true,
          }) ==
          true;
      trace?.record('tts_prepare_completed',
          reason: ready ? 'ready' : 'unavailable');
      if (ready && !_closed && creatingId == _sessionId) {
        _ttsOpened = true;
        baseline?.resourceOpened(WorkoutResource.tts);
      }
      return ready && !_closed && creatingId == _sessionId;
    } catch (error) {
      lastError = error;
      return false;
    }
  }

  @override
  Future<bool> prepare() =>
      _closed ? Future.value(false) : (_retrying ?? (_ready ??= _create()));

  @override
  Future<bool> retryPrepare() => _closed
      ? Future.value(false)
      : (_retrying ??= _retryPrepare().whenComplete(() => _retrying = null));

  Future<bool> _retryPrepare() async {
    await stop();
    await _channel.invokeMethod<void>('close', _identity);
    _traceChannel?.setMethodCallHandler(null);
    if (_ttsOpened) {
      _ttsOpened = false;
      baseline?.resourceClosed(WorkoutResource.tts);
    }
    if (_closed) return false;
    _sessionId = 'audio-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
    return await (_ready = _create());
  }

  @override
  Future<AudioPlaybackOutcome> play(CueRequest cue) => _play(cue);

  @override
  Future<AudioPlaybackOutcome> playTraced(CueRequest cue,
          {required String requestId}) =>
      _play(cue, requestId: requestId);

  @override
  Future<AudioPlaybackOutcome> playCurrent(CueRequest cue,
          {required String requestId, required Duration remainingStartTime}) =>
      _play(cue, requestId: requestId, remainingStartTime: remainingStartTime);

  Future<AudioPlaybackOutcome> _play(CueRequest cue,
      {String? requestId, Duration? remainingStartTime}) async {
    if (_closed) return AudioPlaybackOutcome.cancelled;
    if (remainingStartTime != null && remainingStartTime <= Duration.zero) {
      return AudioPlaybackOutcome.cancelled;
    }
    final waiting = Stopwatch()..start();
    if (cue.id.isEmpty ||
        cue.id.length > 96 ||
        cue.text.trim().isEmpty ||
        cue.text.length > 240) {
      return AudioPlaybackOutcome.unavailable;
    }
    final generation = _generation;
    final ready = await prepare();
    if (_closed || generation != _generation) {
      return AudioPlaybackOutcome.cancelled;
    }
    if (!ready) return AudioPlaybackOutcome.unavailable;
    if (remainingStartTime != null && waiting.elapsed >= remainingStartTime) {
      return AudioPlaybackOutcome.cancelled;
    }
    int? nativeSample;
    if (remainingStartTime != null) {
      // Sample Android's clock, then subtract the entire Dart wait. Because
      // Android sampled before this response arrives, this mapping expires
      // conservatively; delivery of the next play call cannot restart its age.
      try {
        nativeSample = await _channel.invokeMethod<int>('clock', _identity);
      } catch (_) {
        return AudioPlaybackOutcome.unavailable;
      }
      if (_closed || generation != _generation) {
        return AudioPlaybackOutcome.cancelled;
      }
      if (nativeSample == null) return AudioPlaybackOutcome.unavailable;
    }
    final remainingMicros = remainingStartTime == null
        ? null
        : remainingStartTime.inMicroseconds - waiting.elapsedMicroseconds;
    if (remainingMicros != null && remainingMicros <= 0) {
      return AudioPlaybackOutcome.cancelled;
    }
    try {
      _requestId = requestId;
      _cueId = cue.id;
      trace?.record('tts_request', requestId: requestId, cueId: cue.id);
      final outcome = await _channel.invokeMethod<String>('play', {
        ..._identity,
        'cueId': cue.id,
        'text': cue.text,
        if (requestId != null) 'requestId': requestId,
        if (remainingMicros != null)
          'maxStartDelayMs': (remainingMicros ~/ 1000).clamp(1, 500),
        if (nativeSample != null && remainingMicros != null)
          'startDeadlineMicros': nativeSample + remainingMicros,
      });
      if (_closed || generation != _generation || outcome == 'cancelled') {
        return AudioPlaybackOutcome.cancelled;
      }
      return outcome == 'completed'
          ? AudioPlaybackOutcome.completed
          : AudioPlaybackOutcome.unavailable;
    } catch (error) {
      lastError = error;
      return AudioPlaybackOutcome.unavailable;
    }
  }

  @override
  Future<void> stop() async {
    if (_closed) return;
    _generation++;
    if (_ready == null) return;
    try {
      await _channel.invokeMethod<void>('stop', _identity);
    } catch (error) {
      lastError = error;
    }
  }

  @override
  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closed = true;
    _generation++;
    return _closeFuture = _close();
  }

  Future<void> _close() async {
    _traceChannel?.setMethodCallHandler(null);
    if (_ready == null) return;
    try {
      // Do not wait for a late onInit callback before requesting shutdown.
      await _channel.invokeMethod<void>('close', _identity);
      if (_ttsOpened) {
        _ttsOpened = false;
        baseline?.resourceClosed(WorkoutResource.tts);
      }
    } catch (error) {
      lastError = error;
    }
  }
}
