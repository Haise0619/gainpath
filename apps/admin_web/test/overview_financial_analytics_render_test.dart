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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUpAll(loadDemoRenderFonts);

  testWidgets(
      'Render Overview Analytics and Financial Analytics at 1440 and verify responsive viewports',
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

    final gateway = BusinessGateway();
    const surfaceKey = ValueKey('analytics-capture-surface');

    // 1. Render Overview Analytics
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
                  category: ReportsCategory.overview,
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

    expect(find.text('Overview Analytics'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Recorded revenue'), findsOneWidget);
    expect(find.text('Revenue & Trend Overview'), findsOneWidget);
    expect(find.text('Workout Activity Summary'), findsOneWidget);
    expect(find.text('Appointment Outcomes'), findsOneWidget);
    expect(find.text('Needs Attention & Operational Alerts'), findsOneWidget);
    expect(find.text('Explore Detailed Reports'), findsOneWidget);

    // Save Overview Screenshot
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(surfaceKey))
          .toImage();
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await File('${outDir.path}/overview_analytics_dashboard_1440.png')
          .writeAsBytes(bytes);
      image.dispose();
    });

    // 2. Switch to Financial Analytics
    final reportsState =
        tester.state<ReportsScreenState>(find.byType(ReportsScreen));
    reportsState.selectCategory(ReportsCategory.financial);
    await tester.pumpAndSettle();

    expect(find.text('Financial Analytics'), findsOneWidget);
    expect(find.textContaining('Recorded Collections'), findsOneWidget);
    expect(find.text('Current Organization Census'), findsOneWidget);
    expect(find.text('Facility & Multi-Branch Availability'), findsOneWidget);

    // Save Financial Screenshot
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(surfaceKey))
          .toImage();
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      await File('${outDir.path}/financial_analytics_dashboard_1440.png')
          .writeAsBytes(bytes);
      image.dispose();
    });

    // 3. Responsive Multi-Viewport & Text Scaling Tests
    for (final size in [
      const Size(1920, 1080),
      const Size(1440, 900),
      const Size(1366, 768),
      const Size(1280, 720),
      const Size(1024, 768),
      const Size(768, 1024),
    ]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          layout.originalLayoutApp(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Theme(
                  data: AppTheme.build(),
                  child: const ReportsScreen(
                    category: ReportsCategory.overview,
                    live: true,
                  ),
                ),
              ),
            ),
            gateway,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Overview Analytics'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Overflow at size $size scale $scale');
      }
    }
  });
}
