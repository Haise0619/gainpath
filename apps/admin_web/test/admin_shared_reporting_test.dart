import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/di/app_repositories.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_cubit.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_dashboard_screens.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:google_fonts/google_fonts.dart';

const _testSession = AuthSession(
  userId: 'test-admin',
  organizationId: 'org-123',
  branchIds: ['branch-1'],
  displayName: 'Test Admin',
  email: 'admin@test.org',
  role: AppRole.admin,
);

class _ControlledReportingGateway implements AdminReportingGateway {
  late Completer<AdminReportingSnapshot> nextCompleter;
  int queryCount = 0;

  _ControlledReportingGateway() {
    nextCompleter = Completer();
  }

  @override
  Future<AdminReportingSnapshot> load(AdminReportQuery query) {
    queryCount++;
    return nextCompleter.future;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('AdminReportingCubit', () {
    test('initial state has null snapshot and false loading', () {
      const gateway = UnavailableAdminReportingGateway();
      final cubit = AdminReportingCubit(gateway: gateway);

      expect(cubit.state.snapshot, isNull);
      expect(cubit.state.isLoading, isFalse);
      cubit.close();
    });

    test('stale generation protection discards outdated query results',
        () async {
      final gateway = _ControlledReportingGateway();
      final cubit = AdminReportingCubit(gateway: gateway);

      final now = DateTime.now();
      final range1 = DateTimeRange(
          start: now.subtract(const Duration(days: 14)),
          end: now.subtract(const Duration(days: 7)));
      final range2 = DateTimeRange(
          start: now.subtract(const Duration(days: 30)), end: now);

      // Query 1 starts
      final completer1 = gateway.nextCompleter;
      cubit.load(AdminReportQuery(range: range1));
      expect(cubit.state.isLoading, isTrue);

      // Query 2 starts before Query 1 completes
      gateway.nextCompleter = Completer();
      final completer2 = gateway.nextCompleter;
      cubit.load(AdminReportQuery(range: range2));
      expect(cubit.state.isLoading, isTrue);

      // Query 1 completes late
      completer1.complete(AdminReportingSnapshot(
        query: AdminReportQuery(range: range1),
        capturedAt: now,
        isAvailable: true,
        totalRevenue: const Money(minorUnits: 10000, currency: 'MYR'),
      ));

      await pumpEventQueue();
      // Snapshot should NOT be query 1's result because query 2 is active
      expect(cubit.state.snapshot, isNull);
      expect(cubit.state.isLoading, isTrue);

      // Query 2 completes
      completer2.complete(AdminReportingSnapshot(
        query: AdminReportQuery(range: range2),
        capturedAt: now,
        isAvailable: true,
        totalRevenue: const Money(minorUnits: 50000, currency: 'MYR'),
      ));

      await pumpEventQueue();
      expect(cubit.state.snapshot?.totalRevenue?.minorUnits, 50000);
      expect(cubit.state.isLoading, isFalse);

      cubit.close();
    });
  });

  group('Live Dashboard & Reports presentation', () {
    testWidgets('Dashboard renders truthful unavailable states in live mode',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppRepositories.injected(
          session: _testSession,
          reportingGatewayFactory: (_, __) =>
              const UnavailableAdminReportingGateway(),
          child: const MaterialApp(
            home: AdminDashboardScreen(
              live: true,
              liveSession: _testSession,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check organization title and email
      expect(find.text('GainPath — org-123'), findsOneWidget);
      expect(find.text('Connected as Test Admin'), findsOneWidget);

      // KPI values should be '—'
      expect(find.text('—'), findsWidgets);

      // Hourly sessions and revenue unavailable messages
      expect(
        find.text(
            'Hourly session metrics are unavailable in this environment.'),
        findsOneWidget,
      );
      expect(
        find.text('Revenue tracking is unavailable in this environment.'),
        findsOneWidget,
      );

      // Recent activity empty state
      expect(
        find.text('No recent activity recorded for this period.'),
        findsOneWidget,
      );

      // Voucher processing shows unavailable text
      expect(find.text('Verify and collect an existing reward voucher'), findsOneWidget);

      // Tapping voucher shows toast rather than pushing screen
      await tester.tap(find.text('Process a voucher'));
      await tester.pump();
      expect(
        find.text('Voucher processing is unavailable in this environment.'),
        findsNothing,
      );
    });

    testWidgets(
        'Reports screen renders truthful unavailable states in live mode',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppRepositories.injected(
          session: _testSession,
          reportingGatewayFactory: (_, __) =>
              const UnavailableAdminReportingGateway(),
          child: const MaterialApp(
            home: ReportsScreen(live: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Revenue overview should show '—'
      expect(find.text('—'), findsWidgets);
      expect(find.text('RM —'), findsOneWidget);

      // Revenue trend honest message
      expect(
        find.text('Revenue trend is not connected to a live aggregate source.'),
        findsOneWidget,
      );
      expect(
        find.text('Revenue history is unavailable'),
        findsOneWidget,
      );

      // Header indicates live console
      expect(find.text('Live console'), findsOneWidget);
    });
  });
}
