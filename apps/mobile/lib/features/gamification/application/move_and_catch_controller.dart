import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/move_and_catch.dart';
import '../domain/move_catch_ports.dart';
import 'mini_game_round_coordinator.dart';

class MoveAndCatchController extends ChangeNotifier {
  MoveAndCatchController(
      {required this.scope,
      required this.activeScope,
      required this.camera,
      required this.bestScores,
      this.roundTiming,
      MoveCatchEngine? engine,
      int Function()? clockMicros,
      bool autoTick = true})
      : engine = engine ?? MoveCatchEngine() {
    final clock = Stopwatch()..start();
    _clock = clockMicros ?? () => clock.elapsedMicroseconds;
    camera.addListener(_cameraChanged);
    roundTiming?.addListener(_notify);
    if (autoTick) {
      _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => tick());
    }
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final MoveCatchCamera camera;
  final MoveCatchBestScoreStore bestScores;
  final MoveCatchEngine engine;
  final MiniGameRoundCoordinator? roundTiming;
  bool roundTimingConsent = false;
  void setRoundTimingConsent(bool consented) {
    if (!hasConsent && roundTiming != null && current) {
      roundTimingConsent = consented;
      _notify();
    }
  }

  late final int Function() _clock;
  Timer? _timer;
  Future<void>? _closing, _finishFuture;
  bool _disposed = false,
      _invalidated = false,
      _background = false,
      _resumeRequested = false,
      _saving = false,
      _roundRecorded = false;
  bool hasConsent = false,
      loading = false,
      bestSaved = false,
      scoreSaveFailed = false,
      bestScoreAvailable = false;
  int bestScore = 0;
  int _resumeAfterMicros = 0;
  String? error;
  bool get current {
    if (activeScope() != scope) _invalidated = true;
    return !_disposed && !_invalidated && _closing == null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _cameraChanged() {
    if (!current) {
      unawaited(close());
      return;
    }
    if (camera.error != null) {
      error = camera.error;
      engine.pause(_clock());
      loading = false;
    }
    _notify();
  }

  Future<void> startCamera({required bool consented}) async {
    if (!current || loading || !consented || _background) return;
    hasConsent = true;
    loading = true;
    error = null;
    _notify();
    try {
      final best = await bestScores.load(scope);
      if (!current) return;
      bestScore = best;
      bestScoreAvailable = true;
    } catch (_) {
      if (current) {
        bestScoreAvailable = false;
        scoreSaveFailed = true;
      }
    }
    try {
      if (!current || _background) return;
      await camera.start(_sample);
      if (!current) {
        await camera.close();
        return;
      }
      if (_background) await camera.pause();
    } catch (_) {
      if (current) {
        error = camera.error ??
            'Could not open the camera. Check camera permission and retry.';
      }
    } finally {
      if (current) {
        loading = false;
        _notify();
      }
    }
  }

  void _sample(MoveCatchTorsoSample sample) {
    if (!current || _background) return;
    final now = _clock();
    engine.updateTorso(
        centerX: sample.centerX,
        shoulderWidth: sample.shoulderWidth,
        fullTorso: sample.fullTorso,
        capturedAtMicros: sample.capturedAtMicros,
        nowMicros: now);
    if (_resumeRequested &&
        engine.trackingReady &&
        sample.capturedAtMicros >= _resumeAfterMicros) {
      _resumeRequested = false;
      engine.resume(now);
    }
    _notify();
  }

  void tick() {
    if (!current) {
      unawaited(close());
      return;
    }
    if (!hasConsent || _background || loading || error != null) return;
    engine.tick(_clock());
    if (roundTimingConsent) {
      roundTiming?.observe(
          activeMillis:
              (engine.durationMicros / 1000 - engine.remainingSeconds * 1000)
                  .round()
                  .clamp(0, 40000),
          playing: engine.phase == MoveCatchPhase.playing);
    }
    if (engine.phase == MoveCatchPhase.finished &&
        !_roundRecorded &&
        !_saving) {
      _roundRecorded = true;
      if (roundTimingConsent) roundTiming?.finish();
      _finishFuture = _finish();
      unawaited(_finishFuture);
    }
    _notify();
  }

  void startRound() {
    if (!current || loading || !camera.tracking || error != null) return;
    final previous = engine.phase;
    engine.start(_clock());
    if (roundTimingConsent &&
        previous == MoveCatchPhase.ready &&
        engine.phase == MoveCatchPhase.countdown) {
      roundTiming?.start();
    }
    _notify();
  }

  Future<void> pause() async {
    if (!current) return;
    _resumeRequested = false;
    engine.pause(_clock());
    _notify();
    try {
      await camera.pause();
    } catch (_) {
      if (current) {
        error = 'Could not pause camera. Exit and try again.';
        _notify();
      }
    }
  }

  Future<void> resume() async {
    if (!current || loading || _background || !hasConsent) return;
    loading = true;
    error = null;
    _resumeRequested = true;
    _resumeAfterMicros = _clock();
    _notify();
    try {
      await camera.resume();
      if (_background && current) await camera.pause();
    } catch (_) {
      if (current) {
        error = camera.error ?? 'Could not resume camera. Try again.';
        _resumeRequested = false;
      }
    } finally {
      if (current) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> restart() async {
    if (!current || !hasConsent || loading) return;
    loading = true;
    _notify();
    try {
      if (_finishFuture != null) await _finishFuture;
      if (!current || _background) return;
      engine.restart(_clock());
      roundTiming?.reset();
      _roundRecorded = false;
      bestSaved = false;
      scoreSaveFailed = false;
      error = null;
      _resumeRequested = false;
      await camera.resume();
    } catch (_) {
      if (current) error = 'Could not reopen camera. Try again.';
    } finally {
      if (current) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _finish() async {
    if (_saving || !current) return;
    _saving = true;
    final score = engine.score;
    try {
      await camera.pause();
      if (!current) return;
      final best =
          await bestScores.record(scope, score, isCurrent: () => current);
      if (current) {
        bestScore = best;
        bestScoreAvailable = true;
        bestSaved = true;
        scoreSaveFailed = false;
      }
    } catch (_) {
      if (current) scoreSaveFailed = true;
    } finally {
      _saving = false;
      _notify();
    }
  }

  Future<void> background() async {
    if (!current || _background) return;
    _background = true;
    await pause();
  }

  void foreground() {
    _background = false;
    _notify();
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _invalidated = true;
    _resumeRequested = false;
    _timer?.cancel();
    engine.pause(_clock());
    camera.removeListener(_cameraChanged);
    roundTiming?.reset();
    return _closing = camera.close().catchError((Object _) {});
  }

  /// Navigation must not invalidate the account guard while a completed
  /// round's already-started personal-best write is still pending.
  Future<void> finishAndClose() async {
    if (engine.phase == MoveCatchPhase.finished && current) {
      await _finishFuture;
    }
    await close();
  }

  @override
  void dispose() {
    if (_disposed) return;
    unawaited(close());
    roundTiming?.removeListener(_notify);
    roundTiming?.dispose();
    _disposed = true;
    super.dispose();
  }
}
