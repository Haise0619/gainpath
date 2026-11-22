import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_check_in_reporting.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_check_in_report.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../test_support/fyp_render_support.dart';
import 'admin_check_in_reporting_test.dart' as fixture;
import 'admin_engagement_extension_test.dart' as ext_fixture;
import 'admin_original_reporting_layout_test.dart' as layout;
import 'admin_remaining_analytics_test.dart' as remaining_fixture;
import 'firebase_admin_reporting_test.dart' as support;
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

class EngagementTestGateway extends layout.OriginalLayoutGateway
    implements AdminCheckInReportingGateway {
  @override
  Future<AdminCheckInReport> loadCheckIns(AdminReportQuery q) async {
    try {
      final raw = fixture.checkInResponse();
      raw['startAtMillis'] = q.range.start.millisecondsSinceEpoch;
      raw['endAtMillis'] = q.range.end.millisecondsSinceEpoch;
      final scan = DateTime.utc(2026, 10, 26, 6).millisecondsSinceEpoch;
      raw['sourceReadStartedAtMillis'] = scan;
      raw['capturedAtMillis'] = scan + 1000;
      raw['streaks'] = {
        'asOfDate': DateTime.fromMillisecondsSinceEpoch(scan, isUtc: true)
            .add(const Duration(hours: 8))
            .toIso8601String()
            .substring(0, 10),
        'current': {'zero': 2, 'oneTwo': 1, 'threeSix': 1, 'sevenPlus': 0},
        'longest': {'zero': 2, 'oneTwo': 0, 'threeSix': 1, 'sevenPlus': 1}
      };

      final obs = Map<String, dynamic>.from(remaining_fixture.observations());
      obs['weekly'] = [
        {
          'date': '2026-10-19',
          'checkIns': 2,
          'bookings': 1,
          'games': 0,
          'workoutBackups': 1,
          'uniqueMembers': 2
        }
      ];
      obs['asOfMillis'] = q.range.end.millisecondsSinceEpoch - 1 < scan
          ? q.range.end.millisecondsSinceEpoch - 1
          : scan;
      final span = q.range.end.difference(q.range.start).inMilliseconds;
      final returning = Map<String, dynamic>.from(obs['returning'] as Map);
      final available = q.range.start.millisecondsSinceEpoch >= span &&
          q.range.end.millisecondsSinceEpoch <= scan;
      returning['available'] = available;
      if (!available) {
        returning['ratePercent'] = null;
      }
      obs['returning'] = returning;
      raw['observations'] = obs;

      final ext = Map<String, dynamic>.from(ext_fixture.extensionFixture());
      raw['extensions'] = ext;

      return parseAdminCheckInReport(raw, support.reportingScope, q);
    } catch (e) {
      debugPrint('GATEWAY LOAD CHECK INS ERROR: $e');
      rethrow;
    }
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUpAll(loadDemoRenderFonts);

  testWidgets(
      'Render Engagement Intelligence Dashboard across all workspaces and capture verification PNGs',
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

    final gateway = EngagementTestGateway();
    const surfaceKey = ValueKey('engagement-analytics-capture-surface');

    Future<void> capture(String filename) async {
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
                  category: ReportsCategory.engagement,
                  live: true,
                  now: () => DateTime.utc(2026, 10, 25, 12),
                ),
              ),
            ),
            gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Header & Subtitle
    expect(find.text('Engagement Analytics'), findsOneWidget);
    expect(
        find.text('Recorded member engagement, rewards and activity insights.'),
        findsOneWidget);

    // Verify Tab Bar exists
    expect(find.text('All Workspaces'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Member Activity'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Gamification'), findsOneWidget);

    // 1. Switch to Overview Workspace
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    expect(find.text('Platform Usage Pattern'), findsOneWidget);
    expect(find.text('Current Member cohort'), findsWidgets);
    expect(find.text('Check-in claims'), findsWidgets);
    expect(find.text('Bookings created'), findsWidgets);
    expect(find.text('Recorded game starts'), findsWidgets);
    expect(find.text('Backed-up camera captures'), findsWidgets);
    await capture('engagement_analytics_overview_1440.png');

    // 2. Switch to Member Activity Workspace
    await tester.tap(find.text('Member Activity'));
    await tester.pumpAndSettle();

    expect(
        find.text('Recorded engagement & returning Members'), findsOneWidget);
    expect(find.text('Observed within 7 days'), findsWidgets);
    expect(find.text('No observed activity / unknown'), findsWidgets);
    expect(find.text('Returning Members'), findsOneWidget);
    await capture('engagement_analytics_member_activity_1440.png');

    // 3. Switch to Rewards Workspace
    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();

    expect(find.text('Reward Redemptions'), findsOneWidget);
    expect(find.text('Vouchers issued'), findsWidgets);
    expect(find.text('Vouchers collected'), findsWidgets);
    expect(find.text('Vouchers expired'), findsWidgets);
    expect(find.text('Points spent'), findsWidgets);
    expect(find.text('Status of vouchers issued in range'), findsOneWidget);
    expect(find.text('Most redeemed rewards'), findsOneWidget);
    await capture('engagement_analytics_rewards_1440.png');

    // 4. Switch to Gamification Workspace
    await tester.tap(find.text('Gamification'));
    await tester.pumpAndSettle();

    expect(find.text('Gamification Engagement'), findsOneWidget);
    expect(find.text('Confirmed check-ins'), findsWidgets);
    expect(find.text('Unique claiming Members'), findsWidgets);
    expect(find.text('Check-in Reward Points'), findsWidgets);
    expect(find.text('Recorded mini-game participation'), findsOneWidget);
    expect(find.text('Move & Catch'), findsWidgets);
    expect(find.text('Reach & Tap'), findsWidgets);
    expect(find.text('Confirmed earning sources'), findsOneWidget);
    expect(find.text('Real check-in badge unlocks'), findsOneWidget);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Longest streak'), findsOneWidget);
    await capture('engagement_analytics_gamification_1440.png');
  });
}
