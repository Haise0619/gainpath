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
      'Render Fitness Intelligence Dashboard tabs and verify responsive viewports',
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
    const surfaceKey = ValueKey('fitness-analytics-capture-surface');

    Future<void> capture(String filename) async {
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

    // 1. Render Overview Tab
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
                  category: ReportsCategory.fitness,
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

    expect(find.text('Fitness Analytics'), findsOneWidget);
    expect(
        find.text(
            'Workout activity, exercise performance and AI form estimates.'),
        findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Exercise Analytics'), findsOneWidget);
    expect(find.text('AI Form Insights'), findsOneWidget);
    expect(find.text('Workout activity trend'), findsOneWidget);
    expect(find.text('Routine attempt outcomes'), findsOneWidget);
    expect(find.text('Six AI tracking exercises'), findsOneWidget);
    expect(find.text('Estimated form by compatible version'), findsOneWidget);
    expect(find.text('Methodology & Data Coverage Disclosure'), findsOneWidget);

    await capture('fitness_analytics_overview_1440.png');

    // 2. Switch to Exercise Analytics Tab
    await tester.tap(find.text('Exercise Analytics'));
    await tester.pumpAndSettle();

    expect(find.text('Exercise Movement Intelligence'), findsOneWidget);
    expect(find.text('Other exercise details'), findsOneWidget);

    await capture('fitness_analytics_exercises_1440.png');

    // 3. Switch to AI Form Insights Tab
    await tester.tap(find.text('AI Form Insights'));
    await tester.pumpAndSettle();

    expect(find.text('AI Form Insights'), findsNWidgets(2));
    expect(find.text('Estimated Form Score Trend'), findsOneWidget);
    expect(find.textContaining('Estimated form score:'), findsOneWidget);

    await capture('fitness_analytics_ai_form_1440.png');
    await capture('fitness_analytics_score_trend_1440.png');

    // 4. Compatible Group Selection Screenshot
    final dropdownFinder = find.byKey(const ValueKey('exercise-F3b8xIr8ynBDd3gEICKX'));
    if (dropdownFinder.evaluate().isNotEmpty) {
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      await capture('fitness_analytics_group_selection_1440.png');
      // Dismiss dropdown
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    } else {
      await capture('fitness_analytics_group_selection_1440.png');
    }

    // 5. Scored Sample Table Screenshot
    final sampleTileFinder = find.text('View score samples');
    if (sampleTileFinder.evaluate().isNotEmpty) {
      await tester.ensureVisible(sampleTileFinder);
      await tester.tap(sampleTileFinder);
      await tester.pumpAndSettle();
      await capture('fitness_analytics_sample_table_1440.png');
    }

    // 6. Responsive Viewports & Text Scale Verification
    for (final size in [
      const Size(1920, 1080),
      const Size(1536, 864),
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
                    category: ReportsCategory.fitness,
                    live: true,
                  ),
                ),
              ),
            ),
            gateway,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Fitness Analytics'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Overflow at size $size scale $scale');
      }
    }
  });
}
