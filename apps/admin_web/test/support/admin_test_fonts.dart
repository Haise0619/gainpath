import 'dart:io';

import 'package:flutter/services.dart';

import '../../../../test_support/workspace_root.dart';

Future<void> loadAdminReviewFont() {
  final font = findGainPathWorkspace()
      .uri
      .resolve('apps/mobile/assets/fonts/Barlow-Regular.ttf');
  final bytes = File.fromUri(font).readAsBytesSync();
  return (FontLoader('CReview')
        ..addFont(Future.value(ByteData.sublistView(bytes))))
      .load();
}

Future<void> loadAdminMaterialIcons() {
  final assets = Platform.environment['UNIT_TEST_ASSETS']!;
  final bytes = File('$assets/fonts/MaterialIcons-Regular.otf').readAsBytesSync();
  return (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(bytes))))
      .load();
}
