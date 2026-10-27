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
import '../domain/curl_arm_metrics.dart';
import 'guided_workout_progress.dart';
import 'measured_workout_session.dart';
import 'pose_preview_controller.dart';
import 'workout_audio_controller.dart';

/// Local-only single-arm curl session. Never constructs an upload submission.
class CurlWorkoutSession extends ChangeNotifier
    implements MeasuredWorkoutSession, UnilateralWorkoutSession {
  CurlWorkoutSession(
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
      this.armMode = CurlArmMode.both,
      CurlSide startingSide = CurlSide.left,
      this.saveVoiceMode,
      this.provenance = WorkoutProvenance.realCamera})
      : guidance = GuidedWorkoutProgress(sets: sets, repetitions: reps),
        audio = WorkoutAudioController(port: audioPort) {
    if (repository.scope != scope ||
        ExerciseTrackingRegistry.resolve(
                    organizationId: scope.organizationId,
                    exerciseId: exerciseId)
                .trackerId !=
            ExerciseTrackingCapability.sideViewCurl.trackerId ||
        !{WorkoutProvenance.realCamera, WorkoutProvenance.recordedFixture}
            .contains(provenance)) {
      throw ArgumentError(
          'Curl session requires matching account, registered exercise and measured provenance');
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
    _firstSide = armMode == CurlArmMode.leftOnly
        ? CurlSide.left
        : armMode == CurlArmMode.rightOnly
            ? CurlSide.right
            : startingSide;
    _currentSide = _firstSide;
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
  final CurlArmMode armMode;
  final _analyzers = {
    CurlSide.left: CurlAnalyzer(side: CurlSide.left),
    CurlSide.right: CurlAnalyzer(side: CurlSide.right),
  };
  late final CurlSide _firstSide;
  late CurlSide _currentSide;
  bool _switchPending = false;
  final _setBaselines = {CurlSide.left: 0, CurlSide.right: 0};
  CurlAnalyzer get _analyzer => _analyzers[_currentSide]!;
  int get _totalReps =>
      _analyzers.values.fold(0, (n, a) => n + a.snapshot.repetitions);
  int get _totalPartial =>
      _analyzers.values.fold(0, (n, a) => n + a.snapshot.partialRepetitions);
  int get _totalTracked =>
      _analyzers.values.fold(0, (n, a) => n + a.snapshot.trackedDurationMicros);
  int get _totalRejected => _analyzers.values
      .fold(0, (n, a) => n + a.snapshot.rejectedDurationMicros);
  String _label(CurlSide side) =>
      side == CurlSide.left ? 'Left arm' : 'Right arm';
  @override
  String get armLabel => _label(_currentSide);
  @override
  String get nextArmLabel =>
      _label(_currentSide == CurlSide.left ? CurlSide.right : CurlSide.left);
  @override
  bool get awaitingArmSwitch => _switchPending;
  @override
  String get armRepetitionLabel =>
      '${_analyzer.snapshot.repetitions - _setBaselines[_currentSide]!} / ${guidance.repetitions}';
  @override
  CurlArmMetrics get armMetrics {
    if (!_authorized) {
      final empty = CurlArmResult(
          repetitions: 0, partialRepetitions: 0, formScorePercent: null);
      return CurlArmMetrics(
          mode: armMode,
          targetSets: guidance.sets,
          repetitionsPerArm: guidance.repetitions,
          completedSets: 0,
          left: empty,
          right: empty);
    }
    CurlArmResult result(CurlSide side) {
      final u = _analyzers[side]!.snapshot;
      return CurlArmResult(
          repetitions: u.repetitions,
          partialRepetitions: u.partialRepetitions,
          formScorePercent: u.formScorePercent);
    }

    return CurlArmMetrics(
        mode: armMode,
        targetSets: guidance.sets,
        repetitionsPerArm: guidance.repetitions,
        completedSets: guidance.completedSets,
        left: result(CurlSide.left),
        right: result(CurlSide.right));
  }

  @override
  void confirmArmSwitch() {
    if (!_authorized ||
        isPaused ||
        !_switchPending ||
        viewPhase != MeasuredWorkoutPhase.active) {
      return;
    }
    _currentSide =
        _currentSide == CurlSide.left ? CurlSide.right : CurlSide.left;
    _switchPending = false;
    _analyzer.pause();
    audio.resume();
    _notify();
  }

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
      !_switchPending &&
      guidance.stage == GuidedWorkoutStage.working;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  bool get isManuallyPaused => _manualPaused;
  @override
  bool get isPaused =>
      _manualPaused || !_foreground || _recalibrating || _modelChanged;
  @override
  bool get isRecalibrating => _recalibrating;
  @override
  bool get analysisAvailable => _canAnalyse && _hasFrame;
  @override
  String? get errorMessage => _error ?? preview.errorMessage;
  @override
  bool get voiceEnabled => audio.voiceEnabled;
  @override
  WorkoutVoiceMode get voiceMode => audio.voiceMode;
  @override
  String get calibrationCue =>
      '$armLabel · stand side-on with this arm facing the camera and lowered';
  @override
  String get formGuidance =>
      '${armMode.label} · ${guidance.repetitions} reps per selected arm per set. Keep the selected arm facing the camera. Start lowered, curl with control, then lower again. Switch only when prompted. Guidance is provisional; load and grip are not assessed.';
  @override
  String get movementCue => switch (_analyzer.snapshot.phase) {
        CurlPhase.ready => '$armLabel · ready to curl',
        CurlPhase.curling => 'Curl with control · keep your upper arm steady',
        CurlPhase.lowering => 'Lower with control',
      };
  @override
  WorkoutAnalysisView? get analysis {
    if (!_hasFrame || viewPhase == MeasuredWorkoutPhase.closed) return null;
    final u = _analyzer.snapshot;
    return WorkoutAnalysisView(
        repetitions: _totalReps,
        partialRepetitions: _totalPartial,
        trackedDurationMicros: _totalTracked,
        rejectedDurationMicros: _totalRejected,
        formScorePercent: armMetrics.formScorePercent,
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
    final side = _analyzer.snapshot.selectedSide;
    return age >= 0 &&
        age <= CurlAnalyzer.maximumFrameAgeMicros &&
        (side == null ? CurlSide.values : [side]).any((side) =>
            CurlGeometry.confidence(frame, side) >= .65 &&
            CurlGeometry.fromFrame(frame, side) != null);
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
    guidance.observe(_totalReps ~/ (armMode == CurlArmMode.both ? 2 : 1),
        nowMicros: clockMicros());
    if (previous != guidance.stage) _suspendAnalysis();
    if (guidance.stage == GuidedWorkoutStage.working &&
        armMode == CurlArmMode.both &&
        _currentSide == _firstSide &&
        update.repetitions - _setBaselines[_currentSide]! >=
            guidance.repetitions) {
      _switchPending = true;
      _suspendAnalysis();
    }
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
      await preview.resume();
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
    } else if (!_manualPaused) {
      if (!_recalibrating) {
        guidance.resumeClock(clockMicros());
        audio.resume();
      }
      if (_deferred) {
        _deferred = false;
        await preview.start(consented: true);
      } else {
        await preview.foreground();
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
      for (final side in CurlSide.values) {
        _setBaselines[side] = _analyzers[side]!.snapshot.repetitions;
      }
      _currentSide = _firstSide;
      _analyzer.pause();
      audio.resume();
      _notify();
    }
  }

  @override
  void beginRecalibration() {
    if (!_authorized ||
        isPaused ||
        _switchPending ||
        viewPhase != MeasuredWorkoutPhase.active) {
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
        final arms = armMetrics;
        final elapsed = (clockMicros() - _startedMicros!).clamp(1, 86400000000);
        summary = WorkoutSessionSummary(
            sessionId: sessionId,
            userId: scope.userId,
            organizationId: scope.organizationId,
            exerciseId: exerciseId,
            repetitions: _totalReps,
            accuracy: arms.formScorePercent?.round() ?? 0,
            startedAt: _startedAt!,
            endedAt: _startedAt!.add(Duration(microseconds: elapsed)),
            provenance: provenance,
            poseMetrics: WorkoutPoseMetrics(
                curlArms: arms,
                partialRepetitions: _totalPartial,
                trackedDurationMicros: _totalTracked,
                rejectedDurationMicros: _totalRejected,
                formScorePercent: arms.formScorePercent,
                scoringVersion: CurlAnalyzer.version,
                detectorId: detectorId,
                detectorVersion: detectorVersion,
                cameraView: 'side',
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
