import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'workout_audio_controller.dart';
import '../../../infrastructure/pose/real_squat_performance.dart';
import '../../../infrastructure/pose/squat_decision_diagnostics.dart';

/// Step 3 analysis/audio boundary. The caller supplies refined camera poses;
/// this class does not open a camera, authorize consent, save, or upload sessions.
/// Camera setup confirmations are assumptions, not automated view validation.
class SquatProcessingController extends ChangeNotifier {
  SquatProcessingController({
    required this.scope,
    required this.activeScope,
    required this.audio,
    required this.clockMicros,
    this.performance,
    required bool sideViewConfirmed,
    required bool uprightCameraConfirmed,
    SquatAnalyzer? analyzer,
  }) : _analyzer = analyzer ??
            SquatAnalyzer(diagnostics: createSquatDiagnosticRecorder()) {
    if (!sideViewConfirmed || !uprightCameraConfirmed) {
      throw ArgumentError(
          'Side-view squat analysis requires confirmed upright camera setup');
    }
  }

  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final WorkoutAudioController audio;
  final int Function() clockMicros;
  final RealSquatPerformance? performance;
  final SquatAnalyzer _analyzer;
  SquatUpdate? _update;
  SquatUpdate? get update => _update;
  bool _closed = false,
      _disposed = false,
      _manualPause = false,
      _foreground = true;
  bool get isClosed => _closed;
  bool get isPaused => _manualPause || !_foreground;
  Timer? _watchdog;
  int? _lastCapture, _lastNow;
  Future<void>? _closing;
  int _lastDiagnosticSequence = 0;
  void _emitDiagnostics() {
    if (squatDecisionDiagnosticsEnabled && activeScope() == scope) {
      _lastDiagnosticSequence = emitSquatDecisionRecords(
          _analyzer.diagnostics, _lastDiagnosticSequence);
    }
  }

  bool _checkScope() {
    if (_closed) return false;
    if (activeScope() == scope) return true;
    unawaited(close());
    return false;
  }

  /// Refined means inverse-ROI landmarks before preview One Euro smoothing.
  /// Feeding the already filtered preview frame would apply smoothing twice.
  SquatUpdate? consumeRefined(PoseFrame frame) {
    if (!_checkScope() || isPaused) return null;
    final now = clockMicros();
    final time = frame.capturedAtMicros;
    if (time < 0 ||
        time > now ||
        (_lastCapture != null && time <= _lastCapture!) ||
        (_lastNow != null && now < _lastNow!)) {
      return null;
    }
    final timer = performance == null ? null : (Stopwatch()..start());
    final next = _analyzer.update(frame, nowMicros: now);
    if (timer != null) {
      timer.stop();
      performance!.analyzed(timer.elapsedMicroseconds);
    }
    _emitDiagnostics();
    _lastCapture = time;
    _lastNow = now;
    _watchdog ??= Timer.periodic(
        const Duration(milliseconds: 100), (_) => checkFreshness());
    _publish(next, now);
    return next;
  }

  void checkFreshness() {
    if (!_checkScope() || isPaused || _lastCapture == null) return;
    final now = clockMicros();
    if (_lastNow != null && now <= _lastNow!) return;
    _lastNow = now;
    final next = _analyzer.tick(nowMicros: now);
    _emitDiagnostics();
    _publish(next, now);
  }

  void _publish(SquatUpdate next, int now) {
    final lost = next.health == TrackingStatus.lost &&
        _update?.health != TrackingStatus.lost;
    _update = next;
    audio.consume([
      ...next.cues,
      if (lost)
        const CueRequest(
            id: 'squat_tracking_lost',
            text: 'Tracking lost. Stand fully in view to recalibrate.',
            priority: CuePriority.warning),
    ],
        nowMicros: now,
        trackingAvailable:
            next.health == TrackingStatus.healthy && !next.needsCalibration);
    if (!_disposed) notifyListeners();
  }

  void applyPreferences(MemberPreferences preferences) {
    if (_checkScope()) audio.applyPreferences(preferences);
  }

  void setVoiceEnabled(bool enabled) {
    if (_checkScope()) audio.setVoiceEnabled(enabled);
  }

  void _suspendAnalysis(
      {SquatDiagnosticReason diagnosticReason = SquatDiagnosticReason.paused}) {
    _watchdog?.cancel();
    _watchdog = null;
    _analyzer.pause(diagnosticReason: diagnosticReason);
    _emitDiagnostics();
    _update = null;
    if (!_disposed) notifyListeners();
  }

  void pause() {
    if (!_checkScope() || _manualPause) return;
    _manualPause = true;
    audio.pause();
    _suspendAnalysis();
  }

  void resume() {
    if (!_checkScope() || !_manualPause) return;
    _manualPause = false;
    if (_foreground) {
      _analyzer.resume();
      audio.resume();
    }
    if (!_disposed) notifyListeners();
  }

  void setForeground(bool foreground) {
    if (!_checkScope() || _foreground == foreground) return;
    _foreground = foreground;
    audio.setForeground(foreground);
    if (!foreground) {
      _suspendAnalysis(diagnosticReason: SquatDiagnosticReason.backgrounded);
    } else if (!_manualPause) {
      _analyzer.resume();
      audio.resume();
      if (!_disposed) notifyListeners();
    }
  }

  /// Call immediately on auth changes; the frame/watchdog guards also enforce it.
  void accountChanged() => _checkScope();

  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _watchdog?.cancel();
    _watchdog = null;
    _analyzer.pause(diagnosticReason: SquatDiagnosticReason.sessionClosed);
    _emitDiagnostics();
    _analyzer.diagnostics?.clear();
    _update = null;
    _closing = audio.close();
    if (!_disposed) notifyListeners();
    return _closing!;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
