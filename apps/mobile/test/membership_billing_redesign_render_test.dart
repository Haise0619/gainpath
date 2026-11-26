import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/main_billing_preview.dart' as preview;
import 'package:google_fonts/google_fonts.dart';

import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadDemoRenderFonts();
  });

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'Membership billing Payment Due renders without overflow at ${width.toInt()}dp scale=${scale.toInt()}x',
          (tester) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.reset);

        preview.main();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Payment Due'));
        await tester.pumpAndSettle();

        expect(find.text('Membership billing'), findsOneWidget);
        expect(find.text('Payment Due'), findsOneWidget);
        expect(find.text('Pay Now'), findsOneWidget);
        expect(find.text('Cancel Renewal'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Capture screenshot of redesigned Membership Billing screen',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    preview.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment Due'));
    await tester.pumpAndSettle();

    final brainDir = Directory(
        'C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314')
      ..createSync(recursive: true);

    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${brainDir.path}/membership_billing_redesign_393.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('Capture screenshot at 320dp 2.0x scale', (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);

    preview.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment Due'));
    await tester.pumpAndSettle();

    final brainDir = Directory(
        'C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314')
      ..createSync(recursive: true);

    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first);
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${brainDir.path}/membership_billing_redesign_320_2x.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
