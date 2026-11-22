import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../test_support/fyp_render_support.dart';
import 'admin_original_reporting_layout_test.dart' as layout;
import 'business_dashboard_test.dart' show BusinessGateway;
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

Map<String, dynamic> _mockBranchReport(Map<String, Object?> input) {
  final action = input['action'];
  if (action == 'list') {
    return {
      'records': [
        {'branchId': 'main', 'displayName': 'Main Branch', 'status': 'active'},
        {'branchId': 'gainpath-2', 'displayName': 'GainPath 2', 'status': 'active'},
        {'branchId': 'old-gym', 'displayName': 'Old Gym', 'status': 'inactive'},
      ],
    };
  }

  if (action == 'branchReport') {
    final scope = input['scope'];
    final branchId = input['branchId'];

    if (scope == 'all' || scope == null && branchId == null) {
      return {
        'branchName': 'All Branches',
        'activeBranches': 2,
        'homeMembers': 48,
        'assignedCoaches': 3,
        'bookingsCreated': 28,
        'completedSessions': 22,
        'cancelledSessions': 4,
        'coachingMinor': 240000,
        'actualCoachingMinor': null,
        'gymVisits': 185,
        'uniqueVisitors': 42,
        'repeatVisitors': 29,
        'peakHours': [17, 18, 19],
        'branches': [
          {
            'branchId': 'main',
            'branchName': 'Main Branch',
            'status': 'active',
            'homeMembers': 32,
            'assignedCoaches': 3,
            'gymVisits': 120,
            'bookingsCreated': 18,
            'completedSessions': 15,
            'coachingMinor': 160000,
          },
          {
            'branchId': 'gainpath-2',
            'branchName': 'GainPath 2',
            'status': 'active',
            'homeMembers': 16,
            'assignedCoaches': 1,
            'gymVisits': 65,
            'bookingsCreated': 10,
            'completedSessions': 7,
            'coachingMinor': 80000,
          },
        ],
        'daily': [
          {'date': '2026-11-14', 'visits': 25, 'bookings': 4, 'completed': 3, 'cancelled': 0, 'coachingMinor': 32000},
          {'date': '2026-11-15', 'visits': 30, 'bookings': 5, 'completed': 4, 'cancelled': 1, 'coachingMinor': 40000},
          {'date': '2026-11-16', 'visits': 28, 'bookings': 3, 'completed': 3, 'cancelled': 0, 'coachingMinor': 28000},
          {'date': '2026-11-17', 'visits': 34, 'bookings': 6, 'completed': 5, 'cancelled': 1, 'coachingMinor': 52000},
          {'date': '2026-11-18', 'visits': 32, 'bookings': 4, 'completed': 3, 'cancelled': 1, 'coachingMinor': 38000},
          {'date': '2026-11-19', 'visits': 36, 'bookings': 6, 'completed': 4, 'cancelled': 1, 'coachingMinor': 50000},
        ],
      };
    }

    if (branchId == 'main') {
      return {
        'branchName': 'Main Branch',
        'activeBranches': 1,
        'homeMembers': 32,
        'assignedCoaches': 3,
        'equipmentUnits': 45,
        'usableUnits': 42,
        'maintenanceUnits': 3,
        'bookingsCreated': 18,
        'completedSessions': 15,
        'cancelledSessions': 2,
        'coachingMinor': 160000,
        'actualCoachingMinor': null,
        'gymVisits': 120,
        'uniqueVisitors': 28,
        'repeatVisitors': 20,
        'peakHours': [18, 19],
        'daily': [
          {'date': '2026-11-14', 'visits': 18, 'bookings': 3, 'completed': 2, 'cancelled': 0, 'coachingMinor': 22000},
          {'date': '2026-11-15', 'visits': 22, 'bookings': 3, 'completed': 3, 'cancelled': 0, 'coachingMinor': 28000},
          {'date': '2026-11-16', 'visits': 19, 'bookings': 2, 'completed': 2, 'cancelled': 0, 'coachingMinor': 18000},
          {'date': '2026-11-17', 'visits': 23, 'bookings': 4, 'completed': 3, 'cancelled': 1, 'coachingMinor': 36000},
          {'date': '2026-11-18', 'visits': 20, 'bookings': 3, 'completed': 2, 'cancelled': 1, 'coachingMinor': 26000},
          {'date': '2026-11-19', 'visits': 24, 'bookings': 3, 'completed': 3, 'cancelled': 0, 'coachingMinor': 30000},
        ],
      };
    }
  }

  return {};
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUpAll(loadDemoRenderFonts);

  testWidgets(
      'Render Multi-Branch Performance Dashboard at 1440 and capture verification PNGs',
      (tester) async {
    final reset = await installFypOfflineFonts();
    addTearDown(reset);
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final outDir = Directory('../../build/analytics-20261121');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final gateway = BusinessGateway();
    const surfaceKey = ValueKey('branch-analytics-capture-surface');

    Future<void> saveScreenshot(String filename) async {
      await tester.pump();
      await tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(surfaceKey))
            .toImage();
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        await File('${outDir.path}/$filename').writeAsBytes(bytes);
        image.dispose();
      });
    }

    // 1. Render Branch Analytics with All Branches scope
    await tester.pumpWidget(
      RepaintBoundary(
        key: surfaceKey,
        child: fypOfflineChartFonts(
          layout.originalLayoutApp(
            Theme(
              data: AppTheme.build(),
              child: ColoredBox(
                color: AppColors.surfaceAlt,
                child: ReportsScreen(
                  category: ReportsCategory.branches,
                  live: true,
                  branchRequest: (input) async => _mockBranchReport(input),
                ),
              ),
            ),
            gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Header and Overview section
    expect(find.text('Branch Analytics'), findsOneWidget);
    expect(find.text('Export branch CSV'), findsOneWidget);
    expect(find.text('Branch Overview'), findsOneWidget);
    expect(find.text('Active branches · current'), findsOneWidget);
    expect(find.text('Home branch members · current'), findsOneWidget);
    expect(find.text('Assigned coaches · current'), findsOneWidget);

    // Verify values from mock report
    expect(find.text('48'), findsOneWidget); // Home members
    expect(find.text('3'), findsAtLeastNWidgets(1)); // Coaches

    // Capture Overview screenshot
    await saveScreenshot('branch_analytics_overview_1440.png');

    // Verify Comparison section
    expect(find.text('Location Performance & Benchmarks'), findsOneWidget);
    expect(find.text('Home Branch Members'), findsOneWidget);
    expect(find.text('Recorded Gym Visits'), findsOneWidget);
    expect(find.text('Coach Bookings'), findsOneWidget);
    expect(find.text('Confirmed Sandbox Receipts (RM)'), findsOneWidget);

    // Capture Comparison screenshot
    await saveScreenshot('branch_analytics_comparison_1440.png');

    // Scroll down to Booking Activity
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Booking Activity'),
      250,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking Activity'), findsOneWidget);
    expect(find.text('Bookings created'), findsOneWidget);
    expect(find.text('Completed sessions · appointment date'), findsOneWidget);
    expect(find.text('Cancelled sessions · appointment date'), findsOneWidget);

    // Capture Booking Activity screenshot
    await saveScreenshot('branch_analytics_booking_activity_1440.png');

    // Scroll to Gym Visit Insights
    await tester.scrollUntilVisible(
      find.text('Gym Visit Insights'),
      250,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Gym Visit Insights'), findsOneWidget);
    expect(find.text('Recorded gym visits'), findsWidgets);
    expect(find.text('Unique visiting members'), findsOneWidget);
    expect(find.text('Members with multiple visits'), findsOneWidget);
    expect(find.text('Peak recorded hours · MYT'), findsOneWidget);

    // Capture Gym Visits screenshot
    await saveScreenshot('branch_analytics_gym_visits_1440.png');

    // Scroll to Financial Coverage
    await tester.scrollUntilVisible(
      find.text('Financial Coverage'),
      250,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Financial Coverage'), findsOneWidget);
    expect(find.text('Confirmed sandbox coaching receipts · RM'), findsOneWidget);
    expect(find.text('Actual coaching revenue · RM'), findsOneWidget);
    expect(find.text('RM 2400.00'), findsOneWidget);
    expect(find.text('Unavailable'), findsAtLeastNWidgets(1));
    expect(find.text('Membership revenue remains in the organization-wide report.'), findsOneWidget);

    // Capture Financial screenshot
    await saveScreenshot('branch_analytics_financial_1440.png');

    // Scroll to Branch Comparison Table
    await tester.scrollUntilVisible(
      find.text('Branch Comparison Table'),
      250,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('Branch Comparison Table'), findsOneWidget);
    expect(find.text('Main Branch'), findsAtLeastNWidgets(1));
    expect(find.text('GainPath 2'), findsAtLeastNWidgets(1));
    expect(find.text('View details'), findsAtLeastNWidgets(1));

    // Capture Table screenshot
    await saveScreenshot('branch_analytics_table_1440.png');
  });

  testWidgets(
      'Render Single Branch view with equipment units and daily activity trends',
      (tester) async {
    final reset = await installFypOfflineFonts();
    addTearDown(reset);
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final outDir = Directory('../../build/analytics-20261121');
    final gateway = BusinessGateway();
    const surfaceKey = ValueKey('branch-single-capture-surface');

    await tester.pumpWidget(
      RepaintBoundary(
        key: surfaceKey,
        child: fypOfflineChartFonts(
          layout.originalLayoutApp(
            Theme(
              data: AppTheme.build(),
              child: ColoredBox(
                color: AppColors.surfaceAlt,
                child: ReportsScreen(
                  category: ReportsCategory.branches,
                  live: true,
                  initialBranchId: 'main',
                  branchRequest: (input) async => _mockBranchReport(input),
                ),
              ),
            ),
            gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify single-branch metrics including equipment inventory
    expect(find.text('Branch Overview'), findsOneWidget);
    expect(find.text('Equipment units · current'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('Usable units · current'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Maintenance units · current'), findsOneWidget);
    expect(find.text('3'), findsWidgets);

    // Verify daily activity trends
    expect(find.text('Daily Activity Trends'), findsOneWidget);
    expect(find.text('Daily Activity Log'), findsOneWidget);

    // Save single branch verification screenshot
    await tester.pump();
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(surfaceKey))
          .toImage();
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await File('${outDir.path}/branch_analytics_single_branch_1440.png')
          .writeAsBytes(bytes);
      image.dispose();
    });
  });
}
