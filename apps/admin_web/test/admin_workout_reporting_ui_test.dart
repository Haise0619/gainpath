import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_workout_reporting.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_workout_analytics.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_dashboard_screens.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_workout_report.dart';
import 'admin_original_reporting_layout_test.dart' as original;
import 'firebase_admin_reporting_test.dart' as support;
import 'admin_workout_reporting_test.dart' as fixture;

class WorkoutUiGateway extends original.OriginalLayoutGateway
    implements AdminWorkoutReportingGateway {
  int calls = 0;
  Completer<AdminWorkoutReport>? pendingWorkouts;
  bool unavailable = false;
  @override
  Future<AdminWorkoutReport> loadWorkouts(q) async {
    calls++;
    if (pendingWorkouts != null) return pendingWorkouts!.future;
    if (unavailable) {
      throw const AdminWorkoutReportException(
          'Workout analytics is awaiting server activation.');
    }
    final raw = fixture.workoutResponse(),
        date = q.range.start
            .toUtc()
            .add(const Duration(hours: 8))
            .toIso8601String()
            .substring(0, 10);
    raw['startAtMillis'] = q.range.start.millisecondsSinceEpoch;
    raw['endAtMillis'] = q.range.end.millisecondsSinceEpoch;
    ((raw['daily'] as List).first as Map)['date'] = date;
    ((((raw['forms'] as List).first as Map)['daily'] as List).first
        as Map)['date'] = date;
    raw['capturedAtMillis'] = DateTime.now().millisecondsSinceEpoch;
    raw['sourceReadStartedAtMillis'] = DateTime.now()
        .subtract(const Duration(seconds: 1))
        .millisecondsSinceEpoch;
    return parseAdminWorkoutReport(raw, support.reportingScope, q);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'original dashboard adds compact backup workout metrics without replacing its layout',
      (t) async {
    final g = WorkoutUiGateway();
    await t.pumpWidget(
        original.originalLayoutApp(const AdminDashboardScreen(live: true), g));
    await t.pumpAndSettle();
    expect(find.text('GainPath Console'), findsOneWidget);
    expect(find.text('Workout activity'), findsOneWidget);
    expect(find.text('Saved camera sessions'), findsOneWidget);
    expect(find.textContaining('backup records'), findsOneWidget);
    expect(g.calls, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'reports retain original header and section anchors, provide workout details and refresh both sources',
      (t) async {
    t.view.physicalSize = const Size(1200, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final g = WorkoutUiGateway();
    await t.pumpWidget(
        original.originalLayoutApp(const ReportsScreen(live: true), g));
    await t.pumpAndSettle();
    expect(find.text('Reports & analytics'), findsOneWidget);
    expect(find.text('Workouts'), findsOneWidget);
    await t.tap(find.byTooltip('Refresh reports'));
    await t.pumpAndSettle();
    expect(g.calls, 4);
    await t.tap(find.text('Workouts'));
    await t.pumpAndSettle();
    expect(find.text('Most-used exercises'), findsOneWidget);
    expect(find.text('Manual sets'), findsOneWidget);
    expect(find.text('Estimated form by compatible version'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'unactivated workout endpoint leaves existing receipt reports available',
      (t) async {
    final g = WorkoutUiGateway()..unavailable = true;
    await t.pumpWidget(
        original.originalLayoutApp(const ReportsScreen(live: true), g));
    await t.pumpAndSettle();
    expect(find.text('MYR 139.00'), findsWidgets);
    expect(find.text('Workout analytics is awaiting server activation.'),
        findsNWidgets(2));
    expect(find.text('Retry workout analytics'), findsOneWidget);
  });
  testWidgets(
      'small-width large text panel supports chart switch and retry without stale metrics',
      (t) async {
    t.view.physicalSize = const Size(430, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final g = WorkoutUiGateway();
    Widget app() => original.originalLayoutApp(
        MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child:
                        AdminWorkoutAnalytics(query: support.reportingQuery)))),
        g);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Weekly'));
    await t.tap(find.text('Weekly'));
    await t.pumpAndSettle();
    expect(find.textContaining('Weeks start Monday'), findsOneWidget);
    expect(t.takeException(), isNull);
    g.pendingWorkouts = Completer();
    await t.ensureVisible(find.byTooltip('Refresh workout analytics'));
    await t.tap(find.byTooltip('Refresh workout analytics'));
    await t.pump();
    expect(find.text('Most-used exercises'), findsOneWidget);
    g.pendingWorkouts!.completeError(StateError('offline'));
    await t.pumpAndSettle();
    expect(find.text('Retry workout analytics'), findsOneWidget);
    expect(find.text('Saved camera sessions'), findsNothing);
    g.pendingWorkouts = null;
    await t.tap(find.text('Retry workout analytics'));
    await t.pumpAndSettle();
    expect(find.text('Saved camera sessions'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
