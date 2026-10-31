import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, MemberPreferences;
import 'package:gainpath_domain/workout.dart'
    show ExerciseTrackingRegistry, ExerciseTrackingCapability;
import 'package:gainpath_pose/gainpath_pose.dart';
import '../domain/workout_contracts.dart';
import '../domain/real_workout_contract.dart' show workoutConsentVersion;
import '../domain/workout_audio_port.dart';
import 'guided_workout_progress.dart';
import 'measured_workout_session.dart';
import 'pose_preview_controller.dart';
import 'workout_audio_controller.dart';

/// Local-only bilateral front-view standing lateral raise session. Never constructs an upload submission.
class LateralRaiseWorkoutSession extends ChangeNotifier
    implements MeasuredWorkoutSession {
  LateralRaiseWorkoutSession(
      {required this.scope,
      required this.activeScope,
      required PoseCameraSource camera,
      required Future<ManagedPoseDetector> Function() detectorFactory,
      required WorkoutAudioPort audioPort,
      required this.repository,
      required this.clockMicros,
      required this.sessionId,
      required this.exerciseId,
      required this.publishedRoutineId,
      required this.detectorId,
      required this.detectorVersion,
      required int sets,
      required int reps,
      this.saveVoiceMode,
      this.provenance = WorkoutProvenance.realCamera})
      : _analyzer = LateralRaiseAnalyzer(),
        guidance = GuidedWorkoutProgress(sets: sets, repetitions: reps),
        audio = WorkoutAudioController(port: audioPort) {
    if (repository.scope != scope ||
        ExerciseTrackingRegistry.resolve(
                    organizationId: scope.organizationId,
                    exerciseId: exerciseId)
                .trackerId !=
            ExerciseTrackingCapability.frontViewLateralRaise.trackerId ||
        !{WorkoutProvenance.realCamera, WorkoutProvenance.recordedFixture}
            .contains(provenance)) {
      throw ArgumentError(
          'Lateral raise requires matching account, registered exercise and measured provenance');
    }
    preview = PosePreviewController(
        scope: scope,
        activeScope: activeScope,
        camera: camera,
        detectorFactory: detectorFactory,
        clockMicros: clockMicros,
        onRefined: _consume,
        onGeometryInvalidated: () => _analyzer.pause());
    preview.addListener(_cameraChanged);
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final WorkoutRepository repository;
  final int Function() clockMicros;
  final String sessionId,
      exerciseId,
      publishedRoutineId,
      detectorId,
      detectorVersion;
  final WorkoutProvenance provenance;
  final Future<void> Function(WorkoutVoiceMode)? saveVoiceMode;
  final WorkoutAudioController audio;
  final LateralRaiseAnalyzer _analyzer;

  @override
  final GuidedWorkoutProgress guidance;
  @override
  late final PosePreviewController preview;
  @override
  MeasuredWorkoutPhase viewPhase = MeasuredWorkoutPhase.idle;
  WorkoutSessionSummary? summary;
  bool _disposed = false,
      _manualPaused = false,
      _foreground = true,
      _recalibrating = false,
      _hasFrame = false,
      _modelChanged = false,
      _voiceOverridden = false,
      _deferred = false;
  String? _error;
  DateTime? _startedAt;
  int? _startedMicros;
  Timer? _timer;
  Future<WorkoutSessionSummary?>? _saving;
  Future<void>? _closing;
  bool get _authorized =>
      !_disposed &&
      activeScope() == scope &&
      viewPhase != MeasuredWorkoutPhase.closed;
  bool get _canAnalyse =>
      _authorized &&
      viewPhase == MeasuredWorkoutPhase.active &&
      !isPaused &&
      guidance.stage == GuidedWorkoutStage.working;
  bool _notificationPending = false;
  void _notify() {
    if (_disposed || _notificationPending) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  bool get isManuallyPaused => _manualPaused;
  @override
  bool get isPaused =>
      _manualPaused || !_foreground || _recalibrating || _modelChanged;
  @override
  bool get isRecalibrating => _recalibrating;
  @override
  bool get analysisAvailable =>
      _canAnalyse &&
      _hasFrame &&
      _analyzer.snapshot.health == TrackingStatus.healthy;
  @override
  String? get errorMessage => _error ?? preview.errorMessage;
  @override
  bool get voiceEnabled => audio.voiceEnabled;
  @override
  WorkoutVoiceMode get voiceMode => audio.voiceMode;
  @override
  String get calibrationCue {
    final status = _analyzer.snapshot;
    return status.needsCalibration && status.calibrationProgress > 0
        ? '${status.calibrationCue} · ${(status.calibrationProgress * 100).floor()}%'
        : status.calibrationCue;
  }

  @override
  String get formGuidance =>
      'Face the camera with a steady upright torso. Keep both shoulders, elbows, wrists and hips visible, with room on both sides. Hold arms by your sides to calibrate automatically. Raise both arms out to shoulder height with a slight elbow bend, then lower to your sides. One complete bilateral cycle is one rep. The camera does not assess load, spinal alignment or three-dimensional shoulder mechanics; no form score is produced.';
  @override
  String get movementCue => _analyzer.snapshot.requiresBottomReset
      ? _analyzer.snapshot.calibrationCue
      : switch (_analyzer.snapshot.phase) {
          LateralRaisePhase.ready =>
            'Ready · arms relaxed by your sides',
          LateralRaisePhase.raising => 'Raise both arms out to shoulder height',
          LateralRaisePhase.lowering =>
            'Lower both arms with control to your sides',
        };

  /// Scalar-only diagnostics available to local tests/debugging; no frame data
  /// or image uploads and no reward/acceptance authority.
  Map<String, Object?> get decisionDiagnostics => {
        'revision': LateralRaiseAnalyzer.implementationRevision,
        'decision': _analyzer.snapshot.decision,
        'needsCalibration': _analyzer.snapshot.needsCalibration,
        'requiresBottomReset': _analyzer.snapshot.requiresBottomReset,
        'health': _analyzer.snapshot.health.name,
        'phase': _analyzer.snapshot.phase.name,
        'repetitions': _analyzer.snapshot.repetitions,
      };
  @override
  WorkoutAnalysisView? get analysis {
    if (!_hasFrame || viewPhase == MeasuredWorkoutPhase.closed) return null;
    final u = _analyzer.snapshot;
    return WorkoutAnalysisView(
        repetitions: u.repetitions,
        partialRepetitions: u.partialRepetitions,
        trackedDurationMicros: u.trackedDurationMicros,
        rejectedDurationMicros: u.rejectedDurationMicros,
        formScorePercent: u.formScorePercent,
        needsCalibration: u.needsCalibration,
        health: u.health,
        cues: u.cues);
  }

  @override
  bool get canConfirmRecalibration {
    final frame = preview.frame;
    if (!_authorized || !_foreground || !_recalibrating || frame == null) {
      return false;
    }
    final age = clockMicros() - frame.capturedAtMicros;
    final geometry = LateralRaiseGeometry.fromFrame(frame);
    return age >= 0 &&
        age <= LateralRaiseAnalyzer.maximumFrameAgeMicros &&
        geometry != null &&
        geometry.neutral &&
        geometry.symmetric;
  }

  Future<void> start(
      {required bool consented,
      required bool setupConfirmed,
      bool foreground = true}) async {
    if (!_authorized ||
        !consented ||
        !setupConfirmed ||
        viewPhase != MeasuredWorkoutPhase.idle) {
      return;
    }
    _startedAt = DateTime.now().toUtc();
    _startedMicros = clockMicros();
    _foreground = foreground;
    viewPhase = MeasuredWorkoutPhase.active;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_authorized) {
        unawaited(close());
        return;
      }
      if (viewPhase != MeasuredWorkoutPhase.active) return;
      if (guidance.stage == GuidedWorkoutStage.resting && !isPaused) {
        guidance.tick(clockMicros());
      }
      if (_canAnalyse) _analyzer.tick(nowMicros: clockMicros());
      _notify();
    });
    if (!foreground) {
      _deferred = true;
      guidance.suspend(clockMicros());
      audio.setForeground(false);
      _notify();
      return;
    }
    await preview.start(consented: true);
  }

  void _consume(PoseFrame frame) {
    if (!_canAnalyse) return;
    if (frame.detectorId != detectorId ||
        frame.modelVersion != detectorVersion) {
      _modelChanged = true;
      _error = 'Pose model changed. End this session and start again.';
      unawaited(pause());
      return;
    }
    _hasFrame = true;
    final update = _analyzer.update(frame, nowMicros: clockMicros());
    audio.consume(update.cues,
        nowMicros: clockMicros(),
        trackingAvailable: update.health == TrackingStatus.healthy &&
            !update.needsCalibration);
    final previous = guidance.stage;
    guidance.observe(update.repetitions, nowMicros: clockMicros());
    if (previous != guidance.stage) _suspendAnalysis();
    _notify();
  }

  void _cameraChanged() {
    if (!_authorized) {
      unawaited(close());
      return;
    }
    if (preview.phase == PosePreviewPhase.failure) _suspendAnalysis();
    _notify();
  }

  void _suspendAnalysis() {
    _analyzer.pause();
    audio.pause();
  }

  @override
  Future<void> pause() async {
    if (!_authorized || viewPhase != MeasuredWorkoutPhase.active) return;
    _manualPaused = true;
    guidance.suspend(clockMicros());
    _suspendAnalysis();
    await preview.pause().catchError((Object _) {
      _error = 'Camera shutdown failed. Counting is paused.';
    });
    _notify();
  }

  @override
  Future<void> resume() async {
    if (!_authorized ||
        viewPhase != MeasuredWorkoutPhase.active ||
        _modelChanged) {
      return;
    }
    _manualPaused = false;
    if (_foreground && !_recalibrating) {
      guidance.resumeClock(clockMicros());
      audio.resume();
      if (_deferred) {
        _deferred = false;
        await preview.start(consented: true);
      } else {
        await preview.resume();
      }
    }
    _notify();
  }

  Future<void> setForeground(bool foreground) async {
    _foreground = foreground;
    if (!_authorized || viewPhase != MeasuredWorkoutPhase.active) return;
    audio.setForeground(foreground);
    if (!foreground) {
      guidance.suspend(clockMicros());
      _suspendAnalysis();
      await preview.background();
    } else {
      if (!_manualPaused && !_recalibrating) {
        guidance.resumeClock(clockMicros());
        audio.resume();
      }
      // Clear the preview background flag even when manual pause is retained.
      await preview.foreground();
      if (_deferred && !_manualPaused) {
        _deferred = false;
        await preview.start(consented: true);
      }
    }
    _notify();
  }

  void accountChanged() {
    if (activeScope() != scope) unawaited(close());
  }

  void applyPreferences(MemberPreferences preferences) {
    if (_authorized && !_voiceOverridden) audio.applyPreferences(preferences);
  }

  void applySavedVoiceMode(WorkoutVoiceMode mode) {
    if (_authorized && !_voiceOverridden) {
      audio.setVoiceMode(mode);
      _notify();
    }
  }

  @override
  void setVoiceMode(WorkoutVoiceMode mode, {bool persist = true}) {
    if (!_authorized) return;
    _voiceOverridden = true;
    audio.setVoiceMode(mode);
    if (persist) {
      unawaited(saveVoiceMode?.call(mode).catchError((Object _) {}) ??
          Future<void>.value());
    }
    _notify();
  }

  @override
  void setRestSeconds(int seconds) {
    if (_authorized && viewPhase == MeasuredWorkoutPhase.active) {
      guidance.setRestSeconds(seconds);
      _notify();
    }
  }

  @override
  void startNextSet({bool skipRest = false}) {
    if (!_authorized || isPaused || viewPhase != MeasuredWorkoutPhase.active) {
      return;
    }
    if (guidance.startNextSet(nowMicros: clockMicros(), skipRest: skipRest)) {
      _analyzer.pause();
      audio.resume();
      _notify();
    }
  }

  @override
  void beginRecalibration() {
    if (!_authorized || isPaused || viewPhase != MeasuredWorkoutPhase.active) {
      return;
    }
    _recalibrating = true;
    guidance.suspend(clockMicros());
    _suspendAnalysis();
    _notify();
  }

  @override
  void finishRecalibration() {
    if (!canConfirmRecalibration) return;
    _recalibrating = false;
    if (!_manualPaused) {
      guidance.resumeClock(clockMicros());
      audio.resume();
    }
    _notify();
  }

  @override
  Future<WorkoutSessionSummary?> endAndSave() {
    if (_saving != null) return _saving!;
    if (viewPhase == MeasuredWorkoutPhase.saved) return Future.value(summary);
    if (!_authorized || !_hasFrame) {
      _error =
          'No camera frames were analyzed. Retry the camera or discard this session.';
      _notify();
      return Future.value(null);
    }
    final completion = Completer<WorkoutSessionSummary?>();
    _saving = completion.future;
    unawaited(
        _save().then(completion.complete, onError: completion.completeError));
    return completion.future;
  }

  Future<WorkoutSessionSummary?> _save() async {
    await Future<void>.value();
    try {
      if (!_authorized) return null;
      if (summary == null) {
        _analyzer.tick(nowMicros: clockMicros());
        final u = _analyzer.snapshot;
        final elapsed = (clockMicros() - _startedMicros!).clamp(1, 86400000000);
        summary = WorkoutSessionSummary(
            sessionId: sessionId,
            userId: scope.userId,
            organizationId: scope.organizationId,
            exerciseId: exerciseId,
            repetitions: u.repetitions,
            accuracy: u.formScorePercent?.round() ?? 0,
            startedAt: _startedAt!,
            endedAt: _startedAt!.add(Duration(microseconds: elapsed)),
            provenance: provenance,
            poseMetrics: WorkoutPoseMetrics(
                partialRepetitions: u.partialRepetitions,
                trackedDurationMicros: u.trackedDurationMicros,
                rejectedDurationMicros: u.rejectedDurationMicros,
                formScorePercent: u.formScorePercent,
                scoringVersion: LateralRaiseAnalyzer.version,
                detectorId: detectorId,
                detectorVersion: detectorVersion,
                cameraView: 'front',
                consentVersion: workoutConsentVersion,
                consentedAt: _startedAt!,
                publishedRoutineId: publishedRoutineId));
      }
      viewPhase = MeasuredWorkoutPhase.saving;
      _error = null;
      _timer?.cancel();
      _suspendAnalysis();
      _notify();
      await audio.close();
      await preview.close().catchError((Object _) {});
      if (!_authorized) return null;
      await repository.saveLocal(summary!);
      if (!_authorized) return null;
      viewPhase = MeasuredWorkoutPhase.saved;
      return summary;
    } catch (_) {
      if (_authorized) {
        viewPhase = MeasuredWorkoutPhase.saveFailed;
        _error =
            'Could not save on this device. Retry to save the same result.';
      }
      return null;
    } finally {
      _saving = null;
      _notify();
    }
  }

  @override
  Future<void> close() {
    if (_closing != null) return _closing!;
    viewPhase = MeasuredWorkoutPhase.closed;
    _timer?.cancel();
    _analyzer.pause();
    preview.removeListener(_cameraChanged);
    summary = null;
    _notify();
    return _closing =
        Future.wait([audio.close(), preview.close().catchError((Object _) {})])
            .then((_) {});
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(close());
    preview.dispose();
    super.dispose();
  }
}
