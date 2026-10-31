import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'firebase_admin_reporting_test.dart' as support;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_cubit.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_dashboard_screens.dart';
import 'admin_original_reporting_layout_test.dart' as fixture;

class GuardedGateway
    implements AdminReportingGateway, AdminReportingSessionGuard {
  bool current = true;
  final requests = <Completer<AdminReportingSnapshot>>[];
  @override
  bool get canRetainSnapshot => current;
  @override
  Future<AdminReportingSnapshot> load(AdminReportQuery q) {
    final c = Completer<AdminReportingSnapshot>();
    requests.add(c);
    return c.future;
  }
}

void main() {
  test(
      'same-query refresh retains snapshot; changed query and account clear it',
      () async {
    final g = GuardedGateway();
    final q = AdminReportQuery(
        range: DateTimeRange(
            start: DateTime.utc(2026, 10, 1), end: DateTime.utc(2026, 10, 2)));
    final c = AdminReportingCubit(gateway: g, initialQuery: q);
    final first = c.load();
    final snapshot = AdminReportingSnapshot(
        query: q,
        capturedAt: DateTime.utc(2026, 10, 2),
        isAvailable: true,
        activeMembersCount: 2);
    g.requests.last.complete(snapshot);
    await first;
    final refresh = c.load();
    expect(c.state.snapshot, same(snapshot));
    expect(c.state.isLoading, true);
    g.requests.last.completeError(
        const AdminReportingException('Temporarily unavailable'));
    await refresh;
    expect(c.state.snapshot, same(snapshot));
    expect(c.state.errorMessage, 'Temporarily unavailable');
    final newQ = AdminReportQuery(
        range: DateTimeRange(
            start: DateTime.utc(2026, 9, 1), end: DateTime.utc(2026, 9, 2)));
    final next = c.load(newQ);
    expect(c.state.snapshot, isNull);
    g.requests.last.complete(AdminReportingSnapshot(
        query: newQ, capturedAt: DateTime.utc(2026, 10, 2), isAvailable: true));
    await next;
    final drift = c.load();
    g.current = false;
    g.requests.last.completeError(StateError('private'));
    await drift;
    expect(c.state.snapshot, isNull);
    expect(c.state.errorMessage, isNot(contains('private')));
    await c.close();
  });
  test('revoked access produces safe invalidating error', () async {
    final g = FirebaseAdminReportingGateway(
        scope: support.reportingScope,
        isCurrent: () => true,
        currentUid: () => support.reportingScope.userId,
        invoke: (_) async => throw FirebaseFunctionsException(
            code: 'permission-denied', message: 'private source detail'));
    await expectLater(
        g.load(support.reportingQuery),
        throwsA(isA<AdminReportingException>()
            .having((e) => e.invalidatesSnapshot, 'invalidates', true)
            .having(
                (e) => e.message, 'safe message', isNot(contains('private')))));
  });
  testWidgets(
      'Dashboard actions invoke destination callbacks and replace accuracy KPI',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var coaches = 0, vouchers = 0;
    await tester.pumpWidget(fixture.originalLayoutApp(
        AdminDashboardScreen(
            live: true,
            onOpenCoaches: () => coaches++,
            onProcessVoucher: () => vouchers++),
        fixture.OriginalLayoutGateway()));
    await tester.pumpAndSettle();
    expect(find.text('Avg accuracy'), findsNothing);
    await tester.ensureVisible(find.text('Coach verification'));
    await tester.tap(find.text('Coach verification'));
    expect(coaches, 1);
    await tester.ensureVisible(find.text('Process a voucher'));
    await tester.tap(find.text('Process a voucher'));
    expect(vouchers, 1);
  });
  testWidgets('section CSV contains selected booking or receipt data only', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = fixture.OriginalLayoutGateway();
    await tester.pumpWidget(fixture.originalLayoutApp(const ReportsScreen(live:true), gateway));
    await tester.pumpAndSettle();
    final sections = tester.widgetList<ReportSection>(find.byType(ReportSection));
    final bookings = sections.firstWhere((s)=>s.exportFilename=='booking_activity.csv').exportRows!();
    final receipts = sections.firstWhere((s)=>s.exportFilename=='membership_revenue.csv').exportRows!();
    expect(bookings.expand((r)=>r),contains(gateway.query!.range.start.toUtc().toIso8601String()));
    expect(bookings.expand((r)=>r),isNot(contains(8900)));
    expect(receipts.expand((r)=>r),contains(8900));
    expect(receipts.expand((r)=>r),isNot(contains('Current active Members')));
    expect(find.text('Export overview CSV'),findsOneWidget);
  });

}
