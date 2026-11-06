import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_plan_signature.dart';

void main() {
  PublishedRoutine plan(
      {int version = 1,
      int seconds = 45,
      int rest = 60,
      String generation = '123',
      bool reverse = false}) {
    final rows = [
      for (final entry in ['first', 'second'])
        PublishedRoutineExercise(
            exerciseId: 'same',
            entryId: entry,
            dayNumber: 1,
            name: 'Exercise',
            category: '',
            sets: 3,
            reps: version == 1 ? 8 : null,
            executionMode:
                version == 1 ? null : ExerciseExecutionMode.videoGuidedTimed,
            durationSeconds: version == 1 ? null : seconds,
            restSeconds: rest,
            mediaGeneration: generation,
            mediaRevision: 1,
            cue: '',
            imageUrl: '',
            muscleGroup: '')
    ];
    return PublishedRoutine(
        id: 'routine',
        sourceBlueprintId: 'blueprint',
        title: 'Plan',
        estimatedMinutes: 5,
        schemaVersion: version,
        exercises: reverse ? rows.reversed.toList() : rows);
  }

  test('legacy signature retains exact previous bytes', () {
    expect(routinePlanSignature(plan()),
        '["routine","blueprint",["same",1,3,8],["same",1,3,8]]');
  });
  test('v2 duration rest media and stable entry ordering are signed', () {
    final signature = routinePlanSignature(plan(version: 2));
    for (final changed in [
      plan(version: 2, seconds: 46),
      plan(version: 2, rest: 30),
      plan(version: 2, generation: '124'),
      plan(version: 2, reverse: true)
    ]) {
      expect(routinePlanSignature(changed), isNot(signature));
    }
  });
}
