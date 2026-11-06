// Test-only package boundary: both Flutter apps share this offline render helper.
// ignore_for_file: depend_on_referenced_packages, invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_test;

/// Offline test rendering only. Poppins/Inter and chart fonts use the
/// repository's existing Barlow font files. Screenshot evidence must disclose
/// this substitute typography; production theme/assets are never modified.
Future<void Function()> installFypOfflineFonts() async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final previousManifest = google_fonts_test.assetManifest;
  final previousFetching = GoogleFonts.config.allowRuntimeFetching;
  const directory =
      'C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/assets/fonts';
  final bytes = <String, ByteData>{};
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    bytes[weight] = ByteData.sublistView(
        File('$directory/Barlow-$weight.ttf').readAsBytesSync());
  }
  await (FontLoader('FypChart')..addFont(Future.value(bytes['Regular']!)))
      .load();
  final variants = [
    'Thin',
    'ExtraLight',
    'Light',
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black'
  ];
  final assets = <String, ByteData>{};
  for (final family in ['Poppins', 'Inter']) {
    for (var i = 0; i < variants.length; i++) {
      final source = i < 4
          ? 'Regular'
          : i == 4
              ? 'Medium'
              : i == 5
                  ? 'SemiBold'
                  : 'Bold';
      assets['fyp-test-fonts/$family-${variants[i]}.ttf'] = bytes[source]!;
      assets['fyp-test-fonts/$family-${i == 3 ? 'Italic' : '${variants[i]}Italic'}.ttf'] =
          bytes[source]!;
    }
  }
  GoogleFonts.config.allowRuntimeFetching = false;
  google_fonts_test.clearCache();
  google_fonts_test.assetManifest = _FontManifest(assets.keys.toList());
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = const StringCodec().decodeMessage(message);
    if (assets.containsKey(key)) return assets[key];
    return messenger.delegate.send('flutter/assets', message);
  });
  return () {
    messenger.setMockMessageHandler('flutter/assets', null);
    google_fonts_test.assetManifest = previousManifest;
    google_fonts_test.clearCache();
    GoogleFonts.config.allowRuntimeFetching = previousFetching;
  };
}

/// Charts paint text on a canvas without a DefaultTextStyle ancestor. Supply
/// only the offline font family; retain production colors, sizes and geometry.
Widget fypOfflineChartFonts(Widget child) => SfChartTheme(
    data: const SfChartThemeData(
        axisLabelTextStyle: TextStyle(fontFamily: 'FypChart'),
        axisTitleTextStyle: TextStyle(fontFamily: 'FypChart'),
        legendTextStyle: TextStyle(fontFamily: 'FypChart'),
        dataLabelTextStyle: TextStyle(fontFamily: 'FypChart')),
    child: child);

class _FontManifest implements AssetManifest {
  _FontManifest(this.assets);
  final List<String> assets;
  @override
  List<String> listAssets() => assets;
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}
