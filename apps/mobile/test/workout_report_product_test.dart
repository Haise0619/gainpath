import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/analytics/domain/member_workout_report.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_report_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_performance_screen.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/posture_accuracy_screen.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'support/workout_analytics_fixture.dart';
import 'workout_report_ui_test.dart' show ReportExporterFake;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('single form result has a bounded recent date axis',
      (tester) async {
    final f = WorkoutAnalyticsFixture();
    await tester.pumpWidget(MaterialApp(
        home: PostureAccuracyScreen(
            localProgress: calculateLocalMemberProgress(
                scope: f.scope,
                records: f.snapshot.records.take(1),
                asOf: f.now))));
    await tester.pumpAndSettle();
    final chart =
        tester.widget<SfCartesianChart>(find.byType(SfCartesianChart));
    final axis = chart.primaryXAxis as DateTimeAxis;
    expect(axis.minimum?.year, 2026);
    expect(axis.maximum?.year, 2026);
  });
  testWidgets('available form assessments precede optional comparisons',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = WorkoutAnalyticsFixture();
    await tester.pumpWidget(MaterialApp(
        home: PostureAccuracyScreen(
            localProgress: calculateLocalMemberProgress(
                scope: f.scope, records: f.snapshot.records, asOf: f.now))));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Estimated form: 84.0%')).dy,
        lessThan(tester.getTopLeft(find.text('PREVIOUS VS RECENT')).dy));
  });
  testWidgets(
      'assessment comparison keeps link and version metadata out of the primary card',
      (tester) async {
    final f = WorkoutAnalyticsFixture();
    await tester.pumpWidget(MaterialApp(
        home: PostureAccuracyScreen(
            localProgress: calculateLocalMemberProgress(
                scope: f.scope, records: f.snapshot.records, asOf: f.now),
            routineProgress: RoutineProgress(
                scope: f.scope, attempts: [f.attempt], asOf: f.now))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recent routine target:'), findsNothing);
    expect(find.textContaining('fixture-model'), findsNothing);
  });
  testWidgets('unsupported assessments do not draw an empty form chart',
      (tester) async {
    final f = WorkoutAnalyticsFixture();
    final records = f.snapshot.records
        .where((r) => r.scoringVersion == 'dumbbell-shoulder-press-front-v1');
    await tester.pumpWidget(MaterialApp(
        home: PostureAccuracyScreen(
            localProgress: calculateLocalMemberProgress(
                scope: f.scope, records: records, asOf: f.now))));
    await tester.pumpAndSettle();
    expect(find.byType(SfCartesianChart), findsNothing);
    expect(find.text('Form assessment not available for this exercise.'),
        findsOneWidget);
  });
  testWidgets(
      'manual filter does not reintroduce AI or video facts in activity',
      (tester) async {
    final f = WorkoutAnalyticsFixture();
    await tester.pumpWidget(MaterialApp(
        home: WorkoutReportScreen(
            scope: f.scope,
            source: f.snapshot,
            asOf: f.now,
            initialFilter: WorkoutReportFilter(exerciseId: 'manual-core'),
            exporter: ReportExporterFake(),
            isCurrent: () => true,
            onRefresh: () async {})));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Workout activity (1)'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('18 AI full reps'), findsNothing);
    expect(find.textContaining('2 timed sets'), findsNothing);
    expect(find.textContaining('2 self-reported sets'), findsWidgets);
  });
  testWidgets(
      'activity trends can filter and export video without any AI captures',
      (tester) async {
    final f = WorkoutAnalyticsFixture();
    WorkoutReportFilter? exported;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutPerformanceScreen(
            localProgress: calculateLocalMemberProgress(
                scope: f.scope, records: const [], asOf: f.now),
            routineProgress: RoutineProgress(
                scope: f.scope, attempts: [f.attempt], asOf: f.now),
            onOpenFilteredReport: (filter) => exported = filter)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Burpee'), findsOneWidget);
    await tester.tap(find.text('Burpee'));
    await tester.pumpAndSettle();
    expect(find.text('1m 30s'), findsOneWidget);
    await tester.ensureVisible(find.text('Export PDF'));
    await tester.tap(find.text('Export PDF'));
    expect(exported?.exerciseId, 'burpee-video');
  });
  testWidgets(
      'mixed report leads with each mode and keeps internal IDs in details',
      (tester) async {
    final f = WorkoutAnalyticsFixture();
    await tester.pumpWidget(MaterialApp(
        home: WorkoutReportScreen(
            scope: f.scope,
            source: f.snapshot,
            asOf: f.now,
            exporter: ReportExporterFake(),
            isCurrent: () => true,
            onRefresh: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('analytics-squat').hitTestable(), findsNothing);
    await tester.scrollUntilVisible(find.text('Video Timed'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Video Timed'), findsOneWidget);
    expect(find.textContaining('1m 30s'), findsWidgets);
  });
  testWidgets(
      'routine appears once and linked captures stay inside its breakdown',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = WorkoutAnalyticsFixture();
    var opened = '';
    await tester.pumpWidget(MaterialApp(
        home: WorkoutReportScreen(
            scope: f.scope,
            source: f.snapshot,
            asOf: f.now,
            exporter: ReportExporterFake(),
            isCurrent: () => true,
            onRefresh: () async {},
            onOpenWorkout: (record) => opened = record.sessionId)));
    await tester.pumpAndSettle();
    final parent = find.byWidgetPredicate((w) =>
        w is ExpansionTile && w.key.toString().contains('report-workout-'));
    await tester.scrollUntilVisible(parent, 200,
        scrollable: find.byType(Scrollable).first);
    expect(parent, findsOneWidget);
    expect(find.text('View Squat result'), findsNothing);
    await tester.tap(find
        .descendant(
            of: parent, matching: find.textContaining('Everyday Strength'))
        .first);
    await tester.pumpAndSettle();
    expect(find.text('View Squat result'), findsOneWidget);
    expect(find.text('View Shoulder Press result'), findsOneWidget);
    expect(find.textContaining('Video Timed · 2 sets'), findsOneWidget);
    expect(find.text('Manual · 2 user-recorded sets'), findsOneWidget);
    await tester.ensureVisible(find.text('View Squat result'));
    await tester.tap(find.text('View Squat result'));
    expect(opened, 'analytics-squat');
    expect(find.text('Routine attempts (1)'), findsNothing);
  });
  testWidgets(
      'unsupported AI score is unavailable and technical evidence is disclosed',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = WorkoutAnalyticsFixture();
    await tester.pumpWidget(MaterialApp(
        home: WorkoutReportScreen(
            scope: f.scope,
            source: f.snapshot,
            asOf: f.now,
            exporter: ReportExporterFake(),
            isCurrent: () => true,
            onRefresh: () async {})));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Form assessment not available for this exercise.'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('0.0%'), findsNothing);
    expect(find.textContaining('fixture-model'), findsNothing);
    expect(find.textContaining('analytics-squat'), findsNothing);
    expect(find.byType(SfCartesianChart), findsNothing);
  });
  testWidgets(
      'reviewed and skipped exercises never become zero manual activity',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = WorkoutAnalyticsFixture();
    final attempt = RoutineAttempt(
        id: f.attempt.id,
        scope: f.scope,
        routine: f.routine,
        day: 1,
        finished: false,
        updatedAtMicros: f.now.microsecondsSinceEpoch,
        entries: [
          for (final entry in f.attempt.entries)
            if (entry.index == 0 || entry.index == 2)
              RoutineExerciseResult(
                  index: entry.index,
                  status: entry.index == 0
                      ? RoutineExerciseStatus.instructionsReviewed
                      : RoutineExerciseStatus.skipped,
                  sessionIds: [],
                  fullRepetitions: 0,
                  partialRepetitions: 0,
                  trackedDurationMicros: 0,
                  manualSets: 0)
            else
              entry
        ]);
    await tester.pumpWidget(MaterialApp(
        home: WorkoutReportScreen(
            scope: f.scope,
            source: LocalMemberProgressSnapshot(
                records: [],
                attempts: [attempt],
                routineHistoryAvailable: true),
            asOf: f.now,
            exporter: ReportExporterFake(),
            isCurrent: () => true,
            onRefresh: () async {})));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Everyday Strength'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Everyday Strength'));
    await tester.pumpAndSettle();
    expect(find.text('Instructions reviewed · no activity recorded'),
        findsOneWidget);
    expect(find.text('Skipped · no activity recorded'), findsOneWidget);
    expect(find.text('Manual · 0 user-recorded sets'), findsNothing);
    expect(find.text('AI Tracked · 0 full reps · 0 partial attempts'),
        findsNothing);
  });
  test('PDF places useful mixed evidence before technical appendix', () {
    final f = WorkoutAnalyticsFixture();
    final report = MemberWorkoutReport.build(
        scope: f.scope,
        source: f.snapshot,
        filter: WorkoutReportFilter.all(),
        asOf: f.now);
    expect(report.fullReps, 18);
    expect(report.sessions, hasLength(2));
    expect(report.manualSets, 2);
    final lines = report.toDocument().lines;
    final text = lines.join('\n');
    expect(lines.first, 'GainPath | Training Report');
    expect(text, contains('VIDEO TIMED'));
    expect(text, contains('90'));
    expect(text, contains('Attempt-weighted'));
    expect(lines.indexOf('TECHNICAL APPENDIX'),
        greaterThan(lines.indexOf('VIDEO TIMED')));
  });
}
