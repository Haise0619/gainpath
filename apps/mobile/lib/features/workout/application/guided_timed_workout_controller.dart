import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/guided_timed_progress.dart';
import '../domain/tutorial_player.dart';

/// Serialized timer commands, with synchronous invalidation for media/lifecycle loss.
class GuidedTimedWorkoutController extends ChangeNotifier {
  GuidedTimedWorkoutController(
      {required GuidedTimedProgress progress,
      required this.player,
      required this.activeScope,
      required this.persist,
      Duration Function()? monotonicNow,
      DateTime Function()? utcNow,
      this.initializationTimeout = const Duration(seconds: 25)})
      : _progress = progress,
        _now = monotonicNow ?? _defaultClock,
        _utc = utcNow ?? _defaultUtc {
    player.addListener(_playerChanged);
  }
  static final Stopwatch _clock = Stopwatch()..start();
  static Duration _defaultClock() => _clock.elapsed;
  static DateTime _defaultUtc() => DateTime.now().toUtc();
  final TutorialPlayer player;
  final bool Function() activeScope;
  final Future<void> Function(GuidedTimedProgress) persist;
  final Duration Function() _now;
  final DateTime Function() _utc;
  final Duration initializationTimeout;
  GuidedTimedProgress _progress;
  GuidedTimedProgress get progress => _progress;
  String? interruptionReason;
  bool _disposed = false,
      _blocked = false,
      _saving = false,
      _notifierDisposed = false;
  int _generation = 0, _lastSavedActive = 0;
  Duration? _anchor;
  Future<void> _tail = Future.value();
  bool get _valid => !_disposed && activeScope();
  Future<void> _serial(Future<void> Function() action) {
    final next = _tail.then((_) async {
      if (!_valid) {
        _revoke();
        return;
      }
      await action();
    });
    _tail = next.catchError((Object _) {});
    return next;
  }

  void _set(GuidedTimedProgress value) {
    _progress = value;
    if (!_disposed) notifyListeners();
  }

  void _revoke() {
    _anchor = null;
    _blocked = true;
    _generation++;
    if (!_disposed) {
      player.removeListener(_playerChanged);
      player.dispose();
      _disposed = true;
    }
  }

  void _playerChanged() {
    if (!_valid) {
      _revoke();
      return;
    }
    if ((player.buffering || player.error != null || !player.playing) &&
        _anchor != null &&
        !_saving) {
      // Do not award the interval whose playback readiness is now unknown.
      _anchor = null;
      _blocked = true;
      _generation++;
      unawaited(interrupt(player.error ??
          (player.buffering ? 'buffering' : 'playback stopped')));
    }
  }

  Future<void> _save() async {
    if (!_valid) {
      _revoke();
      return;
    }
    try {
      await persist(_progress.completed
          ? _progress.copyWith(phase: GuidedTimedPhase.completed)
          : _progress);
      if (!_valid) {
        _revoke();
        return;
      }
      _lastSavedActive = _progress.totalActiveMicroseconds;
    } catch (_) {
      _anchor = null;
      _blocked = true;
      interruptionReason = 'save failed';
      _set(_progress.copyWith(
          phaseBeforePause: switch (_progress.phase) {
            GuidedTimedPhase.saving => GuidedTimedPhase.completed,
            GuidedTimedPhase.paused || GuidedTimedPhase.interrupted =>
              _progress.phaseBeforePause,
            final phase => phase,
          },
          phase: GuidedTimedPhase.interrupted,
          updatedAt: _utc()));
      await player.pause();
      rethrow;
    }
  }

  Future<void> initialize() => _serial(() async {
        _anchor = null;
        _blocked = true;
        final generation = ++_generation;
        final previousPhase = _progress.phase;
        final resumePhase = previousPhase == GuidedTimedPhase.working ||
                previousPhase == GuidedTimedPhase.resting
            ? previousPhase
            : _progress.phaseBeforePause;
        _set(_progress.copyWith(
            phase: GuidedTimedPhase.loading,
            phaseBeforePause: resumePhase,
            updatedAt: _utc()));
        try {
          await player.initialize().timeout(initializationTimeout);
          if (!_valid || generation != _generation) return;
          await player.setLooping(true);
          if (!_valid || generation != _generation) return;
          if (!player.ready || player.error != null) {
            throw StateError('Media unavailable');
          }
          _set(_progress.copyWith(
              phase: _progress.completed
                  ? GuidedTimedPhase.completed
                  : (_progress.totalActiveMicroseconds > 0
                      ? GuidedTimedPhase.paused
                      : GuidedTimedPhase.ready),
              updatedAt: _utc()));
        } catch (_) {
          if (_valid && generation == _generation) {
            interruptionReason = 'media initialization failed';
            _set(_progress.copyWith(
                phase: GuidedTimedPhase.interrupted, updatedAt: _utc()));
          }
        }
      });
  Future<void> _play(GuidedTimedPhase phase) async {
    final generation = _generation;
    if (!player.ready || player.buffering || player.error != null) return;
    try {
      await player.play();
    } catch (_) {
      await _interrupt('playback failed');
      return;
    }
    if (!_valid || generation != _generation) {
      await player.pause();
      return;
    }
    if (!player.playing || player.buffering || player.error != null) {
      await _interrupt('playback failed');
      return;
    }
    _blocked = false;
    interruptionReason = null;
    _set(_progress.copyWith(
        phase: phase,
        startedAt: _progress.startedAt ?? _utc(),
        updatedAt: _utc()));
    _anchor = _now();
    await _save();
  }

  Future<void> start() => _serial(() async {
        if (_progress.phase == GuidedTimedPhase.ready) {
          await _play(GuidedTimedPhase.working);
        }
      });
  Future<void> resume() => _serial(() async {
        if (_progress.completed) {
          await _save();
          _set(_progress.copyWith(
              phase: GuidedTimedPhase.completed, updatedAt: _utc()));
          return;
        }
        if (_progress.phase != GuidedTimedPhase.paused &&
            _progress.phase != GuidedTimedPhase.interrupted) {
          return;
        }
        final prior = _progress.phaseBeforePause;
        await _play(prior == GuidedTimedPhase.resting
            ? prior
            : GuidedTimedPhase.working);
      });

  Future<void> retryProgressSave() => _serial(() async {
        if (interruptionReason != 'save failed') return;
        final retry = _progress.copyWith(
            phase: _progress.completed
                ? GuidedTimedPhase.completed
                : GuidedTimedPhase.paused,
            updatedAt: _utc());
        await persist(retry);
        if (!_valid) {
          _revoke();
          return;
        }
        _lastSavedActive = retry.totalActiveMicroseconds;
        interruptionReason = null;
        _set(retry);
      });
  Future<void> tick() => _serial(_tick);
  Future<void> _tick() async {
    if (_anchor == null || _blocked) return;
    final now = _now();
    final elapsed = (now - _anchor!).inMicroseconds;
    _anchor = now;
    if (elapsed <= 0) return;
    if (_progress.phase == GuidedTimedPhase.working) {
      final active = _progress.currentSetActiveMicroseconds + elapsed;
      if (active >= _progress.targetMicroseconds) {
        final sets = [
          ..._progress.completedSetActiveMicroseconds,
          _progress.targetMicroseconds
        ];
        final done = sets.length == _progress.prescription.sets;
        _set(_progress.copyWith(
            completedSetActiveMicroseconds: sets,
            currentSetActiveMicroseconds: 0,
            remainingRestMicroseconds:
                done ? 0 : _progress.prescription.restSeconds * 1000000,
            restKind: GuidedTimedRestKind.betweenSets,
            phase: done ? GuidedTimedPhase.saving : GuidedTimedPhase.resting,
            endedAt: done ? _utc() : null,
            updatedAt: _utc()));
        if (done) {
          _anchor = null;
          _blocked = true;
          _saving = true;
          try {
            await player.pause();
            await _save();
            if (_valid) {
              _set(_progress.copyWith(
                  phase: GuidedTimedPhase.completed, updatedAt: _utc()));
            }
          } finally {
            _saving = false;
          }
        } else {
          await _save();
        }
        return;
      }
      _set(_progress.copyWith(
          currentSetActiveMicroseconds: active, updatedAt: _utc()));
    } else if (_progress.phase == GuidedTimedPhase.resting) {
      _set(_progress.copyWith(
          remainingRestMicroseconds:
              (_progress.remainingRestMicroseconds - elapsed)
                  .clamp(0, _progress.prescription.restSeconds * 1000000),
          updatedAt: _utc()));
    }
    if (_progress.totalActiveMicroseconds - _lastSavedActive >= 5000000) {
      await _save();
    }
  }

  Future<void> pause() {
    // Freeze immediately, even if an asynchronous save is pending.
    final stop = _now();
    final anchor = _anchor;
    _anchor = null;
    _blocked = true;
    _generation++;
    return _serial(() async {
      if (anchor != null &&
          (_progress.phase == GuidedTimedPhase.working ||
              _progress.phase == GuidedTimedPhase.resting)) {
        _anchor = anchor;
        _blocked = false;
        await _tickUntil(stop);
        _anchor = null;
        _blocked = true;
      }
      final phase = _progress.phase;
      if (phase == GuidedTimedPhase.completed) return;
      _set(_progress.copyWith(
          phaseBeforePause: phase == GuidedTimedPhase.paused
              ? _progress.phaseBeforePause
              : phase,
          phase: GuidedTimedPhase.paused,
          updatedAt: _utc()));
      await player.pause();
      await _save();
    });
  }

  Future<void> _tickUntil(Duration stop) async {
    // A pause never completes a set: only a foreground tick can credit elapsed targets.
    final delta =
        (stop - _anchor!).inMicroseconds.clamp(0, _progress.targetMicroseconds);
    if (_progress.phase == GuidedTimedPhase.working) {
      _set(_progress.copyWith(
          currentSetActiveMicroseconds:
              (_progress.currentSetActiveMicroseconds + delta)
                  .clamp(0, _progress.targetMicroseconds - 1),
          updatedAt: _utc()));
    }
    if (_progress.phase == GuidedTimedPhase.resting) {
      _set(_progress.copyWith(
          remainingRestMicroseconds:
              (_progress.remainingRestMicroseconds - delta)
                  .clamp(0, _progress.prescription.restSeconds * 1000000),
          updatedAt: _utc()));
    }
  }

  Future<void> rest() => _serial(() async {
        if (_progress.phase != GuidedTimedPhase.working) return;
        if (_anchor != null) await _tickUntil(_now());
        _set(_progress.copyWith(
            phase: GuidedTimedPhase.resting,
            restKind: GuidedTimedRestKind.midSet,
            remainingRestMicroseconds:
                _progress.prescription.restSeconds * 1000000,
            updatedAt: _utc()));
        _anchor = _now();
        await _save();
      });
  Future<void> resumeCurrentSet() => _serial(() async {
        if (_progress.phase == GuidedTimedPhase.resting &&
            _progress.restKind == GuidedTimedRestKind.midSet) {
          await _play(GuidedTimedPhase.working);
        }
      });
  Future<void> startNextSet({bool skipRest = false}) => _serial(() async {
        if (_progress.phase == GuidedTimedPhase.resting &&
            _progress.restKind == GuidedTimedRestKind.betweenSets &&
            (skipRest || _progress.remainingRestMicroseconds == 0)) {
          await _play(GuidedTimedPhase.working);
        }
      });
  Future<void> _interrupt(String reason) async {
    _anchor = null;
    _blocked = true;
    interruptionReason = reason;
    if (_progress.phase == GuidedTimedPhase.completed) return;
    _set(_progress.copyWith(
        phaseBeforePause: _progress.phase == GuidedTimedPhase.interrupted
            ? _progress.phaseBeforePause
            : _progress.phase,
        phase: GuidedTimedPhase.interrupted,
        updatedAt: _utc()));
    await player.pause();
    await _save();
  }

  Future<void> interrupt(String reason) {
    _anchor = null;
    _blocked = true;
    _generation++;
    unawaited(player.pause().catchError((Object _) {}));
    return _serial(() => _interrupt(reason));
  }

  Future<void> saveAndExit() => pause();
  @override
  void dispose() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    _revoke();
    super.dispose();
  }
}
