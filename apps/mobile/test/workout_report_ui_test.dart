import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:gainpath_mobile/features/analytics/domain/member_workout_report.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_report_screen.dart';
import 'member_workout_report_test.dart' as support;
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/activity_timeline_screen.dart';

class ReportExporterFake implements WorkoutReportExporter {
  WorkoutReportDocument? saved;
  bool result = true, fail = false;
  int calls = 0, opened = 0, cancelled = 0;
  Completer<bool>? pending;
  @override
  Future<bool> save(WorkoutReportDocument d) async {
    calls++;
    saved = d;
    if (fail) throw StateError('save failed');
    return pending?.future ?? result;
  }

  @override
  Future<bool> open() async {
    opened++;
    return true;
  }

  @override
  Future<void> cancel() async {
    cancelled++;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('timeline filters in place and exports the selected window',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    WorkoutReportFilter? exported;
    final progress = calculateLocalMemberProgress(
        scope: support.reportScope,
        records: [
          support.reportRecord('recent', support.reportNow),
          support.reportRecord('other-exercise', support.reportNow,
              exercise: 'curl'),
          support.reportRecord(
              'old', support.reportNow.subtract(const Duration(days: 20)))
        ],
        asOf: support.reportNow);
    await tester.pumpWidget(MaterialApp(
        home: ActivityTimelineScreen(
            localProgress: progress,
            onOpenFilteredReport: (filter) => exported = filter)));
    await tester.pumpAndSettle();
    expect(find.text('Measurement details'), findsNWidgets(3));
    await tester.tap(find.text('Last 7 days'));
    await tester.pumpAndSettle();
    expect(find.text('old'), findsNothing);
    expect(find.text('Measurement details'), findsNWidgets(2));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat').last);
    await tester.pumpAndSettle();
    expect(find.text('other-exercise'), findsNothing);
    await tester.tap(find.byTooltip('Export'));
    expect(exported!.exerciseId, 'squat');
    expect(exported!.includes(support.reportNow), isTrue);
    expect(
        exported!
            .includes(support.reportNow.subtract(const Duration(days: 20))),
        isFalse);
    final exporter = ReportExporterFake();
    await tester.pumpWidget(MaterialApp(
        home: WorkoutReportScreen(
            scope: support.reportScope,
            source: LocalMemberProgressSnapshot(
                records: progress.records, routineHistoryAvailable: true),
            asOf: support.reportNow,
            initialFilter: exported,
            exporter: exporter,
            isCurrent: () => true,
            onRefresh: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pumpAndSettle();
    expect(exporter.saved!.lines.join(' '), contains('recent'));
    expect(exporter.saved!.lines.join(' '), isNot(contains('old')));
    expect(exporter.saved!.lines.join(' '), isNot(contains('other-exercise')));
  });
  Future<void> mount(WidgetTester tester, ReportExporterFake exporter,
      {LocalMemberProgressSnapshot? source, bool Function()? active}) async {
    await tester.pumpWidget(MaterialApp(
        home: WorkoutReportScreen(
            scope: support.reportScope,
            source: source ??
                LocalMemberProgressSnapshot(records: [
                  support.reportRecord('squat-record', support.reportNow),
                  support.reportRecord('curl-record', support.reportNow,
                      exercise: 'curl')
                ], routineHistoryAvailable: true),
            asOf: support.reportNow,
            isCurrent: active ?? () => true,
            exporter: exporter,
            onRefresh: () async {})));
    await tester.pumpAndSettle();
  }

  testWidgets('form series renders missing captures as gaps with matching PDF',
      (tester) async {
    final exporter = ReportExporterFake();
    await mount(tester, exporter,
        source: LocalMemberProgressSnapshot(records: [
          support.reportRecord(
              'before', support.reportNow.subtract(const Duration(hours: 2))),
          support.reportRecord('unassessed',
              support.reportNow.subtract(const Duration(hours: 1)),
              score: null),
          support.reportRecord('after', support.reportNow),
        ], routineHistoryAvailable: true));
    final chartFinder = find.byWidgetPredicate((w) =>
        w is SfCartesianChart &&
        w.series.any((s) => s is LineSeries<WorkoutReportFormPoint, String>));
    await tester.scrollUntilVisible(chartFinder, 200,
        scrollable: find.byType(Scrollable).first);
    final chart = tester.widget<SfCartesianChart>(chartFinder);
    final line =
        chart.series.single as LineSeries<WorkoutReportFormPoint, String>;
    expect(line.emptyPointSettings.mode, EmptyPointMode.gap);
    expect(line.dataSource!.map((p) => p.score), [80.0, null, 80.0]);
    expect(line.dataSource!.map((p) => p.key).toSet(), hasLength(3));
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pumpAndSettle();
    expect(exporter.saved!.formTrends.single.points.map((p) => p.score),
        [80.0, null, 80.0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px and large text fit without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue());
    await mount(tester, ReportExporterFake());
    expect(find.text('Workout report'), findsOneWidget);
    final title =
        tester.renderObject<RenderParagraph>(find.text('Workout report'));
    expect(title.didExceedMaxLines, isFalse);
    expect(find.byTooltip('Filter report'), findsOneWidget);
    expect(find.byTooltip('Export PDF'), findsOneWidget);
    expect(find.text('Camera sessions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtered progression timeline uses the same records as PDF',
      (tester) async {
    final exporter = ReportExporterFake();
    await mount(tester, exporter);
    await tester.tap(find.byTooltip('Filter report'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-exercise-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Curl').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    final timeline = find.text('Progression history timeline (1)');
    await tester.scrollUntilVisible(timeline, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Measured AI capture'), findsOneWidget);
    expect(find.text('Curl'), findsWidgets);
    expect(find.textContaining('squat-record'), findsNothing);
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pumpAndSettle();
    expect(exporter.saved!.lines.join('\n'), contains('curl-record'));
    expect(exporter.saved!.lines.join('\n'), isNot(contains('squat-record')));
    expect(tester.takeException(), isNull);
  });
  testWidgets('applied exercise filter controls screen and exported rows',
      (tester) async {
    final exporter = ReportExporterFake();
    await mount(tester, exporter);
    await tester.tap(find.byTooltip('Filter report'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-exercise-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Curl').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pumpAndSettle();
    expect(exporter.saved!.lines.join('\n'), contains('curl-record'));
    expect(exporter.saved!.lines.join('\n'), isNot(contains('squat-record')));
    expect(find.text('PDF saved'), findsOneWidget);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(exporter.opened, 1);
  });
  testWidgets(
      'empty report has truthful text and cancelled export is not success',
      (tester) async {
    final exporter = ReportExporterFake()..result = false;
    await mount(tester, exporter,
        source: LocalMemberProgressSnapshot(
            records: [], routineHistoryAvailable: false));
    expect(find.text('No activity matches these filters.'), findsOneWidget);
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pumpAndSettle();
    expect(find.text('PDF saved'), findsNothing);
    expect(find.text('Export cancelled'), findsOneWidget);
  });
  testWidgets(
      'failed export can retry and duplicate taps do not open two pickers',
      (tester) async {
    final exporter = ReportExporterFake()..pending = Completer<bool>();
    await mount(tester, exporter);
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pump();
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pump();
    expect(exporter.calls, 1);
    exporter.pending!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('PDF could not be saved. Please retry.'), findsOneWidget);
    exporter.pending = null;
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pumpAndSettle();
    expect(exporter.calls, 2);
  });
  testWidgets('account drift discards delayed export response', (tester) async {
    var active = true;
    final exporter = ReportExporterFake()..pending = Completer<bool>();
    await mount(tester, exporter, active: () => active);
    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pump();
    active = false;
    exporter.pending!.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('PDF saved'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(exporter.cancelled, 1);
  });
}
