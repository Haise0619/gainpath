import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/workout_hub_attempt.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_journey.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_plan_signature.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  final routine = PublishedRoutine(
      id: 'r',
      sourceBlueprintId: 'b',
      title: 'Routine',
      estimatedMinutes: 10,
      exercises: const [
        PublishedRoutineExercise(
            exerciseId: 'e',
            dayNumber: 1,
            name: 'Exercise',
            category: 'Strength',
            sets: 2,
            reps: 10,
            cue: '',
            imageUrl: '',
            muscleGroup: '')
      ]);
  RoutineCheckpoint checkpoint({String? signature, bool finished = false}) =>
      RoutineCheckpoint(
          id: 'a',
          scope: scope,
          routineId: routine.id,
          planSignature: signature ?? routinePlanSignature(routine),
          day: 1,
          selectedIndex: 0,
          updatedAtMicros: 1,
          finished: finished);
  test('only compatible checkpoints offer continue', () {
    expect(
        WorkoutHubAttempt.fromCheckpoints(
            scope: scope, routine: routine, checkpoints: []).actionLabel,
        'Start workout');
    expect(
        WorkoutHubAttempt.fromCheckpoints(
            scope: scope,
            routine: routine,
            checkpoints: [checkpoint(signature: 'old')]).actionLabel,
        'Start workout');
    expect(
        WorkoutHubAttempt.fromCheckpoints(
            scope: scope,
            routine: routine,
            checkpoints: [checkpoint()]).actionLabel,
        'Continue workout');
  });
  test('finished partial checkpoint offers summary before explicit resume', () {
    final view = WorkoutHubAttempt.fromCheckpoints(
        scope: scope,
        routine: routine,
        checkpoints: [checkpoint(finished: true)]);
    expect(view.actionLabel, 'Resume Unfinished Exercises');
    expect(view.resumeUnfinished, isTrue);
    expect(view.statusLabel, 'Partially completed');
    expect(view.total, 1);
    expect(view.completed, 0);
  });
  test('completed compatible attempt offers a fresh start', () {
    final base = checkpoint(finished: true);
    final attempt = RoutineAttempt(
        id: base.id,
        scope: scope,
        routine: routine,
        day: 1,
        finished: true,
        updatedAtMicros: 1,
        entries: [
          RoutineExerciseResult(
              index: 0,
              status: RoutineExerciseStatus.selfReportedCompleted,
              sessionIds: [],
              fullRepetitions: 0,
              partialRepetitions: 0,
              trackedDurationMicros: 0,
              manualSets: 2)
        ]);
    final view = WorkoutHubAttempt.fromCheckpoints(
        scope: scope,
        routine: routine,
        checkpoints: [base.copyWith(attempt: attempt)]);
    expect(view.actionLabel, 'Start workout');
    expect(view.startsNewAttempt, isTrue);
    expect(view.completed, 0);
    expect(view.checkpoint!.attempt, same(attempt));
    expect(view.resumeUnfinished, isFalse);
  });
}
