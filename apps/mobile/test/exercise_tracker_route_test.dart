import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/routing/exercise_tracker_route.dart';
import 'package:gainpath_mobile/app/routing/exercise_tutorial_route.dart';
import 'package:gainpath_mobile/app/routing/real_squat_route.dart';
import 'package:gainpath_mobile/app/routing/curl_workout_route.dart';
import 'package:gainpath_mobile/app/routing/calf_raise_workout_route.dart';
import 'package:gainpath_mobile/app/routing/wall_push_up_workout_route.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_workout_context.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'routine_journey_controller_test.dart' as support;

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  testWidgets('calf route remains available only with an explicit test enable',
      (tester) async {
    const exercise = PublishedRoutineExercise(
        exerciseId: 'standing-calf-raise-side-v1',
        name: 'Standing calf raise',
        category: 'Accessory',
        muscleGroup: 'Calves',
        sets: 2,
        reps: 5,
        cue: '',
        imageUrl: '',
        dayNumber: 1);
    final launch = RealWorkoutLaunch(
        scope: scope,
        routineId: 'routine',
        exercise: exercise,
        consented: true,
        setupConfirmed: true,
        requestServerUpload: false,
        sessionId: 'calf',
        returnToRoutine: true);
    late Widget destination;
    await tester.pumpWidget(Builder(builder: (context) {
      destination = ExerciseTrackerRoute(
              launch: launch,
              trackers: const ExerciseTrackerDispatcher(
                  availableTrackers: {ExerciseTracker.sideViewCalfRaise}))
          .build(context);
      return const SizedBox();
    }));
    expect(destination, isA<CalfRaiseWorkoutRoute>());
    expect(
        identical((destination as CalfRaiseWorkoutRoute).launch, launch), true);
  });
  testWidgets('wall route retains the exact consent targets and routine launch',
      (tester) async {
    const exercise = PublishedRoutineExercise(
        exerciseId: 'wall-push-up-side-v1',
        name: 'Wall push-up',
        category: 'Compound Upper-Body',
        muscleGroup: 'Chest',
        sets: 1,
        reps: 5,
        cue: '',
        imageUrl: '',
        dayNumber: 1);
    final launch = RealWorkoutLaunch(
        scope: scope,
        routineId: 'routine',
        exercise: exercise,
        consented: true,
        setupConfirmed: true,
        requestServerUpload: false,
        sessionId: 'wall',
        returnToRoutine: true);
    late Widget destination;
    await tester.pumpWidget(Builder(builder: (context) {
      destination = ExerciseTrackerRoute(launch: launch).build(context);
      return const SizedBox();
    }));
    expect(destination, isA<WallPushUpWorkoutRoute>());
    expect(identical((destination as WallPushUpWorkoutRoute).launch, launch),
        true);
  });
  testWidgets(
      'registered curl routes to its own local controller with launch identity retained',
      (tester) async {
    const exercise = PublishedRoutineExercise(
        exerciseId: 'standing-single-arm-curl-side-v1',
        name: 'Standing single-arm dumbbell curl',
        category: 'Arms',
        muscleGroup: 'Biceps',
        sets: 1,
        reps: 2,
        cue: '',
        imageUrl: '',
        dayNumber: 1);
    final launch = RealWorkoutLaunch(
        scope: scope,
        routineId: 'routine',
        exercise: exercise,
        consented: true,
        setupConfirmed: true,
        requestServerUpload: false,
        sessionId: 'curl',
        returnToRoutine: true);
    late Widget destination;
    await tester.pumpWidget(Builder(builder: (context) {
      destination = ExerciseTrackerRoute(launch: launch).build(context);
      return const SizedBox();
    }));
    expect(destination, isA<CurlWorkoutRoute>());
    expect(identical((destination as CurlWorkoutRoute).launch, launch), true);
  });
  testWidgets(
      'squat route retains targets, consent, capture ID and routine return',
      (tester) async {
    final exercise = support.routineFixture().exercises.first;
    final launch = RealWorkoutLaunch(
        scope: scope,
        routineId: 'routine',
        exercise: exercise,
        consented: false,
        setupConfirmed: false,
        requestServerUpload: true,
        sessionId: 'capture-id',
        routineContext: const RoutineWorkoutContext(
            routineTitle: 'Testing 2',
            day: 1,
            exerciseNumber: 1,
            totalExercises: 2),
        returnToRoutine: true);
    late Widget destination;
    await tester.pumpWidget(Builder(builder: (context) {
      destination = ExerciseTrackerRoute(launch: launch).build(context);
      return const SizedBox();
    }));
    expect(destination, isA<RealSquatRoute>());
    final route = destination as RealSquatRoute;
    expect(route.scope, scope);
    expect(identical(route.exercise, exercise), true);
    expect(route.routineId, launch.routineId);
    expect(route.consented, false);
    expect(route.setupConfirmed, false);
    expect(route.requestServerUpload, true);
    expect(route.sessionId, 'capture-id');
    expect(identical(route.routineContext, launch.routineContext), true);
    expect(route.returnToRoutine, true);
  });

  testWidgets('unknown and unavailable trackers route to the selected tutorial',
      (tester) async {
    final exercises = support.routineFixture().exercises;
    for (final (exercise, dispatcher) in [
      (exercises[1], const ExerciseTrackerDispatcher()),
      (exercises[0], const ExerciseTrackerDispatcher(availableTrackers: {})),
    ]) {
      late Widget destination;
      await tester.pumpWidget(Builder(builder: (context) {
        destination = ExerciseTrackerRoute(
                trackers: dispatcher,
                launch: RealWorkoutLaunch(
                    scope: scope,
                    routineId: 'routine',
                    exercise: exercise,
                    consented: false,
                    setupConfirmed: false,
                    requestServerUpload: false))
            .build(context);
        return const SizedBox();
      }));
      expect(destination, isA<ExerciseTutorialRoute>());
      final tutorial = destination as ExerciseTutorialRoute;
      expect(tutorial.scope, scope);
      expect(identical(tutorial.exercise, exercise), true);
    }
  });
}
