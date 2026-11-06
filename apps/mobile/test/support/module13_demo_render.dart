import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadDemoRenderFonts() async {
  const font =
      'C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/assets/fonts/Barlow-Regular.ttf';
  await (FontLoader('Barlow')
        ..addFont(
            Future.value(ByteData.sublistView(await File(font).readAsBytes()))))
      .load();
  await (FontLoader('BarlowCondensed')
        ..addFont(Future.value(ByteData.sublistView(await File(
                'C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/assets/fonts/BarlowCondensed-Regular.ttf')
            .readAsBytes()))))
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
    await File(
            'C:/Users/Ngzhe/StudioProjects/gainpath/build/module13-firebase-demo/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
