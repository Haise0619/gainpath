import 'package:flutter/services.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import '../../features/workout/domain/workout_audio_port.dart';

/// Offline Android TTS, lazily initialized only after voice coaching is enabled.
/// Native futures complete on utterance done/stop/error. Each cancellation epoch
/// invalidates playback still waiting for engine initialization.
class AndroidWorkoutAudio implements PreparedWorkoutAudioPort {
  AndroidWorkoutAudio({MethodChannel? channel, String? sessionId})
      : _channel = channel ?? const MethodChannel('gainpath/workout_audio'),
        _sessionId = sessionId ??
            'audio-${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';

  static int _nextId = 0;
  final MethodChannel _channel;
  final String _sessionId;
  Future<bool>? _ready;
  Future<void>? _closeFuture;
  bool _closed = false;
  int _generation = 0;
  Object? lastError;

  Map<String, Object> get _identity => {
        'sessionId': _sessionId,
        'generation': _generation,
      };

  Future<bool> _create() async {
    try {
      return await _channel.invokeMethod<bool>('create', _identity) == true;
    } catch (error) {
      lastError = error;
      return false;
    }
  }

  @override
  Future<bool> prepare() =>
      _closed ? Future.value(false) : (_ready ??= _create());

  @override
  Future<AudioPlaybackOutcome> play(CueRequest cue) async {
    if (_closed) return AudioPlaybackOutcome.cancelled;
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
    try {
      final outcome = await _channel.invokeMethod<String>('play', {
        ..._identity,
        'cueId': cue.id,
        'text': cue.text,
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
    if (_ready == null) return;
    try {
      // Do not wait for a late onInit callback before requesting shutdown.
      await _channel.invokeMethod<void>('close', _identity);
    } catch (error) {
      lastError = error;
    }
  }
}
