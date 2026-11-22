import 'package:gainpath_domain/workout.dart';

/// In-memory create seeds, never existing edit identities or auto-save commands.
TutorialVideo aiExerciseSeed(Map<String, dynamic> d) => TutorialVideo(
      title: d['name'] as String,
      category: d['category'] as String,
      status: TutorialStatus.draft,
      difficulty: d['difficulty'] as String,
      description:
          '${d['description']}\nPrimary muscle group: ${d['primaryMuscleGroup']}',
      equipment: d['equipment'] as String,
      durationMin: 0,
      executionMode: ExerciseExecutionMode.videoGuidedTimed,
      tutorialSteps: [
        for (final (i, step) in (d['instructions'] as List).indexed)
          ExerciseTutorialStep(
              title: 'Step ${i + 1}', description: '$step', imageUrl: '')
      ],
    );
RoutineBlueprint aiRoutineSeed(Map<String, dynamic> d) => RoutineBlueprint(
      id: '',
      name: d['name'] as String,
      level: d['difficulty'] as String,
      assignedMembers: 0,
      schemaVersion: 2,
      goal: '${d['goal']}\n${d['description']}',
      sessionDurationMin: d['durationMinutes'] as int,
      equipmentNeeded: [d['equipment'] as String],
      days: [
        RoutineDay(1, [
          for (final row in d['exercises'] as List)
            RoutineExerciseRef(
                row['name'] as String,
                row['sets'] as int,
                row['executionMode'] == 'videoGuidedTimed'
                    ? null
                    : row['reps'] as int,
                exerciseId: row['exerciseId'] as String,
                executionMode: ExerciseExecutionMode.values
                    .firstWhere((e) => e.name == row['executionMode']),
                sourceCatalogRevision: row['revision'] as int,
                prescription: row['executionMode'] == 'videoGuidedTimed'
                    ? TimedPrescription(
                        sets: row['sets'],
                        durationSeconds: row['reps'],
                        restSeconds: row['restSeconds'])
                    : RepetitionPrescription(
                        sets: row['sets'],
                        repetitions: row['reps'],
                        restSeconds: row['restSeconds']))
        ])
      ],
    );

WorkoutProgram aiProgramSeed(Map<String, dynamic> d, String id) =>
    WorkoutProgram.fromJson({
      'schemaVersion': 2,
      'id': id,
      'version': 0,
      'title': d['name'],
      'level': d['difficulty'],
      'weeks': d['weeks'],
      'days': [
        for (var week = 1; week <= (d['weeks'] as int); week++)
          for (var day = 1; day <= 7; day++)
            {
              'schemaVersion': 2,
              'week': week,
              'weekday': day,
              'kind':
                  (d['trainingDays'] as List).any((r) => r['weekday'] == day)
                      ? 'workout'
                      : 'rest',
              'category':
                  (d['trainingDays'] as List).any((r) => r['weekday'] == day)
                      ? (d['trainingDays'] as List)
                          .firstWhere((r) => r['weekday'] == day)['category']
                      : 'Rest',
              'routineId': (d['trainingDays'] as List)
                  .where((r) => r['weekday'] == day)
                  .map((r) => r['routineId'])
                  .firstOrNull,
              'routineDay': 1,
              'muscleGroups': (d['trainingDays'] as List)
                      .where((r) => r['weekday'] == day)
                      .map((r) => programMuscles(r['category'] as String))
                      .firstOrNull ??
                  [],
              'restOverrideSeconds': null,
            }
      ],
    });
