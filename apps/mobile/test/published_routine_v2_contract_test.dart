import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';

Map<String, dynamic> document() => {
      'schemaVersion': 2,
      'kind': 'routine_v2',
      'status': 'published',
      'sourceBlueprintId': 'blueprint',
      'title': 'Mixed',
      'estimatedMinutes': 5,
      'exercises': <Map<String, dynamic>>[
        {
          'entryId': 'first',
          'exerciseId': 'mobility',
          'name': 'Mobility',
          'dayNumber': 1,
          'executionMode': 'videoGuidedTimed',
          'sets': 3,
          'durationSeconds': 45,
          'restSeconds': 30,
          'videoUrl': 'https://storage.example/video.mp4',
          'mediaGeneration': '123',
          'mediaRevision': 1
        },
        {
          'entryId': 'second',
          'exerciseId': 'mobility',
          'name': 'Mobility',
          'dayNumber': 1,
          'executionMode': 'legacyManual',
          'sets': 3,
          'reps': 8,
          'restSeconds': 60
        },
      ]
    };

void main() {
  test('v2 mixed rows decode distinct stable entries without dummy reps', () {
    final plan = PublishedRoutine.fromDocument('routine', document());
    expect(plan.schemaVersion, 2);
    expect(plan.exercises.first.reps, isNull);
    expect(plan.exercises.first.prescription.toJson(),
        {'sets': 3, 'durationSeconds': 45, 'restSeconds': 30});
    expect(plan.exercises.last.prescription, isA<RepetitionPrescription>());
    expect(plan.exercises.map((e) => e.entryId), ['first', 'second']);
  });
  test('v2 duplicate entries unknown modes and ambiguous targets are rejected',
      () {
    for (final change in [
      {'entryId': 'second'},
      {'executionMode': 'unknown'},
      {'reps': 8},
      {'executionMode': 'aiTracked'},
      {'durationSeconds': 3601},
    ]) {
      final data = document();
      (data['exercises'] as List)[0] = <String, dynamic>{
        ...(data['exercises'] as List).first,
        ...change
      };
      expect(() => PublishedRoutine.fromDocument('routine', data),
          throwsFormatException);
    }
    expect(
        () => PublishedRoutine.fromDocument(
            'routine', {...document(), 'kind': 'routine'}),
        throwsFormatException);
  });
}
