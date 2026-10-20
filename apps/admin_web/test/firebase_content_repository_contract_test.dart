import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_routine_template_repository.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  final activeExercise = TutorialVideo(
    id: 'squat-stable-id',
    title: 'Goblet squat',
    category: 'Lower body',
    status: TutorialStatus.active,
    videoUrl: 'https://example.test/squat',
  );

  test('exercise repository maps only the catalog schema fields', () {
    expect(
        FirebaseExerciseCatalogRepository.encodeCatalogFields(activeExercise), {
      'schemaVersion': 1,
      'exerciseName': 'Goblet squat',
      'muscleCategory': 'Lower body',
      'videoUrl': 'https://example.test/squat',
      'isActive': true,
    });
  });

  test('publish request ID generation stays within the browser random bound', () {
    final requestId = buildPublishRoutineRequestId(
      timestampMicros: 1234,
      random: Random(7),
    );
    expect(requestId, matches(RegExp(r'^1234-\d+$')));
  });

  test(
      'routine repository writes stable references without duplicated exercise records',
      () {
    final blueprint = RoutineBlueprint(
      id: 'routine-1',
      name: 'Strength A',
      level: 'Beginner',
      assignedMembers: 0,
      days: [
        RoutineDay(1, [
          RoutineExerciseRef('Goblet squat', 3, 8,
              exerciseId: 'squat-stable-id'),
        ]),
      ],
    );

    final storedDays = FirebaseRoutineTemplateRepository.encodeRoutineDays(
      blueprint,
      [activeExercise],
    );

    expect(storedDays, [
      {
        'dayNumber': 1,
        'exercises': [
          {'exerciseId': 'squat-stable-id', 'sets': 3, 'reps': 8},
        ],
      },
    ]);
    expect(
      () => FirebaseRoutineTemplateRepository.encodeRoutineDays(blueprint, []),
      throwsStateError,
    );
    final inactive = TutorialVideo(
      id: 'squat-stable-id',
      title: 'Goblet squat',
      category: 'Lower body',
      status: TutorialStatus.draft,
    );
    expect(
      () => FirebaseRoutineTemplateRepository.encodeRoutineDays(
          blueprint, [inactive]),
      throwsStateError,
    );
  });
}
