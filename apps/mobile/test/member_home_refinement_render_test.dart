import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'member_home_refinement_test.dart' as fixture;

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Home $width at $scale text: content and AI never overlap',
          (t) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        t.view.physicalSize = Size(width, 820);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final key = GlobalKey();
        await t.pumpWidget(fixture.homeTestApp(
            captureKey: key,
            scale: scale,
            routines: fixture.homeRoutines(
                [fixture.homeAttempt(finished: true, completed: true)]),
            onStart: () {},
            onAttempt: (_) {}));
        await t.pumpAndSettle();
        Future<void> capture(String name) async {
          expect(t.takeException(), isNull);
          final ai = find.byKey(const ValueKey('home-ai-entry')),
              nav = find.byKey(const ValueKey('test-bottom-nav'));
          expect(
              t.getBottomLeft(ai).dy, lessThanOrEqualTo(t.getTopLeft(nav).dy));
          final boundary =
              t.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await t.runAsync(() async {
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../build/home-refinement-20261109/renders/$name-${width.toInt()}-${scale.toInt()}x.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('top');
        for (final entry in {
          'workout': find.byKey(const ValueKey('home-today-workout')),
          'weekly': find.text('Weekly progress'),
          'quick': find.text('Quick access'),
          'goals': find.text('Your goals')
        }.entries) {
          for (var i = 0; entry.value.evaluate().isEmpty && i < 20; i++) {
            await t.drag(find.byKey(const ValueKey('home-scroll')),
                const Offset(0, -220));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          }
          await Scrollable.ensureVisible(t.element(entry.value),
              alignment: 0.15);
          await t.pumpAndSettle();
          await capture(entry.key);
        }
        await t.ensureVisible(find.text('More shortcuts'));
        await t.tap(find.text('More shortcuts'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await capture('more');
        expect(find.text('Coaches'), findsOneWidget);
        expect(find.text('Saved tips'), findsOneWidget);
      });
    }
  }
}
