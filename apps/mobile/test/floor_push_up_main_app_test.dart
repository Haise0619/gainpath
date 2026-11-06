import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/application/floor_push_up_workout_session.dart';
import 'package:gainpath_mobile/features/workout/domain/exercise_tracker_dispatcher.dart';
import 'package:gainpath_mobile/features/workout/domain/floor_push_up_catalog.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';

void main() {
  test(
      'normal floor sessions keep developer diagnostics off even with legacy flags',
      () {
    expect(FloorPushUpWorkoutSession.debugEnabled, false);
  });
  test(
      'ordinary registry and catalog resolve floor independently of Wall Push-Up',
      () {
    const dispatcher = ExerciseTrackerDispatcher();
    expect(standardFloorPushUp.name, 'Standard Floor Push-Up');
    expect(
        dispatcher
            .resolve(
                organizationId: 'gainpath',
                exerciseId: standardFloorPushUp.exerciseId)
            .tracker,
        ExerciseTracker.sideViewFloorPushUp);
    expect(
        ExerciseTrackingRegistry.resolve(
            organizationId: 'gainpath', exerciseId: 'wall-push-up-side-v1'),
        ExerciseTrackingCapability.sideViewWallPushUp);
    expect(
        ExerciseTrackingRegistry.resolve(
                organizationId: 'foreign',
                exerciseId: standardFloorPushUp.exerciseId)
            .hasPoseTracking,
        false);
  });
  test(
      'normal published floor routine parses to the supported tracker and existing targets',
      () {
    final p = jsonDecode(File('../../tools/workouts/floor-main-content.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final f = p['fields'] as Map<String, dynamic>;
    final routine = PublishedRoutine.fromDocument(p['routineId'] as String, {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': p['blueprintId'],
      'title': f['exerciseName'],
      'estimatedMinutes': 10,
      'difficulty': f['difficulty'],
      'exercises': [
        {
          'exerciseId': p['exerciseId'],
          'name': f['exerciseName'],
          'category': 'Bodyweight',
          'muscleGroup': 'Chest',
          'sets': 3,
          'reps': 8,
          'restSeconds': 60,
          'dayNumber': 1,
          'description': f['description'],
          'equipment': f['equipment'],
          'difficulty': f['difficulty'],
          'tutorialSteps': f['tutorialSteps']
        }
      ],
    });
    expect(routine.exercises.single.exerciseId, standardFloorPushUp.exerciseId);
    expect(routine.exercises.single.sets, 3);
    expect(routine.exercises.single.reps, 8);
    expect(routine.exercises.single.restSeconds, 60);
    expect(routine.exercises.single.tutorial.steps.length, 4);
  });
}
