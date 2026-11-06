import 'dart:async';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_cubit.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/business_dashboard.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/analytics/application/business_dashboard_metrics.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_workout_reporting.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/admin_dashboard_screens.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_workout_report.dart';
import 'unified_admin_reporting_test.dart' show unifiedResponse;
import 'admin_workout_reporting_test.dart' show workoutResponse;
import 'firebase_admin_reporting_test.dart' as support;
import 'admin_original_reporting_layout_test.dart' as layout;
import 'admin_commerce_report_test.dart' as commerce;
import 'package:gainpath_admin_web/features/analytics/application/admin_commerce_report.dart';
import 'package:gainpath_admin_web/shared/admin_business_copy.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'package:gainpath_admin_web/features/analytics/presentation/admin/sections/commerce_sections.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';

AdminReportingSnapshot businessSnapshot(AdminReportQuery q) {
  final raw = unifiedResponse();
  raw['startAtMillis'] = q.range.start.millisecondsSinceEpoch;
  raw['endAtMillis'] = q.range.end.millisecondsSinceEpoch;
  (raw['daily'] as List).first['date'] = q.range.start
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 10);
  return parseAdminOperationalReport(raw, support.reportingScope, q);
}

AdminWorkoutReport businessWorkouts(AdminReportQuery q) {
  final raw = workoutResponse();
  raw['startAtMillis'] = q.range.start.millisecondsSinceEpoch;
  raw['endAtMillis'] = q.range.end.millisecondsSinceEpoch;
  final date = q.range.start
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 10);
  (raw['daily'] as List).first['date'] = date;
  for (final f in raw['forms'] as List) {
    for (final day in f['daily'] as List) {
      day['date'] = date;
    }
  }
  return parseAdminWorkoutReport(raw, support.reportingScope, q);
}

class BusinessGateway
    implements
        OperationalAdminReportingGateway,
        UnifiedAdminReportingPresentation,
        AdminWorkoutReportingGateway {
  @override
  bool get unified => true;
  final queries = <AdminReportQuery>[];
  Completer<AdminWorkoutReport>? pending;
  bool failWorkouts = false, alternateForms = false;
  @override
  Future<AdminReportingSnapshot> load(AdminReportQuery q) async {
    queries.add(q);
    return businessSnapshot(q);
  }

  @override
  Future<AdminWorkoutReport> loadWorkouts(AdminReportQuery q) async {
    if (failWorkouts) throw StateError('offline');
    final r = pending == null ? businessWorkouts(q) : await pending!.future;
    if (!alternateForms) return r;
    final f = r.forms.first;
    return AdminWorkoutReport(
        query: r.query,
        capturedAt: r.capturedAt,
        scanStartedAt: r.scanStartedAt,
        totals: r.totals,
        coverage: r.coverage,
        daily: r.daily,
        exercises: r.exercises,
        forms: [
          f,
          WorkoutFormGroup(
              exerciseId: f.exerciseId,
              scoringVersion: 'other-rules-v2',
              detectorId: f.detectorId,
              detectorVersion: f.detectorVersion,
              cameraView: f.cameraView,
              armMode: 'other-mode',
              scoredSessions: f.scoredSessions,
              scoreSum: f.scoreSum,
              daily: f.daily)
        ]);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUpAll(loadDemoRenderFonts);
  testWidgets('summary has one loader plus the independent workout loader',
      (t) async {
    final g = BusinessGateway()..pending = Completer<AdminWorkoutReport>();
    await t.pumpWidget(layout.originalLayoutApp(
        Scaffold(body: BusinessDashboard(
            state: AdminReportingState(
                query: support.reportingQuery, isLoading: true),
            range: 'Today',
            ranges: const ['Today'],
            onRange: (_) {},
            onRefresh: () {})),
        g));
    await t.pump();
    expect(find.byWidgetPredicate((w) => w is LinearProgressIndicator && w.value == null), findsNWidgets(2));
    await t.pumpWidget(const SizedBox());
    g.pending!.complete(businessWorkouts(support.reportingQuery));
  });
  testWidgets(
      'unified Revenue keeps detailed financial filters and scoped export',
      (t) async {
    final raw = unifiedResponse();
    raw['commerce'] = commerce.commerce();
    final s = parseAdminOperationalReport(
        raw, support.reportingScope, support.reportingQuery);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: RevenueSection(
                    anchorKey: GlobalKey(), live: true, snapshot: s)))));
    await t.pumpAndSettle();
    expect(find.text('Financial details'), findsOneWidget);
    await t.ensureVisible(find.text('Financial details'));
    await t.tap(find.text('Financial details'));
    await t.pumpAndSettle();
    expect(find.text('Membership plan'), findsOneWidget);
    expect(find.text('Purchases'), findsWidgets);
    expect(find.text('Confirmed receipts'), findsWidgets);
  });
  testWidgets('workout failure is retryable after a successful main report',
      (t) async {
    final g = BusinessGateway()..failWorkouts = true;
    await t.pumpWidget(
        layout.originalLayoutApp(const AdminDashboardScreen(live: true), g));
    await t.pumpAndSettle();
    expect(
        find.textContaining('Workout activity is unavailable'), findsOneWidget);
    expect(find.byTooltip('Refresh dashboard'), findsOneWidget);
    g.failWorkouts = false;
    await t.tap(find.byTooltip('Refresh dashboard'));
    await t.pumpAndSettle();
    expect(
        find.textContaining('Workout activity is unavailable'), findsNothing);
    expect(g.queries, hasLength(2));
  });
  testWidgets('same-exercise form scores retain incompatible group identities',
      (t) async {
    await t.pumpWidget(layout.originalLayoutApp(
        const AdminDashboardScreen(live: true),
        BusinessGateway()..alternateForms = true));
    await t.pumpAndSettle();
    expect(find.textContaining('other-rules-v2'), findsOneWidget);
    expect(find.textContaining('other-mode'), findsOneWidget);
  });
  testWidgets('business Dashboard renders its actual charts for visual review',
      (t) async {
    t.view.physicalSize = const Size(1440, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final reset = await installFypOfflineFonts();
    addTearDown(reset);
    const key = ValueKey('business-render');
    await t.pumpWidget(RepaintBoundary(
        key: key,
        child: fypOfflineChartFonts(layout.originalLayoutApp(
            Theme(
                data: AppTheme.build(),
                child: const ColoredBox(
                    color: AppColors.surfaceAlt,
                    child: AdminDashboardScreen(live: true))),
            BusinessGateway()))));
    await t.pumpAndSettle();
    await t.runAsync(() async {
      final image = await t
          .renderObject<RenderRepaintBoundary>(find.byKey(key))
          .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
              '../../build/admin-business-dashboard-20261105/fixture-dashboard.png')
          .writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    expect(t.takeException(), isNull);
  });
  test('current plan totals exclude expired and unknown active subscriptions',
      () {
    final raw = unifiedResponse();
    raw['commerce'] = commerce.commerce();
    final parsed = parseAdminOperationalReport(
        raw, support.reportingScope, support.reportingQuery);
    final s = AdminReportingSnapshot(
        query: parsed.query,
        capturedAt: parsed.capturedAt,
        unified: parsed.unified,
        operations: parsed.operations,
        totalRevenue: parsed.totalRevenue,
        activeMembersCount: parsed.activeMembersCount,
        totalBookingsCount: parsed.totalBookingsCount,
        activeCoachesCount: parsed.activeCoachesCount,
        commerce: AdminCommerceReport.parse(
            commerce.commerce(), support.reportingQuery));
    final m = BusinessDashboardMetrics(s, null);
    expect(m.activeSubscriptions, 19);
    expect(m.tiers, {'free': 7, 'basic': 7, 'premium': 6, 'unknown': 1});
    expect(m.completed, 16);
    expect(m.cancelled, 8);
    expect(m.workoutSessions, isNull);
  });
  test('display terminology never activates enrollment or settlement', () {
    expect(
        adminBusinessDetail(
            'illustrative assignment, not an actual enrollment'),
        contains('has not been activated'));
    expect(adminBusinessDetail('simulation only; no entitlement'),
        'No active entitlement');
    expect(adminBusinessDetail('Demo Learner 01'), 'Demo Learner 01');
  });
  test(
      'business totals combine eligible values without changing underlying receipt amounts',
      () {
    final s = businessSnapshot(support.reportingQuery),
        m = BusinessDashboardMetrics(
            s, businessWorkouts(support.reportingQuery));
    expect(m.revenueMinor, 23900);
    expect(m.membershipMinor, 14900);
    expect(m.coachingMinor, 9000);
    expect(m.bookings, 26);
    expect(m.workoutSessions, 2);
    expect(m.activeSubscriptions, isNull);
    expect(m.monthly.fold<int>(0, (n, r) => n + r.minor), 23900);
    expect(s.totalRevenue!.minorUnits, 13900);
    expect(m.csv().expand((r) => r).join(' '), contains('not settled cash'));
  });
  test('workout values from another range are never reused', () {
    final q = AdminReportQuery(
        range: DateTimeRange(
            start: DateTime.utc(2026, 1), end: DateTime.utc(2026, 2)));
    expect(
        () => BusinessDashboardMetrics(
            businessSnapshot(support.reportingQuery), businessWorkouts(q)),
        throwsFormatException);
  });
  testWidgets(
      'ordinary unified Dashboard uses one business presentation and dynamic metrics',
      (t) async {
    final g = BusinessGateway();
    t.view.physicalSize = const Size(1440, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
        layout.originalLayoutApp(const AdminDashboardScreen(live: true), g));
    await t.pumpAndSettle();
    expect(find.text('Dashboard Overview'), findsOneWidget);
    expect(find.text('Revenue Overview'), findsOneWidget);
    expect(find.text('MYR 239.00'), findsWidgets);
    expect(find.text('Active Members'), findsOneWidget);
    expect(find.text('Workout Sessions'), findsOneWidget);
    final labels = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join(' ');
    for (final term in [
      'FYP',
      'Sandbox',
      'Simulation',
      'Existing +',
      'Sample'
    ]) {
      expect(labels, isNot(contains(term)));
    }
    expect(g.queries, hasLength(1));
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'narrow Dashboard and larger text retain sections without overflow',
      (t) async {
    t.view.physicalSize = const Size(430, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(layout.originalLayoutApp(
        MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: const AdminDashboardScreen(live: true)),
        BusinessGateway()));
    await t.pumpAndSettle();
    expect(find.text('Revenue Overview'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
