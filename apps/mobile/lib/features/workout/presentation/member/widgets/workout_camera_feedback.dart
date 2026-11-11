import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../application/calf_raise_workout_session.dart';
import '../../../application/curl_workout_session.dart';
import '../../../application/floor_push_up_workout_session.dart';
import '../../../application/guided_workout_progress.dart';
import '../../../application/lateral_raise_workout_session.dart';
import '../../../application/measured_workout_session.dart';
import '../../../application/pose_preview_controller.dart';
import '../../../application/real_squat_session_controller.dart';
import '../../../application/shoulder_press_workout_session.dart';
import '../../../application/workout_set_continuation.dart';
import '../../../domain/retained_workout_feedback.dart';

/// Exercise positioning copy only. The session owns camera and pose validation.
class WorkoutCameraPosition {
  const WorkoutCameraPosition(this.view, this.joints, this.startingPose);

  final String view, joints, startingPose;

  String get instruction => '$view. $joints';
  String get preparation => '$view. $startingPose';

  static WorkoutCameraPosition? forSession(MeasuredWorkoutSession session) =>
      switch (session) {
        RealSquatSessionController() => const WorkoutCameraPosition(
            'Stand side-on',
            'Keep your near shoulder, hip, knee and ankle visible.',
            'Stand tall and hold still.'),
        CurlWorkoutSession() => const WorkoutCameraPosition(
            'Stand side-on with your selected arm nearest the camera',
            'Keep that shoulder, elbow, wrist and hip visible.',
            'Lower the selected arm and hold still.'),
        CalfRaiseWorkoutSession() => const WorkoutCameraPosition(
            'Stand side-on',
            'Keep your near hip, knee, ankle, heel and toes visible.',
            'Set both heels down and hold still.'),
        FloorPushUpWorkoutSession() => const WorkoutCameraPosition(
            'Set the camera side-on near floor height',
            'Keep your near shoulder, elbow, wrist, hip and ankle visible.',
            'Hold a high plank with your arms straight.'),
        LateralRaiseWorkoutSession() => const WorkoutCameraPosition(
            'Face the camera',
            'Keep both shoulders, elbows, wrists and hips visible.',
            'Hold both arms by your sides.'),
        ShoulderPressWorkoutSession() => const WorkoutCameraPosition(
            'Face the camera',
            'Keep both shoulders, elbows, wrists and hips visible.',
            'Hold your hands above bent elbows at shoulder height.'),
        _ => null,
      };
}

enum _StatusTone { ready, attention, neutral }

class WorkoutCameraFeedback extends StatelessWidget {
  const WorkoutCameraFeedback({
    super.key,
    required this.session,
    required this.position,
    required this.continuation,
    required this.inRoutine,
  });

  final MeasuredWorkoutSession session;
  final WorkoutCameraPosition position;
  final WorkoutSetContinuation? continuation;
  final bool inRoutine;

  (String, String?, _StatusTone) get _feedback {
    final c = session;
    const ready = _StatusTone.ready;
    const neutral = _StatusTone.neutral;
    const attention = _StatusTone.attention;
    if (c.viewPhase == MeasuredWorkoutPhase.closed) {
      return ('SESSION CLOSED', 'Your account access changed.', attention);
    }
    if (c.viewPhase == MeasuredWorkoutPhase.saving) {
      return ('SAVING', null, neutral);
    }
    if (c.viewPhase == MeasuredWorkoutPhase.saveFailed) {
      return ('SAVE FAILED', c.errorMessage, attention);
    }
    if (c.preview.phase == PosePreviewPhase.failure) {
      return (
        'CAMERA UNAVAILABLE',
        c.errorMessage ?? 'Retry the camera to continue.',
        attention
      );
    }
    if (c.isManuallyPaused || c.preview.phase == PosePreviewPhase.paused) {
      return ('PAUSED', c.errorMessage, attention);
    }
    if (c.preview.phase == PosePreviewPhase.opening) {
      return ('OPENING CAMERA', position.instruction, neutral);
    }
    if (c is UnilateralWorkoutSession &&
        (c as UnilateralWorkoutSession).awaitingArmSwitch) {
      final arm = c as UnilateralWorkoutSession;
      return (
        'SWITCH ARMS',
        'Turn with your ${arm.nextArmLabel.toLowerCase()} closest to the camera.',
        neutral
      );
    }
    final flow = c.guidance;
    if (flow?.stage == GuidedWorkoutStage.complete) {
      return (
        'COMPLETE',
        inRoutine ? 'Saving routine progress.' : 'Save your result.',
        ready
      );
    }
    if (flow?.stage == GuidedWorkoutStage.resting) {
      return switch (continuation?.status) {
        SetContinuationStatus.countdown => (
            'GET READY',
            'Hold your position.',
            ready
          ),
        SetContinuationStatus.waiting => (
            'GET IN POSITION',
            position.preparation,
            neutral
          ),
        SetContinuationStatus.cancelled => (
            'AUTO-START CANCELLED',
            'Start the next set when ready.',
            attention
          ),
        _ when flow!.remainingRestSeconds == 0 => (
            'REST COMPLETE',
            'Start the next set when ready.',
            neutral
          ),
        _ => ('REST', null, neutral),
      };
    }
    final analysis = c.analysis;
    if (analysis == null ||
        !c.analysisAvailable ||
        c.preview.phase != PosePreviewPhase.tracking) {
      return ('CAMERA SETUP', position.preparation, neutral);
    }
    if (c is FloorPushUpWorkoutSession && c.hasBriefTrackingDropout) {
      return ('READY', c.readinessMessage, ready);
    }
    if (analysis.health == TrackingStatus.lost) {
      return ('TRACKING LOST', position.instruction, attention);
    }
    if (analysis.needsCalibration) {
      return ('CALIBRATING', c.calibrationCue, neutral);
    }
    if (analysis.health != TrackingStatus.healthy) {
      return ('CHECK POSITION', position.instruction, attention);
    }
    final correction = primaryWorkoutCue(analysis.cues);
    final movement = c is FloorPushUpWorkoutSession
        ? c.readinessMessage
        : c.movementCue.replaceFirst(RegExp(r'^Ready · '), '');
    return (
      'READY',
      correction != null && correction.priority != CuePriority.encouragement
          ? correction.text
          : movement,
      ready
    );
  }

  @override
  Widget build(BuildContext context) {
    final (status, cue, tone) = _feedback;
    final (background, foreground) = switch (tone) {
      _StatusTone.ready => (AppColors.successTint, AppColors.ink),
      _StatusTone.attention => (AppColors.dangerTint, AppColors.ink),
      _StatusTone.neutral => (AppColors.primaryDark, Colors.white),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Text(status,
                        style: TextStyle(
                            color: foreground,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.1)),
                  ),
                ),
              ),
              if (cue != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(3, 6, 3, 3),
                  child: Text(cue,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
