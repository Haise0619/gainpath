import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'exercise_tracker_dispatcher.dart';
import 'published_routine_view.dart';
import 'tutorial_media.dart';

enum ExerciseExecutionKind { measured, timed, legacyManual, unavailable }

class ResolvedExerciseExecution {
  const ResolvedExerciseExecution(this.kind,
      {this.tracker, this.description = ''});
  final ExerciseExecutionKind kind;
  final ExerciseTracker? tracker;
  final String description;
}

class ExerciseExecutionResolver {
  const ExerciseExecutionResolver(
      {this.dispatcher = const ExerciseTrackerDispatcher()});
  final ExerciseTrackerDispatcher dispatcher;
  ResolvedExerciseExecution resolve(
      {required SessionScope scope,
      required PublishedRoutineExercise exercise}) {
    const invalid = ResolvedExerciseExecution(ExerciseExecutionKind.unavailable,
        description:
            'This exercise is unavailable. Check its published targets and media.');
    final tracked = dispatcher.resolve(
        organizationId: scope.organizationId, exerciseId: exercise.exerciseId);
    ExercisePrescription target;
    try {
      target = exercise.prescription;
      target.validate();
    } on FormatException {
      return invalid;
    }
    if (exercise.executionMode == ExerciseExecutionMode.videoGuidedTimed) {
      final stamp = exercise.mediaValidation;
      if (tracked.registeredCapability.hasPoseTracking ||
          target is! TimedPrescription ||
          exercise.reps != null ||
          tutorialMediaUri(exercise.videoUrl) == null ||
          exercise.mediaGeneration == null ||
          exercise.mediaGeneration!.isEmpty ||
          exercise.mediaRevision == null ||
          exercise.mediaRevision! < 0 ||
          stamp == null ||
          stamp['schemaVersion'] != 1 ||
          stamp['videoUrl'] != exercise.videoUrl ||
          stamp['generation'] != exercise.mediaGeneration ||
          stamp['sourceRevision'] != exercise.mediaRevision ||
          stamp['contentType'] != 'video/mp4') {
        return invalid;
      }
      return const ResolvedExerciseExecution(ExerciseExecutionKind.timed,
          description: 'Video guided · Timer tracked · Not AI verified');
    }
    if (target is! RepetitionPrescription) {
      return invalid;
    }
    if (exercise.executionMode == ExerciseExecutionMode.legacyManual) {
      if (tracked.registeredCapability.hasPoseTracking) return invalid;
      return const ResolvedExerciseExecution(ExerciseExecutionKind.legacyManual,
          description: 'Tutorial guidance · Self-reported sets');
    }
    if (tracked.tracker != null) {
      return ResolvedExerciseExecution(ExerciseExecutionKind.measured,
          tracker: tracked.tracker, description: tracked.description);
    }
    if (tracked.unavailable ||
        exercise.executionMode == ExerciseExecutionMode.aiTracked) {
      return ResolvedExerciseExecution(ExerciseExecutionKind.unavailable,
          description: tracked.unavailable
              ? tracked.description
              : 'AI tracking is not registered for this exercise.');
    }
    return const ResolvedExerciseExecution(ExerciseExecutionKind.legacyManual,
        description: 'Tutorial guidance · Self-reported sets');
  }
}
