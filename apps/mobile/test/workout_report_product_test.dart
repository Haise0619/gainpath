import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/analytics/domain/member_workout_report.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/workout_report_screen.dart';
import 'support/workout_analytics_fixture.dart';
import 'workout_report_ui_test.dart' show ReportExporterFake;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
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
    expect(find.text('1m 30s'), findsWidgets);
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
    expect(text, contains('VIDEO TIMED'));
    expect(text, contains('90'));
    expect(text, contains('Attempt-weighted'));
    expect(lines.indexOf('TECHNICAL APPENDIX'),
        greaterThan(lines.indexOf('VIDEO TIMED')));
  });
}
