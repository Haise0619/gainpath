import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:gainpath_mobile/features/analytics/presentation/member/activity_timeline_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/posture_accuracy_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_performance_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/shared/progress_dashboard_screen.dart';

final _scope = SessionScope(userId: 'member-a', organizationId: 'org-a');

LocalWorkoutProgressRecord _record({
  String id = 'capture-a',
  int repetitions = 4,
  int partials = 2,
  double? score = 73,
  String scoringVersion = 'rule-a',
  LocalWorkoutRecordStatus status = LocalWorkoutRecordStatus.localOnly,
  int day = 13,
  int tracked = 3000000,
  int rejected = 1000000,
}) =>
    LocalWorkoutProgressRecord(
      scope: _scope,
      sessionId: id,
      exerciseId: 'squat',
      startedAt: DateTime.utc(2026, 10, day, 1),
      endedAt: DateTime.utc(2026, 10, day, 1, 1),
      repetitions: repetitions,
      partialRepetitions: partials,
      formScorePercent: score,
      trackedDurationMicros: tracked,
      rejectedDurationMicros: rejected,
      scoringVersion: scoringVersion,
      detectorId: 'detector-a',
      detectorVersion: 'model-a',
      cameraView: 'side',
      status: status,
    );

MemberLocalProgress _progress(List<LocalWorkoutProgressRecord> records) =>
    calculateLocalMemberProgress(
        scope: _scope, records: records, asOf: DateTime.utc(2026, 10, 13, 3));

Future<void> _show(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.build(), home: screen));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'timeline date filter changes visible captures and opens actual record',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LocalWorkoutProgressRecord? opened;
    await _show(
        tester,
        ActivityTimelineScreen(
            localProgress: _progress(
                [_record(id: 'old', day: 1), _record(id: 'recent', day: 13)]),
            onOpenWorkout: (r) => opened = r));
    await tester.tap(find.text('Last 7 days'));
    await tester.pumpAndSettle();
    expect(find.text('old'), findsNothing);
    expect(find.text('Squat'), findsOneWidget);
    await tester.tap(find.text('Squat'));
    expect(opened?.sessionId, 'recent');
  });

  testWidgets('live estimated form never renders empty legacy accuracy charts',
      (tester) async {
    await _show(tester, PostureAccuracyScreen(localProgress: _progress([])));
    expect(find.text('Estimated Form Scores'), findsOneWidget);
    expect(find.byType(SfCartesianChart), findsNothing);
    expect(find.text('No estimated form measurements yet.'), findsOneWidget);
    expect(find.text('Form accuracy over time'), findsNothing);
  });

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'live dashboard excludes unsupported placeholders and labels real metrics',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _show(
        tester, ProgressDashboardScreen(localProgress: _progress([_record()])));
    expect(find.text('kg Volume'), findsNothing);
    expect(find.text('Avg Form'), findsNothing);
    expect(find.text('Day Streak'), findsNothing);
    expect(find.text('Volume and muscle group split'), findsNothing);
    expect(find.text('Training days'), findsOneWidget);
    expect(find.text('Training days'), findsOneWidget);
    expect(find.text('Measurement details'), findsOneWidget);
    expect(find.text('Saved sessions'), findsNothing);
  });
  testWidgets(
      'form chart uses actual UTC instants and explicit Malaysia labels near midnight',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _show(
        tester, PostureAccuracyScreen(localProgress: _progress([_record()])));
    final chart = tester
        .widgetList<SfCartesianChart>(find.byType(SfCartesianChart))
        .singleWhere((chart) => chart.primaryXAxis is DateTimeAxis);
    final dynamic series = chart.series.single;
    final record = series.dataSource.single as LocalWorkoutProgressRecord;
    expect(series.xValueMapper(record, 0), record.endedAt);
    final axis = chart.primaryXAxis as DateTimeAxis;
    expect(axis.axisLabelFormatter, isNotNull);
    final instant = DateTime.utc(2026, 10, 12, 15); // 12 Oct 23:00 in Malaysia.
    final details = AxisLabelRenderDetails(
        instant.millisecondsSinceEpoch,
        'ignored machine-local label',
        const TextStyle(),
        axis.createRenderer(),
        DateTimeIntervalType.days,
        null);
    expect(axis.axisLabelFormatter!(details).text, '12/10/2026');
    final next = AxisLabelRenderDetails(
        instant.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'ignored',
        const TextStyle(),
        axis.createRenderer(),
        DateTimeIntervalType.days,
        null);
    expect(axis.axisLabelFormatter!(next).text, '13/10/2026');
    expect(chart.tooltipBehavior!.builder, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('dashboard delegates reports to account-owned routes',
      (tester) async {
    final opened = <String>[];
    await _show(
        tester,
        ProgressDashboardScreen(
          localProgress: _progress([_record()]),
          onOpenHistory: () => opened.add('history'),
          onOpenReport: () => opened.add('reports'),
          onOpenPoints: () => opened.add('points'),
          onOpenBackup: () => opened.add('backup'),
          onOpenPerformance: () => opened.add('performance'),
          onOpenForm: () => opened.add('form'),
        ));
    Future<void> open(String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    for (final label in [
      'History',
      'View reports',
      'Estimated Form Scores',
      'Points & streak',
      'Workout backup'
    ]) {
      await open(label);
    }
    expect(find.text('Workout performance'), findsNothing);
    await open('Measurement details');
    await open('Workout performance');
    expect(opened,
        ['history', 'reports', 'form', 'points', 'backup', 'performance']);
    expect(find.text('Your progress'), findsOneWidget);
  });
  testWidgets('live dashboard uses saved measured totals and opens a record',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    LocalWorkoutProgressRecord? opened;
    await _show(
        tester,
        ProgressDashboardScreen(
          localProgress: _progress([
            _record(),
            _record(id: 'capture-b', repetitions: 0, partials: 1, score: null)
          ]),
          onOpenWorkout: (record) => opened = record,
        ));
    expect(find.text('Training days'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3,400'), findsNothing);
    await tester.ensureVisible(find.text('Squat').first);
    await tester.tap(find.text('Squat').first);
    expect(opened?.sessionId, 'capture-a');
    await tester.ensureVisible(find.text('Measurement details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Measurement details'));
    await tester.pumpAndSettle();
    expect(find.text('4 full reps · 3 partial attempts this week'),
        findsOneWidget);
    expect(find.text('Measurement coverage: 75%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty live dashboard shows missing coverage and refresh works',
      (tester) async {
    var refreshes = 0;
    await _show(
        tester,
        ProgressDashboardScreen(
          localProgress: _progress([]),
          onRefresh: () async {
            refreshes++;
          },
        ));
    expect(
        find.text(
            'No camera workouts recorded yet. Routine history is unavailable.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Measurement details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Measurement details'));
    await tester.pumpAndSettle();
    expect(find.text('Measurement coverage: Unavailable'), findsOneWidget);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(refreshes, 1);
  });

  testWidgets(
      'timeline retains all upload states and provisional score meaning',
      (tester) async {
    await _show(
        tester,
        ActivityTimelineScreen(
            localProgress: _progress([
          for (final status in LocalWorkoutRecordStatus.values)
            _record(id: status.name, status: status),
        ])));
    for (final label in [
      'Server-accepted',
      'Provisional · local only',
      'Pending upload',
      'Upload rejected',
      'Pending upload · retry needed',
      'Upload status unavailable'
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200);
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byTooltip('Export'), findsOneWidget);
    expect(find.textContaining('Provisional estimate'), findsNothing);
    await tester.scrollUntilVisible(
        find.text('Measurement details').first, -200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Measurement details').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Measurement details').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Provisional estimate'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('performance charts contain actual weekly session and rep values',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _show(
        tester,
        WorkoutPerformanceScreen(
            localProgress: _progress([
          _record(id: 'older', day: 6, repetitions: 7),
          _record(repetitions: 4),
        ])));
    final charts = tester
        .widgetList<SfCartesianChart>(find.byType(SfCartesianChart))
        .where((chart) =>
            chart.series.single.name == 'Saved sessions' ||
            chart.series.single.name == 'Full reps')
        .toList();
    expect(charts, hasLength(2));
    final values = <num?>[];
    for (final chart in charts) {
      final dynamic series = chart.series.single;
      for (var i = 0; i < series.dataSource.length; i++) {
        values.add(series.yValueMapper(series.dataSource[i], i) as num?);
      }
    }
    expect(values, [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 7, 4]);
    expect(find.text('WEEKLY VOLUME (KG)'), findsNothing);
    expect(find.text('MUSCLE GROUP SPLIT'), findsNothing);
    expect(find.text('About measurements'), findsOneWidget);
    expect(
        find.textContaining('Weight and muscle-group volume are not recorded'),
        findsNothing);
    await tester.tap(find.text('About measurements'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Weight and muscle-group volume are not recorded'),
        findsOneWidget);
    expect(find.text('3,400'), findsNothing);
    expect(find.byTooltip('Export'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('form groups versions and preserves unassessed chart gaps',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _show(
        tester,
        PostureAccuracyScreen(
            localProgress: _progress([
          _record(id: 'first', day: 6, score: 73),
          _record(id: 'gap', score: null),
          _record(id: 'new-version', score: 91, scoringVersion: 'rule-b'),
        ])));
    expect(find.text('Estimated Form Scores'), findsOneWidget);
    expect(find.textContaining('rule-a'), findsWidgets);
    expect(find.textContaining('rule-b'), findsWidgets);
    final charts = tester
        .widgetList<SfCartesianChart>(find.byType(SfCartesianChart))
        .where((chart) => chart.primaryXAxis is DateTimeAxis)
        .toList();
    expect(charts, hasLength(2));
    final dynamic series = charts.first.series.single;
    expect(series.dataSource, hasLength(2));
    expect(series.yValueMapper(series.dataSource[0], 0), 73);
    expect(series.yValueMapper(series.dataSource[1], 1), isNull);
    expect(find.textContaining('unassessed'), findsWidgets);
    expect(
        find.text('6 scored attempts · 6 unassessed attempts'), findsOneWidget);
    expect(
        find.text('6 scored attempts · 0 unassessed attempts'), findsOneWidget);
    expect(find.text('FORM ACCURACY OVER TIME'), findsNothing);
    expect(find.text('BY EXERCISE'), findsNothing);
    expect(find.text('84%'), findsNothing);
    expect(find.byTooltip('Filter report and export PDF'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('live dashboard fits narrow screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
        home: ProgressDashboardScreen(localProgress: _progress([_record()]))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
