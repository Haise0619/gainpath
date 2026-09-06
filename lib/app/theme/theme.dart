import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GainPath design tokens.
///
/// A deep violet carries the brand: confident and premium without tipping
/// into the "generic gym red" cliché. Amber stays reserved for gamification
/// and celebratory moments, per the design principle that a single accent
/// should keep its meaning rather than being diluted across every screen.
/// The aqua overlay colour exists purely for legibility on top of a live
/// camera feed, so it deliberately sits outside the brand pair.
class AppColors {
  static const bg = Color(0xFFFAF8FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2EDFB);

  static const ink = Color(0xFF190F2E);
  static const inkSoft = Color(0xFF6B6488);
  static const hairline = Color(0xFFE6E0F5);

  static const primary = Color(0xFF6D28D9);
  static const primarySoft = Color(0xFF8B5CF6);
  static const primaryDark = Color(0xFF4C1D95);
  static const primaryTint = Color(0xFFEDE7FB);
  static const accent = Color(0xFFF59E0B);
  static const accentDark = Color(0xFFB45309);
  static const accentTint = Color(0xFFFDF0D6);

  /// Skeleton overlay on the live camera feed. Functional contrast beats
  /// brand consistency here.
  static const overlay = Color(0xFF00E5C0);

  static const danger = Color(0xFFDC2626);
  static const dangerTint = Color(0xFFFBE7E6);
  static const success = Color(0xFF16A34A);
  static const successTint = Color(0xFFE3F6E9);
  static const warning = Color(0xFFD97706);
  static const info = Color(0xFF2563EB);
  static const infoTint = Color(0xFFE6EEFD);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
  );
}

class AppTheme {
  static ThemeData build() {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final headingFont = GoogleFonts.poppins;
    final bodyFont = GoogleFonts.inter;

    final textTheme = TextTheme(
      displaySmall: headingFont(
          fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.0, color: AppColors.ink),
      headlineMedium: headingFont(
          fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.6, color: AppColors.ink),
      titleLarge: headingFont(
          fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.ink),
      titleMedium: bodyFont(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.ink),
      bodyLarge: bodyFont(fontSize: 15, height: 1.45, color: AppColors.ink),
      bodyMedium: bodyFont(fontSize: 14, height: 1.45, color: AppColors.inkSoft),
      labelLarge: bodyFont(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
      labelSmall: bodyFont(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.inkSoft,
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      dividerColor: AppColors.hairline,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: headingFont(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: headingFont(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: headingFont(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: bodyFont(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
        labelStyle: bodyFont(color: AppColors.inkSoft),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryTint,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => bodyFont(
              fontSize: 11.5,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.inkSoft,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.inkSoft,
            )),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkSoft,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.primary : AppColors.hairline),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: AppColors.inkSoft,
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.hairline),
          textStyle: bodyFont(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: bodyFont(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
