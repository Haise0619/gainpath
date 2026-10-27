import 'package:flutter/foundation.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import '../domain/workout_contracts.dart';
import '../domain/workout_audio_port.dart';
import '../domain/curl_arm_metrics.dart';
import 'guided_workout_progress.dart';
import 'pose_preview_controller.dart';

enum MeasuredWorkoutPhase { idle, active, saving, saveFailed, saved, closed }

/// Optional controls for exercises that deliberately track one arm at a time.
abstract interface class UnilateralWorkoutSession {
  String get armLabel;
  String get armRepetitionLabel;
  String get nextArmLabel;
  bool get awaitingArmSwitch;
  CurlArmMetrics get armMetrics;
  void confirmArmSwitch();
}

/// Display-only snapshot; exercise-specific geometry and state machines stay isolated.
class WorkoutAnalysisView {
  const WorkoutAnalysisView(
      {required this.repetitions,
      required this.partialRepetitions,
      required this.trackedDurationMicros,
      required this.rejectedDurationMicros,
      required this.formScorePercent,
      required this.needsCalibration,
      required this.health,
      required this.cues});
  final int repetitions,
      partialRepetitions,
      trackedDurationMicros,
      rejectedDurationMicros;
  final double? formScorePercent;
  final bool needsCalibration;
  final TrackingStatus health;
  final List<CueRequest> cues;
}

abstract interface class MeasuredWorkoutSession implements Listenable {
  PosePreviewController get preview;
  GuidedWorkoutProgress? get guidance;
  MeasuredWorkoutPhase get viewPhase;
  WorkoutAnalysisView? get analysis;
  bool get analysisAvailable;
  bool get isManuallyPaused;
  bool get isPaused;
  bool get isRecalibrating;
  bool get canConfirmRecalibration;
  bool get voiceEnabled;
  WorkoutVoiceMode get voiceMode;
  String? get errorMessage;
  String get calibrationCue;
  String get movementCue;
  String get formGuidance;
  Future<void> pause();
  Future<void> resume();
  Future<void> close();
  Future<WorkoutSessionSummary?> endAndSave();
  void beginRecalibration();
  void finishRecalibration();
  void setRestSeconds(int seconds);
  void startNextSet({bool skipRest = false});
  void setVoiceMode(WorkoutVoiceMode mode, {bool persist = true});
}
