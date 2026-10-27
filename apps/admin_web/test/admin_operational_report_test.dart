import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_cubit.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_operational_metrics.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_operational_report.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_dashboard_screens.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'firebase_admin_reporting_test.dart' as support;
import 'admin_original_reporting_layout_test.dart' show originalLayoutApp;

class OperationalFake implements OperationalAdminReportingGateway {
  AdminReportQuery? query;
  @override
  Future<AdminReportingSnapshot> load(AdminReportQuery q) async {
    query = q;
    final r = support.reportingResponse();
    r['startAtMillis'] = q.range.start.millisecondsSinceEpoch;
    r['endAtMillis'] = q.range.end.millisecondsSinceEpoch;
    final date = q.range.start
        .toUtc()
        .add(adminReportZone)
        .toIso8601String()
        .substring(0, 10);
    (r['daily'] as List).first['date'] = date;
    return parseAdminOperationalReport(r, support.reportingScope, q);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
      'Malaysia calendar presets include whole days independent of browser zone',
      () {
    final q = operationalDateQuery(DateTime.utc(2026, 10, 25, 17), days: 7);
    expect(q.range.start, DateTime.utc(2026, 10, 19, 16));
    expect(q.range.end, DateTime.utc(2026, 10, 26, 16));
  });
  testWidgets(
      'responsive panel uses receipts and current census labels, exports exact selection',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final snap = parseAdminOperationalReport(support.reportingResponse(),
        support.reportingScope, support.reportingQuery);
    List<List<Object?>>? csv;
    AdminReportQuery? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminOperationalReport(
                state: AdminReportingState(query: snap.query, snapshot: snap),
                onQuery: (q) => selected = q,
                onRefresh: () {},
                exportCsv: (rows) => csv = rows))));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed Sandbox receipts'), findsOneWidget);
    expect(find.text('MYR 139.00'), findsOneWidget);
    expect(find.text('Current active Member accounts'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Download CSV'));
    await tester.pump();
    expect(csv!.expand((r) => r), contains(13900));
    await tester.tap(find.text('7 days'));
    await tester.pump();
    expect(selected, isNotNull);
  });
  testWidgets('loading/failure cannot export stale values or fabricate zero',
      (tester) async {
    var retry = 0;
    final state = AdminReportingState(
        query: support.reportingQuery, errorMessage: 'Report unavailable');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminOperationalReport(
                state: state, onQuery: (_) {}, onRefresh: () => retry++))));
    expect(find.text('MYR 0.00'), findsNothing);
    expect(find.text('Download CSV'), findsNothing);
    await tester.tap(find.text('Retry reports'));
    expect(retry, 1);
  });
  testWidgets(
      'both original dashboard and Reports use the connected operational dataset',
      (tester) async {
    for (final screen in [
      const AdminDashboardScreen(live: true),
      const ReportsScreen(live: true)
    ]) {
      final gateway = OperationalFake();
      await tester.pumpWidget(originalLayoutApp(screen, gateway));
      await tester.pumpAndSettle();
      expect(find.byType(AdminOperationalReport), findsNothing);
      expect(find.text('Confirmed Sandbox receipts'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
