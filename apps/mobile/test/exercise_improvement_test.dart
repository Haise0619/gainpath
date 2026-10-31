import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'routine_journey_controller_test.dart' as support;
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/analytics/domain/exercise_improvement.dart';

void main() {
  final scope = SessionScope(userId: 'a', organizationId: 'o');
  LocalWorkoutProgressRecord record(int day, double? score,
          {String rule = 'r', String exercise = 'squat'}) =>
      LocalWorkoutProgressRecord(
          scope: scope,
          sessionId: '$day$rule',
          exerciseId: exercise,
          startedAt: DateTime.utc(2026, 10, day),
          endedAt: DateTime.utc(2026, 10, day, 0, 1),
          repetitions: 4,
          partialRepetitions: 1,
          trackedDurationMicros: 1000000,
          rejectedDurationMicros: 0,
          formScorePercent: score,
          scoringVersion: rule,
          detectorId: 'd',
          detectorVersion: 'v',
          cameraView: 'side',
          status: LocalWorkoutRecordStatus.localOnly);
  test(
      'routine target requires a unique same-account exercise and session link',
      () {
    final capture = record(1, 60, exercise: 'F3b8xIr8ynBDd3gEICKX');
    final plan = support.routineFixture();
    RoutineAttempt attempt(String id, {SessionScope? owner}) => RoutineAttempt(
            id: id,
            scope: owner ?? scope,
            routine: plan,
            day: 1,
            finished: false,
            updatedAtMicros: DateTime.utc(2026, 10, 2).microsecondsSinceEpoch,
            entries: [
              RoutineExerciseResult(
                  index: 0,
                  status: RoutineExerciseStatus.partial,
                  sessionIds: [capture.sessionId],
                  fullRepetitions: 4,
                  partialRepetitions: 1,
                  trackedDurationMicros: 1000000,
                  manualSets: 0)
            ]);
    RoutineProgress progress(List<RoutineAttempt> attempts) => RoutineProgress(
        scope: scope, asOf: DateTime.utc(2026, 10, 3), attempts: attempts);
    expect(linkedRoutineTarget(capture, progress([attempt('one')])),
        contains('1 sets × 2 reps'));
    expect(
        linkedRoutineTarget(
            capture, progress([attempt('one'), attempt('two')])),
        isNull);
    final foreignScope = SessionScope(userId: 'other', organizationId: 'o');
    expect(
        linkedRoutineTarget(
            capture,
            RoutineProgress(
                scope: foreignScope,
                asOf: DateTime.utc(2026, 10, 3),
                attempts: [attempt('foreign', owner: foreignScope)])),
        isNull);
    expect(linkedRoutineTarget(capture, null), isNull);
  });
  test('compatible comparisons preserve missing-score gaps and separate rules',
      () {
    final p = calculateLocalMemberProgress(
        scope: scope,
        records: [
          record(1, 50),
          record(2, null),
          record(3, 80),
          record(4, 99, rule: 'other')
        ],
        asOf: DateTime.utc(2026, 10, 5));
    final groups = exerciseImprovements(p);
    expect(groups.length, 2);
    expect(groups.firstWhere((g) => g.latest.scoringVersion == 'r').scoreChange,
        isNull);
  });
  test('compatible previous and recent expose exact score points', () {
    final p = calculateLocalMemberProgress(
        scope: scope,
        records: [record(1, 50), record(2, 80)],
        asOf: DateTime.utc(2026, 10, 5));
    expect(exerciseImprovements(p).single.scoreChange, 30);
  });
}
