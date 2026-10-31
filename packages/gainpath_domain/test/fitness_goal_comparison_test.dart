import 'package:test/test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
final asOf = DateTime.utc(2026, 10, 19, 1);
LocalWorkoutProgressRecord capture(String id, DateTime end, int reps) =>
    LocalWorkoutProgressRecord(
      scope: scope,
      sessionId: id,
      exerciseId: 'configured-id',
      startedAt: end.subtract(const Duration(minutes: 1)),
      endedAt: end,
      repetitions: reps,
      partialRepetitions: 2,
      trackedDurationMicros: 3000000,
      rejectedDurationMicros: 1000000,
      formScorePercent: 70,
      scoringVersion: 'rule',
      detectorId: 'detector',
      detectorVersion: 'model',
      cameraView: 'side',
      status: LocalWorkoutRecordStatus.localOnly,
    );
NumericFitnessGoal goal(String id, NumericGoalCategory category, double target,
        {NumericGoalStatus status = NumericGoalStatus.active}) =>
    NumericFitnessGoal(
      id: id,
      category: category,
      targetValue: target,
      status: status,
      revision: 1,
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
void main() {
  test(
      'manual-only repetitions stay unavailable and future attempts do not count',
      () {
    final progress =
        calculateLocalMemberProgress(scope: scope, asOf: asOf, records: []);
    final observation = WorkoutGoalObservation(
        id: 'manual',
        startedAt: asOf,
        observedAt: asOf,
        cameraRepetitions: null,
        manualSets: 3,
        context: 'Manual routine · day 1',
        completed: true);
    final future = WorkoutGoalObservation(
        id: 'future',
        startedAt: asOf,
        observedAt: asOf.add(const Duration(hours: 1)),
        cameraRepetitions: 100,
        manualSets: 0,
        context: 'Future',
        completed: true);
    final results = compareFitnessGoals(progress, [
      goal('frequency', NumericGoalCategory.trainingFrequency, 4),
      goal('reps', NumericGoalCategory.repetitions, 10),
    ], workouts: [
      observation,
      observation,
      future
    ]);
    expect(results.first.measuredValue, 1);
    expect(results.last.measuredValue, isNull);
    expect(results.last.measurementLabel,
        contains('3 self-reported sets kept separate'));
  });

  test('whole workout attempts use UTC start week and never capture count', () {
    final progress = calculateLocalMemberProgress(
        scope: scope,
        asOf: asOf,
        records: [capture('set1', asOf, 8), capture('set2', asOf, 8)]);
    final observations = [
      WorkoutGoalObservation(
          id: 'prior',
          startedAt: DateTime.utc(2026, 10, 18, 23),
          observedAt: asOf,
          cameraRepetitions: 16,
          manualSets: 2,
          context: 'Routine A · day 1',
          completed: true),
      WorkoutGoalObservation(
          id: 'current',
          startedAt: DateTime.utc(2026, 10, 19),
          observedAt: asOf,
          cameraRepetitions: 24,
          manualSets: 0,
          context: 'Routine B · day 2',
          completed: true),
    ];
    final values = compareFitnessGoals(
        progress,
        [
          goal('frequency', NumericGoalCategory.trainingFrequency, 4),
          goal('reps', NumericGoalCategory.repetitions, 30),
        ],
        workouts: observations);
    expect(values.first.measuredValue, 1);
    expect(values.first.measurementLabel, contains('UTC'));
    expect(values.last.measuredValue, 24);
    expect(values.last.measurementLabel, contains('Routine B · day 2'));
    expect(values.last.measurementLabel, contains('whole routine attempt'));
  });

  test(
      'profile fact is a separately labelled comparison without camera-derived weight',
      () {
    final p =
        calculateLocalMemberProgress(scope: scope, asOf: asOf, records: []);
    final r = compareFitnessGoals(
            p, [goal('weight', NumericGoalCategory.bodyWeight, 60)],
            profileWeightKg: 65)
        .single;
    expect(r.measuredValue, 65);
    expect(r.measurementLabel, contains('self-reported'));
    expect(
        compareFitnessGoals(
                p, [goal('weight', NumericGoalCategory.bodyWeight, 60)],
                profileWeightKg: double.nan)
            .single
            .measuredValue,
        isNull);
  });

  test(
      'current profile weight is explicitly self-reported and missing camera values remain absent',
      () {
    final p =
        calculateLocalMemberProgress(scope: scope, asOf: asOf, records: []);
    final values = compareFitnessGoals(
        p,
        [
          goal('weight', NumericGoalCategory.bodyWeight, 60),
          goal('reps', NumericGoalCategory.repetitions, 8)
        ],
        profileWeightKg: 72.5);
    expect(values.first.measuredValue, 72.5);
    expect(values.first.measurementLabel, contains('self-reported'));
    expect(values.last.measuredValue, isNull);
  });

  test(
      'camera captures alone cannot supply the UTC weekly workout goal',
      () {
    final progress =
        calculateLocalMemberProgress(scope: scope, asOf: asOf, records: [
      capture('prior-utc-week', DateTime.utc(2026, 10, 18, 23), 5),
      capture('current-utc-week', DateTime.utc(2026, 10, 19, 0, 30), 7),
    ]);
    final result = compareFitnessGoals(progress,
        [goal('frequency', NumericGoalCategory.trainingFrequency, 4)]).single;
    expect(result.measuredValue, isNull);
    expect(result.goal.targetValue, 4);
    expect(result.measurementLabel, contains('UTC'));
    expect(result.provisional, isTrue);
  });
  test(
      'camera sets alone cannot supply a whole workout repetition comparison',
      () {
    final progress =
        calculateLocalMemberProgress(scope: scope, asOf: asOf, records: [
      capture('old', asOf.subtract(const Duration(hours: 2)), 100),
      capture('latest', asOf.subtract(const Duration(minutes: 1)), 7)
    ]);
    final result = compareFitnessGoals(
        progress, [goal('reps', NumericGoalCategory.repetitions, 10)]).single;
    expect(result.measuredValue, isNull);
    expect(result.measurementLabel, contains('whole routine attempt'));
  });
  test(
      'weight targets never fabricate a measurement from pose captures or profile target',
      () {
    final progress = calculateLocalMemberProgress(
        scope: scope,
        asOf: asOf,
        records: [
          capture('one', asOf.subtract(const Duration(minutes: 1)), 7)
        ]);
    final result = compareFitnessGoals(
        progress, [goal('weight', NumericGoalCategory.bodyWeight, 60)]).single;
    expect(result.measuredValue, isNull);
    expect(result.measurementLabel, contains('not recorded'));
  });
  test('empty observations stay unavailable and archived targets stay excluded',
      () {
    final progress =
        calculateLocalMemberProgress(scope: scope, asOf: asOf, records: []);
    final results = compareFitnessGoals(progress, [
      goal('reps', NumericGoalCategory.repetitions, 10),
      goal('archived', NumericGoalCategory.trainingFrequency, 4,
          status: NumericGoalStatus.archived)
    ]);
    expect(results, hasLength(1));
    expect(results.single.measuredValue, isNull);
  });
}
