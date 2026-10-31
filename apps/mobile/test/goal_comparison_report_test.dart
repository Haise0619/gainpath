import 'package:flutter/material.dart';
import 'support/fitness_profile_fake.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/goal_comparison_report.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_performance_screen.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'routine_journey_controller_test.dart' as support;

class Targets implements NumericFitnessGoalRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  List<NumericFitnessGoal> values = [];
  bool fail = false;
  @override
  Future<List<NumericFitnessGoal>> loadActive() async {
    if (fail) throw StateError('offline');
    return values;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'compact goals retain self reported source and open real editor entry',
      (tester) async {
    final repo = Targets()
      ..values = [
        NumericFitnessGoal(
            id: 'weight',
            category: NumericGoalCategory.bodyWeight,
            targetValue: 60,
            status: NumericGoalStatus.active,
            revision: 1,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026))
      ];
    final profiles = FakeProfileGateway().repository(repo.scope);
    await profiles.save(sampleProfile());
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GoalComparisonReport(
                repository: repo,
                progress: calculateLocalMemberProgress(
                    scope: repo.scope,
                    records: [],
                    asOf: DateTime.utc(2026, 10, 29)),
                profileRepository: profiles,
                isCurrent: () => true,
                compact: true,
                onView: () => opened++))));
    await tester.pumpAndSettle();
    expect(find.text('Target: 60 kg'), findsOneWidget);
    expect(find.text('Current: 65.0 kg'), findsOneWidget);
    expect(find.textContaining('measurement date unavailable'), findsOneWidget);
    await tester.tap(find.text('View / edit goals'));
    expect(opened, 1);
  });

  test(
      'remaining target labels preserve unavailable and body weight direction uncertainty',
      () {
    FitnessGoalComparison comparison(
            NumericGoalCategory category, double? observed) =>
        FitnessGoalComparison(
            goal: NumericFitnessGoal(
                id: 'g',
                category: category,
                targetValue:
                    category == NumericGoalCategory.bodyWeight ? 70 : 4,
                status: NumericGoalStatus.active,
                revision: 1,
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026)),
            measuredValue: observed,
            measurementLabel: 'source');
    expect(
        goalRemainingLabel(
            comparison(NumericGoalCategory.trainingFrequency, 2)),
        'Remaining: 2 workouts');
    expect(goalRemainingLabel(comparison(NumericGoalCategory.repetitions, 8)),
        'Target met in this provisional observation');
    expect(
        goalRemainingLabel(comparison(NumericGoalCategory.repetitions, null)),
        'Remaining target unavailable');
    expect(goalRemainingLabel(comparison(NumericGoalCategory.bodyWeight, 75)),
        'Profile weight is 5.0 kg above target · direction is not configured');
    expect(goalRemainingLabel(comparison(NumericGoalCategory.bodyWeight, 68)),
        'Profile weight is 2.0 kg below target · direction is not configured');
    expect(goalRemainingLabel(comparison(NumericGoalCategory.bodyWeight, 70)),
        'Profile weight matches target · self-reported, date unknown');
  });

  testWidgets(
      'workout comparison separates routine attempts, training dates and manual sets',
      (t) async {
    final repo = Targets()
      ..values = [
        NumericFitnessGoal(
            id: 'frequency',
            category: NumericGoalCategory.trainingFrequency,
            targetValue: 4,
            status: NumericGoalStatus.active,
            revision: 1,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026))
      ];
    final now = DateTime.utc(2026, 10, 29, 10);
    final routines = RoutineProgress(scope: repo.scope, asOf: now, attempts: [
      for (var i = 0; i < 2; i++)
        RoutineAttempt(
            id: 'attempt-$i',
            scope: repo.scope,
            routine: support.routineFixture(),
            day: 1,
            finished: true,
            startedAtMicros:
                now.subtract(Duration(hours: i + 1)).microsecondsSinceEpoch,
            finishedAtMicros: now.microsecondsSinceEpoch,
            updatedAtMicros: now.microsecondsSinceEpoch,
            entries: [
              RoutineExerciseResult(
                  index: 0,
                  status: RoutineExerciseStatus.selfReportedCompleted,
                  sessionIds: [],
                  fullRepetitions: 0,
                  partialRepetitions: 0,
                  trackedDurationMicros: 0,
                  manualSets: 2)
            ]),
      for (final missingStart in [false, true])
        RoutineAttempt(
            id: 'excluded-$missingStart',
            scope: repo.scope,
            routine: support.routineFixture(),
            day: 1,
            finished: false,
            startedAtMicros: missingStart ? null : now.microsecondsSinceEpoch,
            updatedAtMicros: now.microsecondsSinceEpoch,
            entries: [
              RoutineExerciseResult(
                  index: 0,
                  status: RoutineExerciseStatus.notStarted,
                  sessionIds: [],
                  fullRepetitions: 0,
                  partialRepetitions: 0,
                  trackedDurationMicros: 0,
                  manualSets: missingStart ? 2 : 0)
            ])
    ]);
    await t.pumpWidget(MaterialApp(
        home: GoalComparisonReport(
            repository: repo,
            progress: calculateLocalMemberProgress(
                scope: repo.scope, records: [], asOf: now),
            routineProgress: routines,
            isCurrent: () => true)));
    await t.pumpAndSettle();
    expect(find.text('Remaining: 2 workouts'), findsOneWidget);
    expect(find.text('Set / edit targets'), findsOneWidget);
    await t.tap(find.text('How this week is counted'));
    await t.pumpAndSettle();
    expect(
        find.textContaining(
            '0 camera captures · 2 workout attempts started · 1 distinct training days · 2 completed routine-day attempts'),
        findsOneWidget);
    expect(find.text('Measured: 2 sessions'), findsOneWidget);
    expect(find.textContaining('Monday–Sunday UTC.'), findsOneWidget);
  });

  testWidgets(
      'real profile weight is self-reported and never an AI measurement',
      (t) async {
    final repo = Targets()
      ..values = [
        NumericFitnessGoal(
            id: 'weight',
            category: NumericGoalCategory.bodyWeight,
            targetValue: 60,
            status: NumericGoalStatus.active,
            revision: 1,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026))
      ];
    final profiles = FakeProfileGateway().repository(repo.scope);
    await profiles.save(sampleProfile());
    final progress = calculateLocalMemberProgress(
        scope: repo.scope, records: [], asOf: DateTime.utc(2026, 10, 29));
    await t.pumpWidget(MaterialApp(
        home: GoalComparisonReport(
            repository: repo,
            progress: progress,
            profileRepository: profiles,
            isCurrent: () => true)));
    await t.pumpAndSettle();
    expect(find.text('Profile (self-reported): 65.0 kg'), findsOneWidget);
    expect(find.textContaining('measurement date unavailable'), findsOneWidget);
    expect(find.text('Measured: 65 kg'), findsNothing);
  });

  testWidgets(
      'live performance presents measured trends without fake weight charts',
      (tester) async {
    final repo = Targets();
    final progress = calculateLocalMemberProgress(
        scope: repo.scope, records: [], asOf: DateTime.utc(2026, 10, 23));
    await tester.pumpWidget(
        MaterialApp(home: WorkoutPerformanceScreen(localProgress: progress)));
    await tester.pumpAndSettle();
    expect(find.text('Measured workout trends'), findsOneWidget);
    expect(find.text('Weekly volume (kg)'), findsNothing);
    await tester.tap(find.text('About measurements'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Weight and muscle-group volume are not recorded'),
        findsOneWidget);
  });
  testWidgets(
      'real targets show missing measurements without fabricated gauges',
      (tester) async {
    final repo = Targets();
    repo.values = [
      NumericFitnessGoal(
          id: 'weight',
          category: NumericGoalCategory.bodyWeight,
          targetValue: 60,
          status: NumericGoalStatus.active,
          revision: 1,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026))
    ];
    final progress = calculateLocalMemberProgress(
        scope: repo.scope, records: [], asOf: DateTime.utc(2026, 10, 23));
    await tester.pumpWidget(MaterialApp(
        home: GoalComparisonReport(
            repository: repo, progress: progress, isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('Target: 60 kg'), findsOneWidget);
    expect(find.text('No measured value available'), findsOneWidget);
    expect(find.text('60 of 70 kg'), findsNothing);
    expect(find.textContaining('No achievement or reward'), findsOneWidget);
  });
  testWidgets('goal load fails with retry and no preview targets',
      (tester) async {
    final repo = Targets()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: GoalComparisonReport(
            repository: repo, progress: null, isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No active numeric targets yet. Set targets in Profile.'),
        findsOneWidget);
  });
  testWidgets('session change hides saved targets immediately on rebuild',
      (tester) async {
    final repo = Targets();
    var current = true;
    final widget = GoalComparisonReport(
        repository: repo, progress: null, isCurrent: () => current);
    await tester.pumpWidget(MaterialApp(home: widget));
    await tester.pumpAndSettle();
    current = false;
    await tester.pumpWidget(MaterialApp(
        home: GoalComparisonReport(
            repository: repo, progress: null, isCurrent: () => current)));
    await tester.pump();
    expect(
        find.text('Sign in to view this account’s targets.'), findsOneWidget);
    expect(find.textContaining('No active numeric targets'), findsNothing);
  });
}
