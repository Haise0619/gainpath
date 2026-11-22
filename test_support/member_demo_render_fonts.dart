// Both Flutter apps use these assets in screenshot tests.
// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'workspace_root.dart';

Future<void> loadDemoRenderFonts() async {
  final root = findGainPathWorkspace().uri;
  final config = File.fromUri(root.resolve('.dart_tool/package_config.json'));
  final decoded =
      jsonDecode(await config.readAsString()) as Map<String, dynamic>;
  final flutter = (decoded['packages'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .firstWhere((package) => package['name'] == 'flutter');
  final flutterPackage = config.uri.resolve('${flutter['rootUri']}/');
  final fonts = root.resolve('apps/mobile/assets/fonts/');
  final materialIcons = flutterPackage.resolve(
      '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  for (final (family, uri) in [
    ('Barlow', fonts.resolve('Barlow-Regular.ttf')),
    ('BarlowCondensed', fonts.resolve('BarlowCondensed-Regular.ttf')),
    ('MaterialIcons', materialIcons),
  ]) {
    final data = await File.fromUri(uri).readAsBytes();
    await (FontLoader(family)
          ..addFont(Future.value(ByteData.sublistView(data))))
        .load();
  }
}
