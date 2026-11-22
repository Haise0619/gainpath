import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadAdminMaterialIcons() {
  final assets = Platform.environment['UNIT_TEST_ASSETS']!;
  final bytes = File('$assets/fonts/MaterialIcons-Regular.otf').readAsBytesSync();
  return (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(bytes))))
      .load();
}
