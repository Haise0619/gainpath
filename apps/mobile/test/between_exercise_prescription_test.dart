import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_plan_signature.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';

void main() {
  Map<String, dynamic> document() => {
        'schemaVersion': 1,
        'kind': 'routine',
        'status': 'published',
        'sourceBlueprintId': 'source',
        'title': 'Routine',
        'estimatedMinutes': 10,
        'exercises': [
          {
            'exerciseId': 'manual',
            'name': 'Move',
            'sets': 1,
            'reps': 5,
            'restSeconds': 90
          }
        ],
      };
  test('between-exercise rest is explicit and never inferred from set rest',
      () {
    final legacy = PublishedRoutine.fromDocument('r', document());
    expect(legacy.betweenExerciseRestSeconds, isNull);
    final prescribed = PublishedRoutine.fromDocument(
        'r', {...document(), 'betweenExerciseRestSeconds': 25});
    expect(prescribed.betweenExerciseRestSeconds, 25);
    expect(prescribed.exercises.single.restSeconds, 90);
    expect(
        PublishedRoutine.fromDocument('r', routinePlanSnapshot(prescribed))
            .betweenExerciseRestSeconds,
        25);
    // Rest configuration is not workout credit or a changed exercise target.
    expect(routinePlanSignature(legacy), routinePlanSignature(prescribed));
  });
  test('invalid explicit rest is rejected', () {
    for (final value in [-1, 601, '30']) {
      expect(
          () => PublishedRoutine.fromDocument(
              'r', {...document(), 'betweenExerciseRestSeconds': value}),
          throwsFormatException);
    }
  });
}
