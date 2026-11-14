import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/features/recommendation/application/recommendation_queue.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_demo_recommendation.dart';
import '../../../test_support/live_presentation_bridge.dart';
import '../../../test_support/fyp_render_support.dart';

void main() {
  testWidgets('live Firebase Admin recommendation presentation', (t) async {
    addTearDown(await installFypOfflineFonts());
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File(
              'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
          .readAsBytesSync())));
    await icons.load();
    final bridge = LivePresentationBridge('admin');
    final repos =
        FirebaseDemoAdminRepositories(bridge.transport, readOnly: false);
    final now = DateTime.now().toUtc();
    final counts = <String, int>{};
    await t.runAsync(() async {
      for (final kind in ['content', 'trainer']) {
        final page = await repos.queue
            .list(RecommendationQueueQuery.recent('gainpath', kind, now, 30));
        counts[kind] = page.leads.length;
        if (page.leads.isNotEmpty) await repos.queue.detail(page.leads.first);
      }
    });
    expect(bridge.failures, isEmpty);
    expect(counts.values.fold<int>(0, (a, b) => a + b), greaterThan(0),
        reason: 'Actual Firebase queue rows required; no fixtures allowed.');
    final dir =
        Directory('../../build/module13-presentation/live-renders/admin')
          ..createSync(recursive: true);
    File('${dir.path}/evidence.json').writeAsStringSync(
        jsonEncode({'actualRows': counts, 'readRequests': bridge.requests}));
    for (final width in [1440.0, 360.0]) {
      for (final scale in [1.0, 2.0]) {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.build(),
                builder: (c, child) => MediaQuery(
                    data: MediaQuery.of(c)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: ColoredBox(
                    color: AppColors.bg,
                    child: RiskLeaderboardScreen(
                        queueRepository: repos.queue,
                        queueClock: () => now,
                        insightsRepository: repos.insights)))));
        for (var attempt = 0; attempt < 180; attempt++) {
          await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)));
          await t.pump(const Duration(milliseconds: 100));
          if (bridge.pending == 0 && attempt > 2) break;
        }
        await t.pumpAndSettle();
        expect(bridge.failures, isEmpty);
        expect(t.takeException(), isNull);
        expect(find.text('Queue maintenance'), findsNothing);
        await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '${dir.path}/queue-${width.toInt()}-${(scale * 100).round()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await t.ensureVisible(find.widgetWithText(TextButton, 'Review').first);
        await t.tap(find.widgetWithText(TextButton, 'Review').first);
        for (var attempt = 0; attempt < 180; attempt++) {
          await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)));
          await t.pump(const Duration(milliseconds: 100));
          if (bridge.pending == 0 && attempt > 2) break;
        }
        await t.pumpAndSettle();
        expect(bridge.failures, isEmpty);
        expect(t.takeException(), isNull);
        expect(find.text('Technical Details'), findsOneWidget);
        await t.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '${dir.path}/review-${width.toInt()}-${(scale * 100).round()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await t.pumpWidget(const SizedBox());
      }
    }
    t.view.reset();
  },
      skip: !const bool.fromEnvironment('GAINPATH_RENDER_LIVE_PRESENTATION'),
      timeout: const Timeout(Duration(minutes: 5)));
}
