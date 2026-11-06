import 'package:flutter/widgets.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import '../features/workout/domain/published_routine_view.dart';
import '../features/workout/domain/routine_workout_context.dart';

abstract final class WorkoutNavigation {
  static const guided = '/workout/guided';
}

/// Consent and content identity selected before opening a measured session.
class RealWorkoutLaunch {
  const RealWorkoutLaunch({
    required this.scope,
    required this.routineId,
    required this.exercise,
    required this.consented,
    required this.setupConfirmed,
    required this.requestServerUpload,
    this.sessionId,
    this.returnToRoutine = false,
    this.routineContext,
  });

  final SessionScope scope;
  final String routineId;
  final PublishedRoutineExercise exercise;
  final bool consented, setupConfirmed, requestServerUpload;
  final String? sessionId;
  final bool returnToRoutine;
  final RoutineWorkoutContext? routineContext;
  RepetitionPrescription get repetitionTarget {
    return exercise.repetitionTarget;
  }
}

/// Immutable camera-free journey identity; route results are never completion evidence.
class GuidedWorkoutLaunch {
  const GuidedWorkoutLaunch(
      {required this.scope,
      required this.routineId,
      required this.sourceBlueprintId,
      required this.dayNumber,
      required this.entryId,
      required this.entryIndex,
      required this.attemptId,
      required this.runId,
      required this.exercise,
      required this.prescription,
      required this.mediaGeneration,
      required this.mediaRevision,
      this.routineContext});
  final SessionScope scope;
  final String routineId, sourceBlueprintId, entryId, attemptId, runId;
  final int dayNumber, entryIndex;
  final PublishedRoutineExercise exercise;
  final TimedPrescription prescription;
  final String mediaGeneration;
  final int mediaRevision;
  final RoutineWorkoutContext? routineContext;
}

/// Destinations supplied by app composition to the preparation screen.
class WorkoutPrepRoutes {
  const WorkoutPrepRoutes({
    this.realSessionBuilder,
    this.savedSessionsBuilder,
    this.posePreviewBuilder,
    this.tutorialBuilder,
    this.journeyBuilder,
  });

  final Widget Function(BuildContext, RealWorkoutLaunch)? realSessionBuilder;
  final Widget Function(BuildContext, SessionScope)? savedSessionsBuilder;
  final WidgetBuilder? posePreviewBuilder;
  final Widget Function(BuildContext, PublishedRoutineExercise)?
      tutorialBuilder;
  final Widget Function(BuildContext, PublishedRoutine)? journeyBuilder;
}
