import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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
  testWidgets('measured timeline filter and export open the shared report',
      (tester) async {
    var opened = 0;
    final progress = calculateLocalMemberProgress(
        scope: support.reportScope,
        records: [support.reportRecord('camera', support.reportNow)],
        asOf: support.reportNow);
    await tester.pumpWidget(MaterialApp(
        home: ActivityTimelineScreen(
            localProgress: progress, onOpenReport: () => opened++)));
    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    expect(opened, 2);
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

  testWidgets('320px and large text fit without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue());
    await mount(tester, ReportExporterFake());
    expect(find.text('Workout report'), findsOneWidget);
    expect(find.text('Camera sessions'), findsOneWidget);
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
    await tester.tap(find.text('curl').last);
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
