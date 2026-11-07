import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/presentation/workout_presentation.dart';

PublishedRoutineExercise exercise(
        {String id = 'standing-lateral-raise-front-v1',
        ExerciseExecutionMode? mode,
        int? reps = 8,
        int? seconds}) =>
    PublishedRoutineExercise(
        exerciseId: id,
        dayNumber: 1,
        name: 'Exercise',
        category: 'Full Body',
        sets: 3,
        reps: reps,
        cue: '',
        imageUrl: '',
        muscleGroup: '',
        executionMode: mode,
        durationSeconds: seconds,
        restSeconds: 30);

void main() {
  test('target grammar and next action distinguish setup from work', () {
    expect(workoutRepetitionTarget(1, 1), '1 set × 1 rep');
    expect(workoutCount(2, 'set'), '2 sets');
    final ai = ExercisePresentation.forExercise(exercise(),
        organizationId: 'gainpath');
    expect(ai.nextActionDescription, contains('Camera setup'));
    expect(ai.restLabel, '30 sec rest between sets');
  });
  test('exact registered identity presents AI targets and available scope only',
      () {
    final value = ExercisePresentation.forExercise(exercise(),
        organizationId: 'gainpath');
    expect(value.mode, WorkoutExerciseMode.aiTracked);
    expect(value.label, 'AI Tracked');
    expect(value.targetLabel, contains('3 sets × 8 reps'));
    expect(value.startLabel, 'Start AI Workout');
    expect(
        ExercisePresentation.forExercise(exercise(), organizationId: 'other')
            .mode,
        WorkoutExerciseMode.manual);
  });
  test('timed and manual targets and labels never use null reps', () {
    final timed = ExercisePresentation.forExercise(
        exercise(
            id: 'mobility',
            mode: ExerciseExecutionMode.videoGuidedTimed,
            reps: null,
            seconds: 45),
        organizationId: 'gainpath');
    expect(timed.mode, WorkoutExerciseMode.videoTimed);
    expect(timed.label, 'Video Timed');
    expect(timed.targetLabel, '3 sets × 45 sec per set');
    expect(timed.targetsWithRest, contains('30 sec rest'));
    expect(timed.targetLabel, isNot(contains('reps')));
    expect(timed.provenance, 'Timer recorded');
    final manual = ExercisePresentation.forExercise(
        exercise(id: 'other', mode: ExerciseExecutionMode.legacyManual),
        organizationId: 'gainpath');
    expect(manual.label, 'Manual');
    expect(manual.targetLabel, contains('Self-reported'));
  });
  test('explicit unsupported AI and invalid targets do not claim tracking', () {
    expect(
        ExercisePresentation.forExercise(
                exercise(id: 'fake', mode: ExerciseExecutionMode.aiTracked),
                organizationId: 'gainpath')
            .mode,
        WorkoutExerciseMode.unavailable);
    final invalid = ExercisePresentation.forExercise(exercise(reps: null),
        organizationId: 'gainpath');
    expect(invalid.targetLabel, 'Targets unavailable');
    expect(invalid.mode, WorkoutExerciseMode.unavailable);
  });
  test(
      'completion styles recognize measured timed and manual target completion',
      () {
    for (final status in [
      RoutineExerciseStatus.completed,
      RoutineExerciseStatus.timerCompleted,
      RoutineExerciseStatus.selfReportedCompleted
    ]) {
      expect(isExerciseTargetComplete(status), isTrue);
      expect(exerciseStatusLabel(status), startsWith('Completed'));
    }
    expect(isExerciseTargetComplete(RoutineExerciseStatus.instructionsReviewed),
        isFalse);
    expect(isExerciseTargetComplete(RoutineExerciseStatus.skipped), isFalse);
  });
  test('no saved measured session means no fabricated zero AI totals', () {
    final manual = RoutineExerciseResult(
        index: 0,
        status: RoutineExerciseStatus.selfReportedCompleted,
        sessionIds: [],
        fullRepetitions: 0,
        partialRepetitions: 0,
        trackedDurationMicros: 0,
        manualSets: 3);
    expect(exerciseResultSummary(manual), '3 sets · Self-reported');
    expect(exerciseResultSummary(manual), isNot(contains('reps')));
    expect(workoutDurationLabel(75000000), '1 min 15 sec');
  });
}
