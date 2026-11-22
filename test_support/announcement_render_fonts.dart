// Shared test code uses the dependencies of the calling Flutter app.
// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

Future<ThemeData> announcementFixtureTheme({ThemeData? base}) async {
  final theme = base ??
      ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.bg,
      );
  if (Platform.environment['GAINPATH_ANNOUNCEMENT_SCREENSHOTS'] == null) {
    return theme;
  }
  final fontFile = Platform.environment['GAINPATH_ANNOUNCEMENT_FIXTURE_FONT'];
  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (fontFile == null || sdk == null) {
    throw StateError(
        'Provide the fixture font path and Flutter SDK directory.');
  }
  const family = 'AnnouncementFixture';
  for (final (name, path) in [
    (family, fontFile),
    (
      'MaterialIcons',
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
    ),
  ]) {
    await (FontLoader(name)
          ..addFont(
              Future.value(ByteData.sublistView(File(path).readAsBytesSync()))))
        .load();
  }
  ButtonStyle withFont(ButtonStyle? style) =>
      (style ?? const ButtonStyle()).copyWith(
          textStyle: WidgetStateProperty.resolveWith((states) =>
              (style?.textStyle?.resolve(states) ?? const TextStyle())
                  .copyWith(fontFamily: family)));
  TextStyle fieldStyle(TextStyle? style) =>
      (style ?? const TextStyle()).copyWith(fontFamily: family);
  return theme.copyWith(
    textTheme:
        ThemeData().textTheme.merge(theme.textTheme).apply(fontFamily: family),
    filledButtonTheme:
        FilledButtonThemeData(style: withFont(theme.filledButtonTheme.style)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: withFont(theme.outlinedButtonTheme.style)),
    textButtonTheme:
        TextButtonThemeData(style: withFont(theme.textButtonTheme.style)),
    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
      labelStyle: fieldStyle(theme.inputDecorationTheme.labelStyle),
      floatingLabelStyle:
          fieldStyle(theme.inputDecorationTheme.floatingLabelStyle),
      hintStyle: fieldStyle(theme.inputDecorationTheme.hintStyle),
    ),
    appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle:
            theme.appBarTheme.titleTextStyle?.copyWith(fontFamily: family)),
  );
}
