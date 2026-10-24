import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/goal_comparison_report.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_performance_screen.dart';

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
