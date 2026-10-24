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
      'weekly numeric goal uses its documented UTC week, not the display timezone',
      () {
    final progress =
        calculateLocalMemberProgress(scope: scope, asOf: asOf, records: [
      capture('prior-utc-week', DateTime.utc(2026, 10, 18, 23), 5),
      capture('current-utc-week', DateTime.utc(2026, 10, 19, 0, 30), 7),
    ]);
    final result = compareFitnessGoals(progress,
        [goal('frequency', NumericGoalCategory.trainingFrequency, 4)]).single;
    expect(result.measuredValue, 1);
    expect(result.goal.targetValue, 4);
    expect(result.measurementLabel, contains('UTC'));
    expect(result.provisional, isTrue);
  });
  test(
      'repetition comparison uses latest capture and keeps partial attempts separate',
      () {
    final progress =
        calculateLocalMemberProgress(scope: scope, asOf: asOf, records: [
      capture('old', asOf.subtract(const Duration(hours: 2)), 100),
      capture('latest', asOf.subtract(const Duration(minutes: 1)), 7)
    ]);
    final result = compareFitnessGoals(
        progress, [goal('reps', NumericGoalCategory.repetitions, 10)]).single;
    expect(result.measuredValue, 7);
    expect(result.measurementLabel, contains('Latest saved capture'));
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
