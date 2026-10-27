import 'package:flutter/widgets.dart';
import '../../features/workout/domain/exercise_tracker_dispatcher.dart';
import '../../navigation/workout_navigation.dart';
import 'exercise_tutorial_route.dart';
import 'real_squat_route.dart';
import 'curl_workout_route.dart';
import 'calf_raise_workout_route.dart';
import 'wall_push_up_workout_route.dart';

/// All measured entry points dispatch here, preserving the original launch data.
class ExerciseTrackerRoute extends StatelessWidget {
  const ExerciseTrackerRoute({
    super.key,
    required this.launch,
    this.trackers = const ExerciseTrackerDispatcher(),
  });
  final RealWorkoutLaunch launch;
  final ExerciseTrackerDispatcher trackers;

  @override
  Widget build(BuildContext context) {
    final resolution = trackers.resolve(
        organizationId: launch.scope.organizationId,
        exerciseId: launch.exercise.exerciseId);
    return switch (resolution.tracker) {
      ExerciseTracker.sideViewWallPushUp =>
        WallPushUpWorkoutRoute(launch: launch),
      ExerciseTracker.sideViewCalfRaise =>
        CalfRaiseWorkoutRoute(launch: launch),
      ExerciseTracker.sideViewSquat => RealSquatRoute(
          scope: launch.scope,
          routineId: launch.routineId,
          exercise: launch.exercise,
          consented: launch.consented,
          setupConfirmed: launch.setupConfirmed,
          requestServerUpload: launch.requestServerUpload,
          sessionId: launch.sessionId,
          routineContext: launch.routineContext,
          returnToRoutine: launch.returnToRoutine),
      null =>
        ExerciseTutorialRoute(scope: launch.scope, exercise: launch.exercise),
      ExerciseTracker.sideViewCurl => CurlWorkoutRoute(launch: launch),
    };
  }
}
