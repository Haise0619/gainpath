import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import '../domain/exercise_tracker_dispatcher.dart';
import '../domain/published_routine_view.dart';
import '../domain/routine_attempt.dart';
export '../domain/routine_attempt.dart' show routineDayTitle;

enum WorkoutExerciseMode { aiTracked, videoTimed, manual, unavailable }

String workoutCount(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';
String workoutRepetitionTarget(int sets, int reps, {String qualifier = ''}) =>
    '${workoutCount(sets, 'set')} × ${workoutCount(reps, 'rep')}${qualifier.isEmpty ? '' : ' · $qualifier'}';

/// Display-only projection. Existing routes/resolvers still authorize execution.
class ExercisePresentation {
  const ExercisePresentation._(this.mode, this.targetLabel, this.restLabel,
      {this.detail = '', this.setupReminder});
  factory ExercisePresentation.forExercise(PublishedRoutineExercise exercise,
      {required String organizationId,
      ExerciseTrackerDispatcher trackers = const ExerciseTrackerDispatcher()}) {
    final tracking = trackers.resolve(
        organizationId: organizationId, exerciseId: exercise.exerciseId);
    final rest = exercise.restSeconds == 0
        ? 'No rest between sets'
        : '${exercise.restSeconds} sec rest between sets';
    ExercisePrescription target;
    try {
      target = exercise.prescription;
      target.validate();
    } on FormatException {
      return ExercisePresentation._(
          WorkoutExerciseMode.unavailable, 'Targets unavailable', rest);
    }
    final timed =
        exercise.executionMode == ExerciseExecutionMode.videoGuidedTimed ||
            target is TimedPrescription;
    if (timed) {
      if (target is! TimedPrescription ||
          tracking.registeredCapability.hasPoseTracking) {
        return ExercisePresentation._(
            WorkoutExerciseMode.unavailable, 'Targets unavailable', rest);
      }
      return ExercisePresentation._(
          WorkoutExerciseMode.videoTimed,
          '${workoutCount(target.sets, 'set')} × ${target.durationSeconds} sec per set',
          rest);
    }
    final reps = (target as RepetitionPrescription).repetitions;
    final base = workoutRepetitionTarget(target.sets, reps);
    if (exercise.executionMode == ExerciseExecutionMode.legacyManual &&
            tracking.registeredCapability.hasPoseTracking ||
        exercise.executionMode == ExerciseExecutionMode.aiTracked &&
            tracking.tracker == null ||
        tracking.unavailable) {
      return ExercisePresentation._(WorkoutExerciseMode.unavailable, base, rest,
          detail: tracking.description);
    }
    if (tracking.tracker != null) {
      final qualifier = switch (tracking.tracker) {
        ExerciseTracker.sideViewCurl => ' · per arm',
        ExerciseTracker.sideViewRow => ' · per selected arm',
        ExerciseTracker.sideViewReverseLunge => ' · per selected leg',
        ExerciseTracker.frontViewShoulderPress ||
        ExerciseTracker.frontViewLateralRaise =>
          ' · both arms together',
        _ => '',
      };
      return ExercisePresentation._(
          WorkoutExerciseMode.aiTracked, '$base$qualifier', rest,
          setupReminder: switch (tracking.tracker) {
            ExerciseTracker.sideViewCurl =>
              'Choose your arm before the camera opens.',
            ExerciseTracker.sideViewCalfRaise =>
              'Confirm level ground and heel contact before the camera opens.',
            ExerciseTracker.sideViewFloorPushUp =>
              'Confirm your phone is stable and the floor space is clear.',
            _ => null,
          });
    }
    return ExercisePresentation._(
        WorkoutExerciseMode.manual, '$base · Self-reported', rest);
  }
  final WorkoutExerciseMode mode;
  final String targetLabel, restLabel, detail;
  final String? setupReminder;
  String get targetsWithRest => '$targetLabel · $restLabel';
  String get label => switch (mode) {
        WorkoutExerciseMode.aiTracked => 'AI Tracked',
        WorkoutExerciseMode.videoTimed => 'Video Timed',
        WorkoutExerciseMode.manual => 'Manual',
        WorkoutExerciseMode.unavailable => 'Unavailable',
      };
  IconData get icon => switch (mode) {
        WorkoutExerciseMode.aiTracked => Icons.videocam_outlined,
        WorkoutExerciseMode.videoTimed => Icons.timer_outlined,
        WorkoutExerciseMode.manual => Icons.checklist_rounded,
        WorkoutExerciseMode.unavailable => Icons.info_outline_rounded,
      };
  String get description => switch (mode) {
        WorkoutExerciseMode.aiTracked =>
          'Camera-based tracking with supported repetition and movement feedback.',
        WorkoutExerciseMode.videoTimed =>
          'Follow the video and timer. Repetitions and form are not measured.',
        WorkoutExerciseMode.manual =>
          'Log your completed sets. Results are self-reported.',
        WorkoutExerciseMode.unavailable => detail.isEmpty
            ? 'This exercise is unavailable. Review its targets before continuing.'
            : detail,
      };
  String get startLabel => switch (mode) {
        WorkoutExerciseMode.aiTracked => 'Start AI Workout',
        WorkoutExerciseMode.videoTimed => 'Start Timed Workout',
        WorkoutExerciseMode.manual => 'Log Workout Sets',
        WorkoutExerciseMode.unavailable => 'Review exercise',
      };
  String get provenance => switch (mode) {
        WorkoutExerciseMode.aiTracked => 'AI measured',
        WorkoutExerciseMode.videoTimed => 'Timer recorded',
        WorkoutExerciseMode.manual => 'Self-reported',
        WorkoutExerciseMode.unavailable => 'Not measured',
      };

  String get nextActionDescription => switch (mode) {
        WorkoutExerciseMode.aiTracked => setupReminder ??
            'The camera opens automatically after rest. Reps count once tracking is ready.',
        WorkoutExerciseMode.videoTimed =>
          'The next video prepares after rest. Active time starts only when playback is ready.',
        WorkoutExerciseMode.manual =>
          'The set logger opens after rest. Mark each completed set yourself.',
        WorkoutExerciseMode.unavailable =>
          'Return to the routine to review this unavailable exercise.',
      };
}

bool isExerciseTargetComplete(RoutineExerciseStatus status) => const {
      RoutineExerciseStatus.completed,
      RoutineExerciseStatus.timerCompleted,
      RoutineExerciseStatus.selfReportedCompleted,
    }.contains(status);

String exerciseStatusLabel(RoutineExerciseStatus status) => switch (status) {
      RoutineExerciseStatus.notStarted => 'Not started',
      RoutineExerciseStatus.partial => 'Partial · AI measured',
      RoutineExerciseStatus.completed => 'Completed · AI measured',
      RoutineExerciseStatus.selfReportedPartial =>
        'In progress · Self-reported',
      RoutineExerciseStatus.selfReportedCompleted =>
        'Completed · Self-reported',
      RoutineExerciseStatus.instructionsReviewed => 'Instructions reviewed',
      RoutineExerciseStatus.skipped => 'Skipped',
      RoutineExerciseStatus.timerPartial => 'In progress · Timer recorded',
      RoutineExerciseStatus.timerCompleted => 'Completed · Timer recorded',
    };

String workoutDurationLabel(int microseconds) {
  final seconds = (microseconds ~/ 1000000).clamp(0, 86400000);
  if (seconds < 60) return '$seconds sec';
  final remainder = seconds % 60;
  return '${seconds ~/ 60} min${remainder == 0 ? '' : ' $remainder sec'}';
}

String exerciseResultSummary(RoutineExerciseResult result) {
  if (result.isTimed) {
    final progress = result.guided;
    if (progress == null) return exerciseStatusLabel(result.status);
    return '${workoutCount(progress.completedSets, 'timed set')} · ${workoutDurationLabel(progress.totalActiveMicroseconds)} active · Timer recorded';
  }
  if (result.sessionIds.isNotEmpty) {
    return '${result.fullRepetitions} full reps · ${result.partialRepetitions} partial reps · ${workoutDurationLabel(result.trackedDurationMicros)} tracked · AI measured';
  }
  if (result.manualSets > 0) {
    return '${workoutCount(result.manualSets, 'set')} · Self-reported';
  }
  return exerciseStatusLabel(result.status);
}

String workoutAttemptLabel(RoutineAttempt attempt) => attempt.isComplete
    ? 'Workout Completed'
    : attempt.finished
        ? 'Partially Completed'
        : 'In Progress';
