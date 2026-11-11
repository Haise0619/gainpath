import 'workout_set_continuation.dart';
import 'workout_set_readiness.dart';
import 'workout_voice_session.dart';
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
import '../domain/workout_feedback_event.dart';
import '../domain/workout_audio_trace.dart';
import 'guided_workout_progress.dart';
import 'measured_workout_session.dart';
import 'pose_preview_controller.dart';
import 'workout_audio_controller.dart';

/// Local-only floor push-up session. Never constructs an upload submission.
class FloorPushUpWorkoutSession extends ChangeNotifier
    implements
        WorkoutSetContinuationSession,
        WorkoutVoiceSession,
        MeasuredWorkoutSession,
        WorkoutReadinessFeedback {
  FloorPushUpWorkoutSession(
      {required this.scope,
      required this.activeScope,
      required PoseCameraSource camera,
      required Future<ManagedPoseDetector> Function() detectorFactory,
      required WorkoutAudioPort audioPort,
      required this.repository,
      required this.clockMicros,
      required this.sessionId,
      required this.exerciseId,
      this.publishedRoutineId,
      required this.detectorId,
      required this.detectorVersion,
      required int sets,
      required int reps,
      this.saveVoiceMode,
      this.onLocalDiagnostics,
      this.audioTrace,
      this.provenance = WorkoutProvenance.realCamera})
      : guidance = GuidedWorkoutProgress(sets: sets, repetitions: reps),
        audio = WorkoutAudioController(
            port: audioPort,
            trace: audioTrace,
            boundedStarts: true,
            quietPeriodMicros: 2000000,
            arbiter: AudioCueArbiter(cooldownMicros: 6000000)) {
    if (repository.scope != scope ||
        ExerciseTrackingRegistry.resolve(
                    organizationId: scope.organizationId,
                    exerciseId: exerciseId)
                .trackerId !=
            ExerciseTrackingCapability.sideViewFloorPushUp.trackerId ||
        !{WorkoutProvenance.realCamera, WorkoutProvenance.recordedFixture}
            .contains(provenance)) {
      throw ArgumentError(
          'Floor push-up session requires matching account, registered exercise and measured provenance');
    }
    preview = PosePreviewController(
        scope: scope,
        activeScope: activeScope,
        camera: camera,
        detectorFactory: detectorFactory,
        clockMicros: clockMicros,
        responsivePreview: false,
        onRefined: _consume,
        onGeometryInvalidated: () {
          setContinuation.cancel();
          _analyzer.pause();
          audio.invalidateSource();
        });
    preview.addListener(_cameraChanged);
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final WorkoutRepository repository;
  final int Function() clockMicros;
  final String sessionId, exerciseId, detectorId, detectorVersion;
  final String? publishedRoutineId;
  final WorkoutProvenance provenance;
  final Future<void> Function(WorkoutVoiceMode)? saveVoiceMode;
  final void Function(Map<String, Object?>)? onLocalDiagnostics;
  final WorkoutAudioTrace? audioTrace;
  int _lastAttemptOutcome = 0;
  static const _attemptCueIds = {
    'floor_extension',
    'floor_depth',
    'floor_good'
  };
  // Normal application sessions never expose the former developer overlay.
  static const debugEnabled = false;

  /// Read latest state explicitly in a developer build. No trace is retained.
  Map<String, Object?> get localDiagnostics => {
        'analyzer': _analyzer.diagnostics,
        'pipeline': preview.diagnostics,
      };
  String _stableReadiness = 'Hold a high plank with arms extended to begin.';
  bool get hasBriefTrackingDropout => _analyzer.snapshot.temporaryDropout;

  @override
  String get readinessMessage {
    final u = _analyzer.snapshot;
    if (u.temporaryDropout) return _stableReadiness;
    if (u.needsCalibration || u.health != TrackingStatus.healthy) {
      return u.calibrationCue;
    }
    return u.phase == FloorPushUpPhase.top
        ? 'Ready — start your push-ups.'
        : movementCue;
  }

  void _diagnose() {
    if (!kReleaseMode && onLocalDiagnostics != null) {
      onLocalDiagnostics!(localDiagnostics);
    }
  }

  final WorkoutAudioController audio;

  @override
  late final setContinuation = WorkoutSetContinuation(
      guidance: () => guidance,
      clockMicros: clockMicros,
      canContinue: () =>
          _authorized &&
          !isPaused &&
          viewPhase == MeasuredWorkoutPhase.active &&
          preview.phase == PosePreviewPhase.tracking,
      detectorId: detectorId,
      detectorVersion: detectorVersion,
      createProbe: () => WorkoutSetReadiness.floor(
          _analyzer.snapshot.selectedSide, _analyzer.rules),
      startNextSet: startNextSet,
      audio: audio);
  final FloorPushUpAnalyzer _analyzer = FloorPushUpAnalyzer();
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
  WorkoutAudioController get voiceFeedback => audio;
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
      'Use Left Side View or Right Side View at floor height. Keep shoulders, elbows, wrists, hips and ankles visible in a floor plank. Lower with control and extend fully. Only projected visible-side depth, alignment, control and extension are estimated. Elbow flare, load and floor contact are not measured. Guidance is provisional.';
  @override
  String get movementCue => switch (_analyzer.snapshot.phase) {
        FloorPushUpPhase.ready => 'Hold your floor plank to start',
        FloorPushUpPhase.top => 'Arms extended · lower with control',
        FloorPushUpPhase.descending => 'Lower your chest · keep hips aligned',
        FloorPushUpPhase.bottom => 'Depth reached · push up with control',
        FloorPushUpPhase.ascending => 'Push up · extend your arms fully',
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
    final side = _analyzer.snapshot.selectedSide;
    return age >= 0 &&
        age <= FloorPushUpAnalyzer.maximumFrameAgeMicros &&
        (side == null ? FloorPushUpSide.values : [side]).any((side) {
          final g = FloorPushUpGeometry.fromFrame(frame, side);
          return g != null &&
              g.usableView(_analyzer.rules) &&
              g.elbowAngleDegrees >= _analyzer.rules.topAngle;
        });
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
        setContinuation.update();
      }
      if (_canAnalyse) {
        final u = _analyzer.tick(nowMicros: clockMicros());
        audio.consume(u.cues.where((c) => !_attemptCueIds.contains(c.id)),
            nowMicros: clockMicros(),
            trackingAvailable: u.observationAccepted,
            invalidateFeedback: u.health == TrackingStatus.lost);
        _diagnose();
      }
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
    if (!_canAnalyse) {
      if (guidance.stage == GuidedWorkoutStage.resting) {
        setContinuation.update(frame: frame);
      }
      return;
    }
    if (frame.detectorId != detectorId ||
        frame.modelVersion != detectorVersion) {
      _modelChanged = true;
      _error = 'Pose model changed. End this session and start again.';
      unawaited(pause());
      return;
    }
    _hasFrame = true;
    final now = clockMicros();
    final update = _analyzer.update(frame, nowMicros: now);
    if (update.health == TrackingStatus.healthy) {
      _stableReadiness = readinessMessage;
    }
    _diagnose();
    final outcome = update.repetitions + update.partialRepetitions;
    final events = <WorkoutFeedbackEvent>[];
    if (outcome > _lastAttemptOutcome && update.observationAccepted) {
      for (final cue
          in update.cues.where((c) => _attemptCueIds.contains(c.id))) {
        final event = WorkoutFeedbackEvent(
            id: 'floor-attempt-$outcome-${cue.id}',
            cue: cue,
            observedAtMicros: frame.capturedAtMicros,
            generatedAtMicros: now);
        events.add(event);
        audioTrace?.record('exercise_event_generated',
            requestId: event.id,
            cueId: cue.id,
            observedAtMicros: frame.capturedAtMicros);
      }
    }
    _lastAttemptOutcome = outcome;
    audio.consume(update.cues.where((c) => !_attemptCueIds.contains(c.id)),
        events: events,
        nowMicros: now,
        observedAtMicros: frame.capturedAtMicros,
        trackingAvailable: update.observationAccepted,
        invalidateFeedback:
            !update.observationAccepted && !update.temporaryDropout);
    final previous = guidance.stage;
    guidance.observe(update.repetitions, nowMicros: clockMicros());
    if (previous != guidance.stage) {
      // No further analysis/cues run during rest/completion. Permit this last
      // bounded attempt event to finish; explicit pause/finish still cancels.
      _analyzer.pause();
      setContinuation.finishBoundary();
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

  void _suspendAnalysis({bool preserveFeedback = false}) {
    _analyzer.pause();
    if (preserveFeedback) {
      setContinuation.finishBoundary();
    } else {
      setContinuation.cancel();
      audio.pause();
    }
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
    if (!_authorized) return;
    audio.setForeground(foreground);
    if (viewPhase != MeasuredWorkoutPhase.active) {
      if (!foreground) await preview.background();
      return;
    }
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
      setContinuation.leaveRest();
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
        _analyzer.finish();
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
                scoringVersion: FloorPushUpAnalyzer.version,
                floorPushUp: FloorPushUpMetrics(
                    side: u.selectedSide?.name,
                    components: u.components?.toJson(),
                    issueCounts: u.issueCounts
                        .map((key, value) => MapEntry(key.name, value))),
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
      _suspendAnalysis(
          preserveFeedback: guidance.stage == GuidedWorkoutStage.complete);
      _notify();
      // Persist the frozen observation before optional hardware cleanup.
      await repository.saveLocal(summary!);
      await audio.settleFeedback();
      await audio
          .close()
          .timeout(const Duration(seconds: 5))
          .catchError((Object _) {});
      await preview.close().catchError((Object _) {});
      if (!_authorized) return null;
      viewPhase = MeasuredWorkoutPhase.saved;
      return summary;
    } catch (_) {
      await audio
          .close()
          .timeout(const Duration(seconds: 5))
          .catchError((Object _) {});
      await preview.close().catchError((Object _) {});
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
    setContinuation.cancel();
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
    setContinuation.dispose();
    super.dispose();
  }
}
