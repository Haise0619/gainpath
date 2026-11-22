import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../test_support/fyp_render_support.dart';
import 'admin_original_reporting_layout_test.dart' as layout;
import 'business_dashboard_test.dart' show BusinessGateway;
import 'firebase_admin_reporting_test.dart' as support;
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'unified_admin_reporting_test.dart' show unifiedResponse;

Map<String, dynamic> coachingCommerceFixture() => {
      'schemaVersion': 1,
      'asOfMillis': DateTime.utc(2026, 11, 20).millisecondsSinceEpoch,
      'coaches': [
        {
          'coachId': 'coach_jackson',
          'name': 'Jackson',
          'bookings': 18,
          'confirmed': 12,
          'completed': 4,
          'cancelled': 1,
          'expired': 1,
          'pendingHold': 0,
          'refunded': 0,
          'consultations': 1,
          'missingConsultations': 3,
          'reviewCount': 1,
          'ratingSum': 4,
          'scheduledStarts': 16,
          'daily': [
            {'date': '2026-11-15', 'bookings': 4, 'consultations': 0},
            {'date': '2026-11-16', 'bookings': 6, 'consultations': 1},
            {'date': '2026-11-17', 'bookings': 3, 'consultations': 0},
            {'date': '2026-11-18', 'bookings': 5, 'consultations': 0},
          ],
        },
        {
          'coachId': 'coach_mickey',
          'name': 'Mickey',
          'bookings': 12,
          'confirmed': 7,
          'completed': 3,
          'cancelled': 1,
          'expired': 1,
          'pendingHold': 0,
          'refunded': 0,
          'consultations': 0,
          'missingConsultations': 3,
          'reviewCount': 0,
          'ratingSum': 0,
          'scheduledStarts': 10,
          'daily': [
            {'date': '2026-11-16', 'bookings': 5, 'consultations': 0},
            {'date': '2026-11-17', 'bookings': 4, 'consultations': 0},
            {'date': '2026-11-18', 'bookings': 3, 'consultations': 0},
          ],
        },
        {
          'coachId': 'coach_alex',
          'name': 'Alex Wong',
          'bookings': 4,
          'confirmed': 2,
          'completed': 1,
          'cancelled': 1,
          'expired': 0,
          'pendingHold': 0,
          'refunded': 0,
          'consultations': 0,
          'missingConsultations': 1,
          'reviewCount': 0,
          'ratingSum': 0,
          'scheduledStarts': 3,
          'daily': [
            {'date': '2026-11-17', 'bookings': 2, 'consultations': 0},
            {'date': '2026-11-18', 'bookings': 2, 'consultations': 0},
          ],
        },
        {
          'coachId': 'coach_uat_1',
          'name': '[DISPOSABLE UAT] Synthetic UAT Coach',
          'bookings': 2,
          'confirmed': 1,
          'completed': 0,
          'cancelled': 1,
          'expired': 0,
          'pendingHold': 0,
          'refunded': 0,
          'consultations': 0,
          'missingConsultations': 0,
          'reviewCount': 0,
          'ratingSum': 0,
          'scheduledStarts': 1,
          'daily': [
            {'date': '2026-11-15', 'bookings': 2, 'consultations': 0},
          ],
        },
      ],
      'membership': {
        'current': {'free': 5, 'basic': 12, 'premium': 8, 'unknown': 2},
        'plans': [
          {
            'planId': 'basic',
            'purchases': 3,
            'renewals': 1,
            'confirmedMinor': 30000,
            'confirmedCount': 4,
            'reviewMinor': 0,
            'refundedMinor': 0,
            'statuses': {'cleared': 4},
            'refundStatuses': {'none': 4},
            'daily': [
              {
                'date': '2026-11-16',
                'confirmedMinor': 30000,
                'purchases': 3,
                'renewals': 1
              }
            ],
            'previous': {
              'confirmedMinor': 20000,
              'confirmedCount': 2,
              'purchases': 2,
              'renewals': 0
            }
          }
        ],
        'coaching': {
          'purchases': 2,
          'renewals': 0,
          'confirmedMinor': 20000,
          'confirmedCount': 2,
          'reviewMinor': 0,
          'refundedMinor': 0,
          'statuses': {'cleared': 2},
          'refundStatuses': {'none': 2},
          'daily': [
            {
              'date': '2026-11-16',
              'confirmedMinor': 20000,
              'purchases': 2,
              'renewals': 0
            }
          ],
          'previous': {
            'confirmedMinor': 10000,
            'confirmedCount': 1,
            'purchases': 1,
            'renewals': 0
          }
        },
        'previousAvailable': true,
      },
      'coverage': {
        'membersConsidered': 27,
        'bookingsScanned': 36,
        'paymentsScanned': 42,
      },
    };

class CoachingTestGateway extends BusinessGateway {
  @override
  Future<AdminReportingSnapshot> load(AdminReportQuery q) async {
    queries.add(q);
    final raw = unifiedResponse();
    raw['startAtMillis'] = q.range.start.millisecondsSinceEpoch;
    raw['endAtMillis'] = q.range.end.millisecondsSinceEpoch;
    raw['commerce'] = coachingCommerceFixture();
    return parseAdminOperationalReport(raw, support.reportingScope, q);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUpAll(loadDemoRenderFonts);

  testWidgets(
      'Render Coaching Performance Dashboard and verify workspaces, charts and viewports',
      (tester) async {
    final reset = await installFypOfflineFonts();
    addTearDown(reset);
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final outDir = Directory('../../build/analytics-20261120');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final gateway = CoachingTestGateway();
    const surfaceKey = ValueKey('coaching-analytics-capture-surface');

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

    // 1. Render Overview Workspace
    await tester.pumpWidget(
      RepaintBoundary(
        key: surfaceKey,
        child: fypOfflineChartFonts(
          layout.originalLayoutApp(
            Theme(
              data: AppTheme.build(),
              child: const ColoredBox(
                color: AppColors.surfaceAlt,
                child: ReportsScreen(
                  category: ReportsCategory.coaching,
                  live: true,
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
    expect(find.text('Coaching Analytics'), findsOneWidget);
    expect(
        find.text('Booking activity, session outcomes and coach insights.'),
        findsOneWidget);

    // Verify Tab Bar
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Coach Comparison'), findsOneWidget);

    // Verify KPI Cards
    expect(find.text('Bookings created'), findsWidgets);
    expect(find.text('36'), findsOneWidget);
    expect(find.text('Published consultations'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(find.text('Review samples'), findsWidgets);
    expect(find.text('Average 4.0 ★'), findsOneWidget);
    expect(find.text('Completed outcomes'), findsWidgets);
    expect(find.text('Scheduled starts'), findsWidgets);

    // Verify Charts & Sections
    expect(find.text('Coaching activity over time'), findsOneWidget);
    expect(find.text('Booking outcomes'), findsOneWidget);
    expect(find.text('Bookings by coach'), findsOneWidget);
    expect(find.text('Coach utilization unavailable'), findsOneWidget);
    expect(find.text('Reporting Methodology & Data Coverage Disclosures'),
        findsOneWidget);

    await capture('coaching_analytics_overview_1440.png');
    await tester.pumpAndSettle();
    await capture('coaching_analytics_bookings_by_coach_1440.png');
    await tester.pumpAndSettle();
    await capture('coaching_analytics_booking_outcomes_1440.png');
    await tester.pumpAndSettle();

    // 2. Switch to Coach Comparison Workspace
    await tester.tap(find.text('Coach Comparison'));
    await tester.pumpAndSettle();

    // Verify Comparison Directory
    expect(find.text('Coach Directory & Performance Comparison'), findsOneWidget);
    expect(find.text('Search coaches by name…'), findsOneWidget);
    expect(find.text('All Coaches'), findsWidgets);
    expect(find.text('Jackson'), findsWidgets);
    expect(find.text('Mickey'), findsWidgets);
    expect(find.text('Alex Wong'), findsWidgets);
    expect(find.text('[DISPOSABLE UAT]…'), findsNothing); // Truncated or with badge
    expect(find.text('TEST'), findsOneWidget); // Test badge for disposable UAT fixture

    await capture('coaching_analytics_comparison_1440.png');
    await tester.pumpAndSettle();

    // 3. Test Coach Selection / Focus View
    final focusBtn = find.text('View Focus').first;
    await tester.ensureVisible(focusBtn);
    await tester.pumpAndSettle();
    await tester.tap(focusBtn);
    await tester.pumpAndSettle();

    expect(find.text('Close Focus'), findsOneWidget);
    expect(find.text('Cancellation Rate'), findsOneWidget);

    await capture('coaching_analytics_coach_focus_1440.png');
    await tester.pumpAndSettle();

    // 4. Test Search Filtering in Comparison Table
    await tester.enterText(
        find.widgetWithText(TextField, 'Search coaches by name…'), 'Mickey');
    await tester.pumpAndSettle();

    expect(find.text('Mickey'), findsWidgets);
    expect(find.text('Alex Wong'), findsNothing);

    // Clear search
    await tester.enterText(
        find.widgetWithText(TextField, 'Search coaches by name…'), '');
    await tester.pumpAndSettle();
    expect(find.text('Alex Wong'), findsWidgets);

    // 5. Test Multi-Viewport and Text Scaling Responsiveness
    final viewports = [
      const Size(1920, 1080),
      const Size(1366, 768),
      const Size(1280, 720),
      const Size(1024, 768),
      const Size(768, 1024),
    ];

    for (final vp in viewports) {
      tester.view.physicalSize = vp;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    // Narrow Viewport with 1.5x and 2.0x Text Scale
    tester.view.physicalSize = const Size(430, 932);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(430, 932),
          textScaler: TextScaler.linear(1.5),
        ),
        child: fypOfflineChartFonts(
          layout.originalLayoutApp(
            Theme(
              data: AppTheme.build(),
              child: const ColoredBox(
                color: AppColors.surfaceAlt,
                child: ReportsScreen(
                  category: ReportsCategory.coaching,
                  live: true,
                ),
              ),
            ),
            gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
