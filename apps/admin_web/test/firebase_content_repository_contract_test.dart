import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_routine_template_repository.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test(
      'v2 routine targets retain copied timed values and stable row identities',
      () {
    final source = TutorialVideo(
        id: 'mobility',
        title: 'Mobility',
        category: 'Full Body',
        status: TutorialStatus.active,
        executionMode: ExerciseExecutionMode.videoGuidedTimed,
        defaultPrescription: const TimedPrescription(
            sets: 5, durationSeconds: 60, restSeconds: 10));
    final blueprint = RoutineBlueprint(
        id: '',
        schemaVersion: 2,
        name: 'Mixed',
        level: 'Beginner',
        assignedMembers: 0,
        days: [
          RoutineDay(1, [
            const RoutineExerciseRef('Mobility', 3, null,
                exerciseId: 'mobility',
                entryId: 'stable',
                executionMode: ExerciseExecutionMode.videoGuidedTimed,
                prescription: TimedPrescription(
                    sets: 3, durationSeconds: 45, restSeconds: 30))
          ])
        ]);
    final encoded = FirebaseRoutineTemplateRepository.encodeRoutineDays(
        blueprint, [source]);
    expect((encoded.single['exercises'] as List).single, {
      'exerciseId': 'mobility',
      'entryId': 'stable',
      'executionMode': 'videoGuidedTimed',
      'sets': 3,
      'durationSeconds': 45,
      'restSeconds': 30
    });
  });
  test(
      'v2 routine encoding rejects duplicate entries and archived catalog sources',
      () {
    final item = TutorialVideo(
        id: 'move',
        title: 'Move',
        category: 'Full Body',
        status: TutorialStatus.active,
        archived: true);
    final blueprint = RoutineBlueprint(
        id: '',
        schemaVersion: 2,
        name: 'Mixed',
        level: 'Beginner',
        assignedMembers: 0,
        days: [
          RoutineDay(
              1,
              List.generate(
                  2,
                  (_) => const RoutineExerciseRef('Move', 3, null,
                      exerciseId: 'move',
                      entryId: 'duplicate',
                      executionMode: ExerciseExecutionMode.videoGuidedTimed,
                      prescription: TimedPrescription(
                          sets: 3, durationSeconds: 45, restSeconds: 30))))
        ]);
    expect(
        () => FirebaseRoutineTemplateRepository.encodeRoutineDays(
            blueprint, [item]),
        throwsStateError);
    final active = TutorialVideo(
        id: 'move',
        title: 'Move',
        category: 'Full Body',
        status: TutorialStatus.active);
    expect(
        () => FirebaseRoutineTemplateRepository.encodeRoutineDays(
            blueprint, [active]),
        throwsFormatException);
  });
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

  test('publish request ID generation stays within the browser random bound',
      () {
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
