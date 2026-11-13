import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_data.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/analytics/presentation/program_adherence_host.dart';
import 'support/workout_analytics_fixture.dart';

final scope =
    SessionScope(userId: 'progress-fixture', organizationId: 'gainpath');
final now = DateTime.utc(2026, 11, 13, 8);
LocalWorkoutProgressRecord capture(String id, DateTime at,
        {double? score = 80,
        String rule = 'squat-v1',
        String exercise = 'squat',
        String model = 'model',
        String? arm}) =>
    LocalWorkoutProgressRecord(
        scope: scope,
        sessionId: id,
        exerciseId: exercise,
        startedAt: at.subtract(const Duration(minutes: 1)),
        endedAt: at,
        repetitions: 10,
        partialRepetitions: 1,
        formScorePercent: score,
        trackedDurationMicros: 20000000,
        rejectedDurationMicros: 0,
        scoringVersion: rule,
        detectorId: 'detector',
        detectorVersion: model,
        cameraView: 'side',
        armMode: arm,
        status: LocalWorkoutRecordStatus.localOnly);
MemberLocalProgress progress(List<LocalWorkoutProgressRecord> records) =>
    calculateLocalMemberProgress(scope: scope, records: records, asOf: now);
Future<void> show(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.build(), home: screen));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('reduced motion bypasses dashboard entrance animations',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: ProgressDashboardScreen(localProgress: progress([]))));
    await tester.pump();
    expect(
        find.descendant(
            of: find.byType(ProgressDashboardScreen),
            matching: find.byType(FadeTransition)),
        findsNothing);
    expect(
        find.descendant(
            of: find.byType(ProgressDashboardScreen),
            matching: find.byType(SlideTransition)),
        findsNothing);
    expect(find.text('This week'), findsOneWidget);
  });
  test(
      'activity uses one Malaysia week and excludes older and future mixed-mode records',
      () {
    final f = WorkoutAnalyticsFixture();
    final p = calculateLocalMemberProgress(
        scope: f.scope, records: f.snapshot.records, asOf: f.now);
    RoutineAttempt at(String id, DateTime time) => RoutineAttempt(
        id: id,
        scope: f.scope,
        routine: f.routine,
        day: 1,
        finished: true,
        startedAtMicros:
            time.subtract(const Duration(minutes: 5)).microsecondsSinceEpoch,
        finishedAtMicros: time.microsecondsSinceEpoch,
        updatedAtMicros: time.microsecondsSinceEpoch,
        entries: f.attempt.entries);
    final history = RoutineProgress(scope: f.scope, asOf: f.now, attempts: [
      f.attempt,
      f.attempt,
      at('prior-week', p.weekStart.subtract(const Duration(microseconds: 1))),
      at('future', f.now.add(const Duration(days: 1))),
      at('monday', p.weekStart),
    ]);
    final data = ProgressDashboardData(p, history);
    expect(data.weekly.fullReps, 18);
    expect(data.weekly.guidedMicros, 180000000);
    expect(data.weekly.manualSets, 4);
    expect(data.weekly.routines.map((r) => r.attempt.id),
        containsAll(['monday', f.attempt.id]));
    expect(data.weekly.routines, hasLength(2));
    expect(data.report.routines, hasLength(3));
    expect(
        () => ProgressDashboardData(progress([]), history), throwsStateError);
  });
  test(
      'missing routine history is unknown and comparison never crosses view model arm or version',
      () {
    final data = ProgressDashboardData(
        progress([
          capture('latest', now, arm: 'leftOnly'),
          capture('other-arm', now.subtract(const Duration(hours: 1)),
              score: 10, arm: 'rightOnly'),
          capture('other-rule', now.subtract(const Duration(hours: 2)),
              score: 20, rule: 'other', arm: 'leftOnly'),
          capture('other-model', now.subtract(const Duration(hours: 3)),
              score: 30, model: 'other', arm: 'leftOnly'),
        ]),
        null);
    expect(data.weekly.manualSets, isNull);
    expect(data.weekly.guidedMicros, isNull);
    expect(data.assessments.single.change, isNull);
  });
  testWidgets(
      'summary-only program host omits empty and past program UI without changing full host',
      (tester) async {
    await show(
        tester,
        Scaffold(
            body: ProgramAdherenceHost(
                scope: scope,
                activeScope: () => scope,
                summaryOnly: true,
                load: () async => [],
                weeklySummaryBuilder: (_, done, total) =>
                    Text('Summary $done/$total'))));
    expect(find.text('Summary 0/0'), findsOneWidget);
    expect(find.text('Current program'), findsNothing);
    expect(find.text('Program details & past programs'), findsNothing);
  });
  testWidgets(
      'empty schedule is absent and overview has one weekday label per day',
      (tester) async {
    await show(
        tester,
        ProgressDashboardScreen(
            localProgress: progress([]),
            programStatsBuilder: (summary) =>
                Builder(builder: (c) => summary(c, 0, 0))));
    expect(find.text('0 / 0'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Scheduled completion'), findsNothing);
    expect(find.text('Open training plan'), findsNothing);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('T'), findsNWidgets(2));
    expect(find.text('No workouts recorded this week.'), findsOneWidget);
  });
  testWidgets(
      'latest valid form is shown once and only exact compatible score is compared',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await show(
        tester,
        ProgressDashboardScreen(
            localProgress: progress([
          capture('new-unscored', now, score: null),
          capture('valid', now.subtract(const Duration(hours: 1)), score: 82),
          capture('incompatible', now.subtract(const Duration(hours: 2)),
              score: 20, model: 'other'),
          capture('previous', now.subtract(const Duration(days: 1)), score: 75),
          capture('unsupported', now,
              score: 99,
              rule: 'dumbbell-shoulder-press-front-v1',
              exercise: 'press'),
        ])));
    expect(find.text('82/100'), findsOneWidget);
    expect(find.text('+7 points vs previous assessment'), findsOneWidget);
    expect(find.text('99/100'), findsNothing);
    expect(find.textContaining('rules pending'), findsNothing);
    expect(find.text('View All Assessments'), findsOneWidget);
    expect(find.byKey(const Key('progress-latest-workout')), findsOneWidget);
  });
  testWidgets(
      'all assessments distinguishes missing unscored and unsupported and opens actual result',
      (tester) async {
    LocalWorkoutProgressRecord? opened;
    await show(
        tester,
        ProgressDashboardScreen(
            localProgress: progress([
              capture('unscored', now, score: null),
              capture('press', now,
                  score: null,
                  exercise: 'dumbbell-shoulder-press-front-v1',
                  rule: 'dumbbell-shoulder-press-front-v1'),
            ]),
            onOpenWorkout: (r) => opened = r));
    await tester.ensureVisible(find.text('View All Assessments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All Assessments'));
    await tester.pumpAndSettle();
    expect(find.text('No sessions yet'), findsWidgets);
    expect(find.text('Session saved · no form score'), findsOneWidget);
    expect(find.text('Form scoring not available'), findsWidgets);
    await tester.tap(find.text('Squat'));
    expect(opened?.sessionId, 'unscored');
  });
  testWidgets(
      'only latest workout is visible; history and trends retain destinations',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var history = 0, trends = 0;
    LocalWorkoutProgressRecord? opened;
    await show(
        tester,
        ProgressDashboardScreen(
            localProgress: progress([
              capture('latest', now, exercise: 'squat'),
              capture('old', now.subtract(const Duration(days: 1)),
                  exercise: 'curl', score: null),
            ]),
            onOpenHistory: () => history++,
            onOpenPerformance: () => trends++,
            onOpenWorkout: (r) => opened = r));
    expect(find.text('Latest workout'), findsOneWidget);
    await tester.tap(find.text('View History'));
    await tester.tap(find.text('View Activity Trends'));
    await tester.tap(find.byKey(const Key('progress-latest-workout')));
    expect(history, 1);
    expect(trends, 1);
    expect(opened?.sessionId, 'latest');
  });
}
