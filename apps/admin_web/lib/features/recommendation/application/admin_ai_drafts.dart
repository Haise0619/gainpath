import 'package:gainpath_domain/workout.dart';

/// In-memory create seeds, never existing edit identities or auto-save commands.
TutorialVideo aiExerciseSeed(Map<String, dynamic> d) => TutorialVideo(
      title: d['name'] as String,
      category: d['category'] as String,
      status: TutorialStatus.draft,
      difficulty: d['difficulty'] as String,
      description: d['description'] as String,
      equipment: d['equipment'] as String,
      durationMin: d['durationMinutes'] as int,
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
      'weeks': 4,
      'days': [
        for (var week = 1; week <= 4; week++)
          for (var day = 1; day <= 7; day++)
            {
              'schemaVersion': 2,
              'week': week,
              'weekday': day,
              'kind': day == 1 || day == 3 || day == 5 ? 'workout' : 'rest',
              'category':
                  day == 1 || day == 3 || day == 5 ? 'Full Body' : 'Rest',
              'routineId': day == 1 || day == 3 || day == 5
                  ? (d['routineIds'] as List)[
                      ((day - 1) ~/ 2) % (d['routineIds'] as List).length]
                  : null,
              'routineDay': 1,
              'muscleGroups': day == 1 || day == 3 || day == 5
                  ? ['upperPush', 'upperPull', 'lower']
                  : [],
              'restOverrideSeconds': null,
            }
      ],
    });
