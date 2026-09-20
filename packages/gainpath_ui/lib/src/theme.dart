import 'package:flutter/material.dart';

class GainPathUiTheme {
  const GainPathUiTheme._();

  static ThemeData build({bool admin = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF287C6B),
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7F8),
      visualDensity: admin
          ? VisualDensity.standard
          : VisualDensity.adaptivePlatformDensity,
    );
  }
}
