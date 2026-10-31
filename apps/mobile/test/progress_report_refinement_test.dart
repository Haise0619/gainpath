import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/widgets/local_progress_widgets.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/widgets/report_preview_tile.dart';
import 'member_workout_report_test.dart' as support;
import 'routine_history_ui_test.dart' as routines;
import 'package:gainpath_mobile/features/analytics/domain/member_workout_report.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/body_metrics_screen.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_report_screen.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'workout_report_ui_test.dart' show ReportExporterFake;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('history labels require a unique name; opaque identifiers stay readable',
      () {
    final names = reportExerciseNames([routines.attempt()]);
    expect(names['press'], 'Press');
    expect(names['F3b8xIr8ynBDd3gEICKX'], 'Saved exercise');
    expect(
        reportExerciseLabel('bodyweight_squat-side'), 'Bodyweight squat side');
  });
  testWidgets('live weight report omits an empty trend chart', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: BodyMetricsScreen(live: true, weightKg: 62, heightCm: 170)));
    expect(find.text('Weight & BMI'), findsOneWidget);
    expect(find.byType(SfCartesianChart), findsNothing);
    expect(find.textContaining('measurement date unknown'), findsOneWidget);
  });
  testWidgets('combined history opens the exact measured capture',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final record = support.reportRecord('one', support.reportNow);
    String? opened;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutReportScreen(
            scope: support.reportScope,
            source: LocalMemberProgressSnapshot(records: [record]),
            asOf: support.reportNow,
            exporter: ReportExporterFake(),
            isCurrent: () => true,
            onRefresh: () async {},
            onOpenWorkout: (record) => opened = record.sessionId)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Squat'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Squat'));
    expect(opened, 'one');
  });
  testWidgets('record details are collapsed and friendly label remains visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: LocalProgressRecordTile(
                record: support.reportRecord(
                    'private-session-id', support.reportNow),
                utcOffset: Duration.zero))));
    expect(find.text('Squat'), findsOneWidget);
    expect(find.text('private-session-id').hitTestable(), findsNothing);
    await tester.tap(find.text('Measurement details'));
    await tester.pumpAndSettle();
    expect(find.text('private-session-id').hitTestable(), findsOneWidget);
  });
  testWidgets('empty preview omits fake trend and wraps subtitle',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReportPreviewTile(
                icon: Icons.history,
                title: 'History',
                subtitle: 'Measured sessions and saved routines',
                sparkData: const [],
                onTap: () {}))));
    expect(find.text('-'), findsNothing);
    expect(
        tester
            .widget<Text>(find.text('Measured sessions and saved routines'))
            .maxLines,
        isNull);
  });
}
