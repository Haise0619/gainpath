import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/reach_tap.dart';
import '../domain/reach_tap_camera.dart';
import '../domain/reach_tap_ports.dart';
import 'mini_game_competition_coordinator.dart';
import 'mini_game_round_coordinator.dart';

/// Camera scoring stays local; optional owned participation timing is independent
/// of local saves and competitive score reporting. Game Score cannot authorize points.
class ReachTapController extends ChangeNotifier {
  ReachTapController(
      {required this.scope,
      required this.activeScope,
      required this.camera,
      required this.history,
      required this.clockMicros,
      this.competition,
      this.roundTiming,
      this.earningAvailable,
      ReachTapEngine? engine,
      bool autoTick = true,
      String Function()? newId,
      DateTime Function()? dateTime})
      : engine = engine ?? ReachTapEngine(),
        _newId = newId ?? _id,
        _dateTime = dateTime ?? _utc {
    camera.addListener(_cameraChanged);
    competition?.addListener(_notify);
    roundTiming?.addListener(_notify);
    if (competition != null) {
      this.engine.onScoreEvent =
          (type) => competition?.event(type, this.engine.activeMillis);
    }
    if (autoTick) {
      _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => tick());
    }
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final ReachTapCamera camera;
  final ReachTapHistoryStore history;
  final ReachTapEngine engine;
  final MiniGameCompetitionCoordinator? competition;
  final MiniGameRoundCoordinator? roundTiming;
  final Future<bool> Function()? earningAvailable;
  bool roundTimingConsent = false, earningUnavailable = false;
  bool _earningRoundStarted = false;
  void setRoundTimingConsent(bool consented) {
    if (!hasConsent && roundTiming != null && current) {
      roundTimingConsent = consented;
      _notify();
    }
  }

  Future<void> _checkEarning() async {
    if (!roundTimingConsent || earningAvailable == null) return;
    try {
      if (!await earningAvailable!().timeout(const Duration(seconds: 12))) {
        roundTimingConsent = false;
        earningUnavailable = true;
      }
    } catch (_) {
      roundTimingConsent = false;
      earningUnavailable = true;
    }
  }

  final int Function() clockMicros;
  final String Function() _newId;
  final DateTime Function() _dateTime;
  static DateTime _utc() => DateTime.now().toUtc();
  static String _id() {
    final r = Random.secure();
    return List.generate(
        16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  bool _disposed = false,
      _invalidated = false,
      _background = false,
      _manualPaused = false,
      _acceptFrames = false,
      _started = false,
      _notificationPending = false;
  bool hasConsent = false,
      loading = false,
      saving = false,
      saved = false,
      saveFailed = false,
      historyAvailable = false;
  String? error;
  ReachTapHistory? localHistory;
  ReachTapRound? _round;
  Future<void>? _closing, _saving;
  Timer? _timer;
  int? _previousBest;
  bool get newPersonalBest =>
      saved &&
      _previousBest != null &&
      engine.score > _previousBest! &&
      bestScore == engine.score;
  int? get bestScore => historyAvailable ? localHistory?.bestScore : null;
  bool get current {
    if (activeScope() != scope) _invalidated = true;
    return !_disposed && !_invalidated && _closing == null;
  }

  void _notify() {
    if (_disposed || _notificationPending) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  void _cameraChanged() {
    if (!current) {
      unawaited(close());
      return;
    }
    if (engine.phase == ReachTapPhase.finished) {
      _notify();
      return;
    }
    if (camera.error != null) {
      error = camera.error;
      _manualPaused = true;
      engine.pause(clockMicros());
      _acceptFrames = false;
    } else if (_started &&
        !loading &&
        !camera.tracking &&
        !_manualPaused &&
        !_background) {
      // Hardware/lifecycle interruption is different from a missing pose.
      // Keep the camera restart deliberate; ordinary pose loss recovers in-engine.
      error = 'Camera interrupted. Resume when ready.';
      _manualPaused = true;
      _acceptFrames = false;
      engine.pause(clockMicros());
    }
    _notify();
  }

  Future<void> startCamera({required bool consented}) async {
    if (!current || loading || !consented || _background || _started) {
      return;
    }
    hasConsent = true;
    _manualPaused = false;
    engine.resume(clockMicros());
    loading = true;
    error = null;
    _notify();
    try {
      await _checkEarning();
      if (!current || _background) return;
      try {
        final result = await history.load(scope);
        if (!current) return;
        localHistory = result;
        historyAvailable = true;
      } catch (_) {
        if (current) historyAvailable = false;
      }
      if (!current || _background) return;
      _acceptFrames = true;
      await camera.start(_sample);
      if (!current) {
        await camera.close();
        return;
      }
      _started = true;
      if (_background || _manualPaused) {
        _acceptFrames = false;
        await camera.pause();
      }
    } catch (_) {
      if (current) {
        _acceptFrames = false;
        error = camera.error ??
            'Could not open camera. Check camera permission and retry.';
        engine.unavailable(clockMicros());
      }
    } finally {
      if (current) {
        loading = false;
        _notify();
      }
    }
  }

  void _sample(ReachTapSample? sample) {
    if (!current) {
      unawaited(close());
      return;
    }
    if (!hasConsent ||
        _background ||
        _manualPaused ||
        !_acceptFrames ||
        error != null) {
      return;
    }
    final now = clockMicros();
    if (sample == null) {
      engine.unavailable(now);
    } else {
      engine.update(sample, nowMicros: now);
    }
    _observeCompetition();
    _finishIfNeeded();
    _notify();
  }

  void tick() {
    if (!current) {
      unawaited(close());
      return;
    }
    if (!hasConsent || _background || loading || error != null) return;
    engine.tick(clockMicros());
    _observeCompetition();
    _finishIfNeeded();
    _notify();
  }

  void _observeCompetition() {
    final phase = engine.phase;
    if (phase == ReachTapPhase.ready ||
        phase == ReachTapPhase.countdown ||
        phase == ReachTapPhase.playing) {
      competition?.start();
      if (roundTimingConsent && !_earningRoundStarted) {
        _earningRoundStarted = true;
        roundTiming?.start();
      }
    }
    if (roundTimingConsent && _earningRoundStarted) {
      roundTiming?.observe(
          activeMillis: engine.activeMillis,
          playing: engine.phase == ReachTapPhase.playing);
    }
    competition?.observe(
        activeMillis: engine.activeMillis,
        playing: phase == ReachTapPhase.playing);
  }

  void _finishIfNeeded() {
    if (engine.phase != ReachTapPhase.finished || _round != null || !current) {
      return;
    }
    _acceptFrames = false;
    competition?.finish();
    if (roundTimingConsent && _earningRoundStarted) roundTiming?.finish();
    _previousBest = bestScore;
    _round = ReachTapRound(
        id: _newId(),
        completedAt: _dateTime().toUtc(),
        hits: engine.hits,
        score: engine.score,
        activeMicros: engine.activeMicros);
    unawaited(retrySave());
  }

  Future<void> retrySave() {
    if (_saving != null) return _saving!;
    if (!current || _round == null || saved) return Future.value();
    final completer = Completer<void>();
    _saving = completer.future;
    unawaited(
        _save().then(completer.complete, onError: completer.completeError));
    return completer.future;
  }

  Future<void> _save() async {
    saving = true;
    saveFailed = false;
    _notify();
    await Future<void>.value();
    try {
      await camera.pause();
      if (!current) return;
      final result =
          await history.record(scope, _round!, isCurrent: () => current);
      if (!current) return;
      localHistory = result;
      historyAvailable = true;
      saved = true;
    } catch (_) {
      if (current) saveFailed = true;
    } finally {
      saving = false;
      _saving = null;
      _notify();
    }
  }

  Future<void> pause() async {
    if (!current || engine.phase == ReachTapPhase.finished) return;
    _manualPaused = true;
    _acceptFrames = false;
    engine.pause(clockMicros());
    _notify();
    try {
      await camera.pause();
    } catch (_) {
      if (current) error = 'Camera pause failed. Exit and try again.';
    }
    _notify();
  }

  Future<void> resume() async {
    if (!current ||
        loading ||
        _background ||
        !hasConsent ||
        engine.phase == ReachTapPhase.finished) {
      return;
    }
    if (!_started) {
      await startCamera(consented: true);
      return;
    }
    loading = true;
    error = null;
    _manualPaused = false;
    engine.resume(clockMicros());
    _acceptFrames = true;
    _notify();
    try {
      await camera.resume();
      if (!current || _background || _manualPaused) {
        _acceptFrames = false;
        await camera.pause();
      }
    } catch (_) {
      if (current) {
        _acceptFrames = false;
        error = camera.error ?? 'Could not resume camera. Retry when ready.';
        engine.unavailable(clockMicros());
      }
    } finally {
      if (current) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> restart() async {
    if (!current ||
        loading ||
        _background ||
        engine.phase != ReachTapPhase.finished) {
      return;
    }
    loading = true;
    _notify();
    await _saving;
    if (!current) return;
    if (!saved) {
      loading = false;
      error = 'Save this result before Replay. Retry saving below.';
      _notify();
      return;
    }
    await _checkEarning();
    if (!current || _background) {
      loading = false;
      _notify();
      return;
    }
    competition?.reset();
    if (competition != null) unawaited(competition!.loadPreference());
    if (!identical(roundTiming, competition?.timing)) roundTiming?.reset();
    _earningRoundStarted = false;
    competition?.timing.reset();
    engine.restart(clockMicros());
    _round = null;
    _previousBest = null;
    saved = false;
    saveFailed = false;
    error = null;
    _manualPaused = false;
    _acceptFrames = true;
    loading = true;
    _notify();
    try {
      await camera.resume();
      if (!current || _background || _manualPaused) {
        _acceptFrames = false;
        await camera.pause();
      }
    } catch (_) {
      if (current) {
        _acceptFrames = false;
        error = 'Could not reopen camera. Retry.';
        engine.unavailable(clockMicros());
      }
    } finally {
      if (current) {
        loading = false;
        _notify();
      }
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
    _acceptFrames = false;
    _timer?.cancel();
    engine.pause(clockMicros());
    camera.removeListener(_cameraChanged);
    competition?.reset();
    competition?.timing.reset();
    if (!identical(roundTiming, competition?.timing)) roundTiming?.reset();
    return _closing = camera.close().catchError((Object _) {});
  }

  Future<void> finishAndClose() async {
    if (current && engine.phase == ReachTapPhase.finished) await _saving;
    await close();
  }

  /// Exit decisions must wait for the actual durable-save outcome before
  /// choosing whether leaving needs an unsaved-result confirmation.
  Future<void> settleSave() async => await _saving;

  @override
  void dispose() {
    if (_disposed) return;
    unawaited(close());
    competition?.removeListener(_notify);
    roundTiming?.removeListener(_notify);
    if (!identical(roundTiming, competition?.timing)) roundTiming?.dispose();
    competition?.dispose();
    competition?.timing.dispose();
    _disposed = true;
    super.dispose();
  }
}
