import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadDemoRenderFonts() async {
  const font = 'C:/Windows/Fonts/arial.ttf';
  await (FontLoader('CReview')
        ..addFont(
            Future.value(ByteData.sublistView(await File(font).readAsBytes()))))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(await File(
                'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
            .readAsBytes()))))
      .load();
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
