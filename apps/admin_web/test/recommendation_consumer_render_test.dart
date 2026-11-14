import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/recommendation_queue_transport.dart';
import 'support/recommendation_queue_fixture.dart';
import 'support/canonical_admin_recommendation_fixture.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final font in [
      ('ReviewArial', 'C:/Windows/Fonts/arial.ttf'),
      (
        'MaterialIcons',
        'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf'
      )
    ]) {
      final loader = FontLoader(font.$1)
        ..addFont(Future.value(
            ByteData.sublistView(await File(font.$2).readAsBytes())));
      await loader.load();
    }
  });
  for (final stage in ['after', 'canonical']) {
    for (final scenario in [
      ('desktop', 1440.0, 1.0),
      ('320', 320.0, 1.0),
      ('360', 360.0, 1.0),
      ('360-200', 360.0, 2.0)
    ]) {
      testWidgets('$stage recommendation fixture ${scenario.$1}',
          (tester) async {
        tester.view.physicalSize = Size(scenario.$2, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        addTearDown(await installFypOfflineFonts());
        final key = GlobalKey();
        final h = QueueTransportHarness();
        final canonical = CanonicalAdminHarness();
        final baseTheme = AppTheme.build();
        final theme = baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(fontFamily: 'ReviewArial'),
            primaryTextTheme:
                baseTheme.primaryTextTheme.apply(fontFamily: 'ReviewArial'));
        await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: ColoredBox(
                    color: AppColors.bg,
                    child: MediaQuery(
                        data: MediaQueryData(
                            textScaler: TextScaler.linear(scenario.$3)),
                        child: RiskLeaderboardScreen(
                            queueRepository: h.repository,
                            queueClock: () => queueNow,
                            canonicalRepository: stage == 'canonical'
                                ? canonical.repository
                                : null))))));
        await tester.pumpAndSettle();
        if (stage == 'before') {
          await tester.ensureVisible(find.text('Trainer Matching'));
          await tester.tap(find.text('Trainer Matching'));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        Future<void> capture(String suffix) async {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(key))
                .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final f = File(
                '../../build/module13-consumer/admin/$stage-${scenario.$1}$suffix.png');
            await f.parent.create(recursive: true);
            await f.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('');
        if (stage != 'before') {
          await tester.ensureVisible(find.text('Review').last);
          await tester.tap(find.text('Review').last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capture('-review');
          await tester.ensureVisible(find.text('Approve & Send'));
          expect(find.text('Approve & Send').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
          skip: !const bool.fromEnvironment(
              'GAINPATH_RENDER_ADMIN_RECOMMENDATIONS'));
    }
  }
}
