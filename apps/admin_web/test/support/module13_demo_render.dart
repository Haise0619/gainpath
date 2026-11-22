import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_test_fonts.dart';

Future<void> loadDemoRenderFonts() async {
  await loadAdminReviewFont();
  await loadAdminMaterialIcons();
}

Future<void> captureDemo(WidgetTester tester, Key key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1),
        bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../../build/module13-firebase-demo/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
