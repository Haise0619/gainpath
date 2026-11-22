import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'support/recommendation_queue_transport.dart';
import 'support/recommendation_queue_fixture.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadDemoRenderFonts();
  });
  for (final stage in ['monitor']) {
    for (final scenario in [
      for (final width in [1920, 1440, 1024, 768, 390, 320])
        for (final scale in [1, 2])
          ('$width-${scale * 100}', width.toDouble(), scale.toDouble())
    ]) {
      testWidgets('$stage recommendation fixture ${scenario.$1}',
          (tester) async {
        tester.view.physicalSize = Size(scenario.$2, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        addTearDown(await installFypOfflineFonts());
        final key = GlobalKey();
        final h = QueueTransportHarness()
          ..freshDetail = queueLead(kind: 'content');
        final baseTheme = AppTheme.build();
        final theme = baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(fontFamily: 'CReview'),
            primaryTextTheme:
                baseTheme.primaryTextTheme.apply(fontFamily: 'CReview'));
        await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scenario.$3)),
                    child: child!),
                home: ColoredBox(
                    color: AppColors.bg,
                    child: RiskLeaderboardScreen(
                        queueRepository: h.repository,
                        queueClock: () => queueNow)))));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        Future<void> capture(String suffix) async {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(key))
                .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final f = File(
                '../../build/module13-admin-performance/screenshots/$stage-${scenario.$1}$suffix.png');
            await f.parent.create(recursive: true);
            await f.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('');
        {
          final view = find.widgetWithText(TextButton, 'View').first;
          await tester.scrollUntilVisible(view, 180,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await tester.tap(view);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Squat foundations'), findsWidgets);
          expect(find.text('Recommendation details could not be verified.'),
              findsNothing);
          await capture('-review');
          await tester.ensureVisible(find.text('Close'));
          expect(find.text('Close').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
          skip: !const bool.fromEnvironment(
              'GAINPATH_RENDER_ADMIN_RECOMMENDATIONS'));
    }
  }
}
