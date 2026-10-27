import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/recommendation.dart';
import 'package:gainpath_admin_web/app/di/admin_presentation_dependencies.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_operational_metrics.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_dashboard_screens.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_operational_report.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/sections/commerce_sections.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'firebase_admin_reporting_test.dart' as support;

class OriginalLayoutGateway implements OperationalAdminReportingGateway {
  bool dense = false;
  AdminReportQuery? query;
  Completer<AdminReportingSnapshot>? pending;
  @override
  Future<AdminReportingSnapshot> load(AdminReportQuery q) async {
    query = q;
    if (pending != null) return pending!.future;
    final raw = support.reportingResponse();
    raw['startAtMillis'] = q.range.start.millisecondsSinceEpoch;
    raw['endAtMillis'] = q.range.end.millisecondsSinceEpoch;
    (raw['daily'] as List).first['date'] = q.range.start
        .toUtc()
        .add(adminReportZone)
        .toIso8601String()
        .substring(0, 10);
    if (dense) {
      final length = q.range.end.difference(q.range.start).inDays;
      raw['daily'] = List.generate(
          length,
          (i) => {
                'date': q.range.start
                    .add(Duration(days: i))
                    .toUtc()
                    .add(adminReportZone)
                    .toIso8601String()
                    .substring(0, 10),
                'bookingsCreated': 1,
                'scheduledStarts': i == 0 ? 1 : 0,
                'receiptsMinor': i == 0 ? 13900 : 0,
                'membershipMinor': i == 0 ? 8900 : 0,
                'coachingMinor': i == 0 ? 5000 : 0
              });
      raw['bookings'] = <String, dynamic>{
        'created': length,
        'scheduledStarts': 1,
        'statuses': {
          'pending_hold': 0,
          'confirmed': length,
          'cancelled': 0,
          'expired': 0,
          'completed': 0,
          'refunded': 0
        }
      };
      raw['sourceCounts'] = <String, dynamic>{
        'members': 4,
        'bookings': length,
        'transactions': 4
      };
    }
    return parseAdminOperationalReport(raw, support.reportingScope, q);
  }
}

Widget originalLayoutApp(Widget screen, AdminReportingGateway gateway) {
  final deps = AdminPresentationDependencies.fromScope(
      scope: support.reportingScope, isCurrent: () => true);
  return MultiRepositoryProvider(providers: [
    RepositoryProvider<AdminReportingGateway>.value(value: gateway),
    RepositoryProvider<AnalyticsRepository>.value(value: deps.analytics),
    RepositoryProvider<BookingRepository>.value(value: deps.booking),
    RepositoryProvider<CoachRepository>.value(value: deps.coach),
    RepositoryProvider<AvailabilityRepository>.value(value: deps.availability),
    RepositoryProvider<UserAccountRepository>.value(value: deps.userAccount),
    RepositoryProvider<RecommendationRepository>.value(
        value: deps.recommendation),
  ], child: MaterialApp(home: screen));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'dense month fits original two-column dashboard without label overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1150, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = OriginalLayoutGateway()..dense = true;
    await tester.pumpWidget(
        originalLayoutApp(const AdminDashboardScreen(live: true), gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('This month').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('BOOKINGS CREATED BY DAY'), findsOneWidget);
  });
  Future<void> size(WidgetTester tester, {double width = 1600}) async {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets(
      'real Dashboard reuses original header columns actions and exact receipts',
      (tester) async {
    await size(tester);
    final gateway = OriginalLayoutGateway();
    await tester.pumpWidget(
        originalLayoutApp(const AdminDashboardScreen(live: true), gateway));
    await tester.pumpAndSettle();
    expect(find.byType(AdminOperationalReport), findsNothing);
    expect(find.text('GainPath Console'), findsOneWidget);
    expect(find.text('NEEDS ATTENTION'), findsOneWidget);
    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    expect(find.text('MYR 139.00'), findsWidgets);
    expect(find.text('BOOKINGS CREATED BY DAY'), findsOneWidget);
    expect(find.text('Confirmed Sandbox receipts'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Reports keeps header toolbar overview and section shells with data',
      (tester) async {
    await size(tester);
    final gateway = OriginalLayoutGateway();
    await tester.pumpWidget(
        originalLayoutApp(const ReportsScreen(live: true), gateway));
    await tester.pumpAndSettle();
    expect(find.byType(AdminOperationalReport), findsNothing);
    expect(find.text('Reports & analytics'), findsOneWidget);
    expect(find.text('Overview'), findsWidgets);
    expect(find.byType(RevenueSection), findsOneWidget);
    expect(find.text('All branches'), findsOneWidget);
    expect(find.text('MYR 89.00'), findsWidgets);
    expect(find.text('MYR 50.00'), findsWidgets);
    expect(find.text('Download CSV'), findsOneWidget);
    expect(find.text('Custom dates'), findsOneWidget);
    final revenue = tester
        .widgetList<ReportSection>(find.byType(ReportSection))
        .firstWhere((s) => s.exportFilename == 'membership_revenue.csv');
    expect(revenue.exportEnabled, true);
    expect(revenue.exportRows!().expand((r) => r), contains(8900));
    expect(revenue.exportRows!().expand((r) => r),
        contains(gateway.query!.range.start.toUtc().toIso8601String()));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'original filter chips discard old values during request and failure',
      (tester) async {
    await size(tester, width: 900);
    final gateway = OriginalLayoutGateway();
    await tester.pumpWidget(
        originalLayoutApp(const ReportsScreen(live: true), gateway));
    await tester.pumpAndSettle();
    gateway.pending = Completer();
    await tester.tap(find.text('7 days'));
    await tester.pump();
    expect(find.text('MYR 89.00'), findsNothing);
    expect(find.text('MYR 139.00'), findsNothing);
    final q = operationalDateQuery(DateTime.now(), days: 7);
    expect(gateway.query, q);
    gateway.pending!.completeError(StateError('private'));
    await tester.pumpAndSettle();
    expect(find.text('Retry reports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
