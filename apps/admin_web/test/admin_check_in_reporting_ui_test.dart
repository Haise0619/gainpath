import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_check_in_reporting.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_check_in_analytics.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_check_in_report.dart';
import 'admin_original_reporting_layout_test.dart' as original;
import 'admin_workout_reporting_ui_test.dart' as workouts;
import 'admin_check_in_reporting_test.dart' as fixture;
import 'firebase_admin_reporting_test.dart' as support;

class CheckInUiGateway extends workouts.WorkoutUiGateway
    implements AdminCheckInReportingGateway {
  int checkInCalls = 0;
  bool checkInUnavailable = false, emptyCheckIns = false;
  Completer<AdminCheckInReport>? pendingCheckIns;
  @override
  Future<AdminCheckInReport> loadCheckIns(q) async {
    checkInCalls++;
    if (pendingCheckIns != null) return pendingCheckIns!.future;
    if (checkInUnavailable) {
      throw const AdminCheckInReportException(
          'Check-in analytics is awaiting server activation.');
    }
    final raw = fixture.checkInResponse();
    raw['startAtMillis'] = q.range.start.millisecondsSinceEpoch;
    raw['endAtMillis'] = q.range.end.millisecondsSinceEpoch;
    if (emptyCheckIns) {
      raw['totals'] = {'claims': 0, 'claimingMembers': 0, 'pointsAwarded': 0};
      raw['daily'] = [];
      raw['weekly'] = [];
      raw['coverage'] = {
        'membersScanned': 5,
        'activeMembers': 4,
        'profiles': 0,
        'claimsScanned': 0
      };
      raw['streaks'] = {
        'asOfDate': '2026-10-26',
        'current': {'zero': 4, 'oneTwo': 0, 'threeSix': 0, 'sevenPlus': 0},
        'longest': {'zero': 4, 'oneTwo': 0, 'threeSix': 0, 'sevenPlus': 0}
      };
    }
    return parseAdminCheckInReport(raw, support.reportingScope, q);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'original Reports Gamification section binds check-in data and global refresh without replacing the page',
      (t) async {
    t.view.physicalSize = const Size(1200, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final g = CheckInUiGateway();
    await t.pumpWidget(
        original.originalLayoutApp(const ReportsScreen(live: true), g));
    await t.pumpAndSettle();
    expect(find.text('Reports & analytics'), findsOneWidget);
    expect(find.text('Gamification Engagement'), findsOneWidget);
    expect(find.text('Confirmed check-ins'), findsOneWidget);
    expect(find.text('Unique claiming Members'), findsOneWidget);
    await t.tap(find.byTooltip('Refresh reports'));
    await t.pumpAndSettle();
    expect(g.checkInCalls,
        8); // Four sections request updates; Firebase coalesces the shared scan.
    expect(g.calls, 4);
    await t.drag(
        find.byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.horizontal),
        const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(find.text('Gamification').hitTestable(), findsOneWidget);
    await t.tap(find.text('Gamification'));
    await t.pumpAndSettle();
    expect(find.textContaining('Current as of'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'unactivated check-in endpoint leaves existing workout and receipt reports usable',
      (t) async {
    final g = CheckInUiGateway()..checkInUnavailable = true;
    await t.pumpWidget(
        original.originalLayoutApp(const ReportsScreen(live: true), g));
    await t.pumpAndSettle();
    expect(find.text('MYR 139.00'), findsWidgets);
    expect(find.text('Saved camera sessions'), findsOneWidget);
    expect(find.text('Check-in analytics is awaiting server activation.'),
        findsNWidgets(4));
    expect(find.text('Retry check-in analytics'), findsOneWidget);
    expect(find.text('Retry redemption analytics'), findsOneWidget);
  });
  testWidgets(
      'small screen/large text supports weekly view, clears stale metrics and retries',
      (t) async {
    t.view.physicalSize = const Size(430, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final g = CheckInUiGateway();
    await t.pumpWidget(original.originalLayoutApp(
        MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: AdminCheckInAnalytics(
                        query: support.reportingQuery,
                        anchorKey: GlobalKey())))),
        g));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Weekly'));
    await t.tap(find.text('Weekly'));
    await t.pumpAndSettle();
    expect(
        find.textContaining('Weekly claimants are distinct'), findsOneWidget);
    expect(t.takeException(), isNull);
    g.pendingCheckIns = Completer();
    await t.ensureVisible(find.byTooltip('Refresh check-in analytics'));
    await t.tap(find.byTooltip('Refresh check-in analytics'));
    await t.pump();
    expect(find.text('Confirmed check-ins'), findsOneWidget);
    expect(find.byTooltip('Export CSV'), findsOneWidget);
    g.pendingCheckIns!.completeError(StateError('offline'));
    await t.pumpAndSettle();
    expect(find.text('Retry check-in analytics'), findsOneWidget);
    g.pendingCheckIns = null;
    await t.tap(find.text('Retry check-in analytics'));
    await t.pumpAndSettle();
    expect(find.text('Confirmed check-ins'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'empty confirmed history displays a genuine zero with current cohort scope',
      (t) async {
    final g = CheckInUiGateway()..emptyCheckIns = true;
    await t.pumpWidget(original.originalLayoutApp(
        Scaffold(
            body: SingleChildScrollView(
                child: AdminCheckInAnalytics(
                    query: support.reportingQuery, anchorKey: GlobalKey()))),
        g));
    await t.pumpAndSettle();
    expect(find.text('No confirmed check-ins in this date range.'),
        findsOneWidget);
    expect(find.text('Check-in Reward Points'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
