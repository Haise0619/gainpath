import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Member typography. Colours, dimensions and behaviour come from AppTheme.
ThemeData buildMemberTypographyTheme() {
  const bodyFamily = 'Barlow';
  const headingFamily = 'BarlowCondensed';
  final base = AppTheme.build();
  final text = base.textTheme.apply(fontFamily: bodyFamily);
  TextStyle? body(TextStyle? style) => style?.copyWith(fontFamily: bodyFamily);
  TextStyle? heading(TextStyle? style) =>
      style?.copyWith(fontFamily: headingFamily);
  WidgetStateProperty<TextStyle?>? bodyStates(
          WidgetStateProperty<TextStyle?>? style) =>
      style == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => body(style.resolve(states)));
  ButtonStyle? bodyButton(ButtonStyle? style) =>
      style?.copyWith(textStyle: bodyStates(style.textStyle));

  return base.copyWith(
    textTheme: text.copyWith(
      displayLarge: heading(text.displayLarge),
      displayMedium: heading(text.displayMedium),
      displaySmall: heading(text.displaySmall),
      headlineLarge: heading(text.headlineLarge),
      headlineMedium: heading(text.headlineMedium),
      headlineSmall: heading(text.headlineSmall),
      titleLarge: heading(text.titleLarge),
    ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: bodyFamily),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: heading(base.appBarTheme.titleTextStyle),
      toolbarTextStyle: body(base.appBarTheme.toolbarTextStyle),
    ),
    filledButtonTheme:
        FilledButtonThemeData(style: bodyButton(base.filledButtonTheme.style)),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: bodyButton(base.outlinedButtonTheme.style)),
    textButtonTheme:
        TextButtonThemeData(style: bodyButton(base.textButtonTheme.style)),
    segmentedButtonTheme: SegmentedButtonThemeData(
        style: bodyButton(base.segmentedButtonTheme.style)),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      labelTextStyle: bodyStates(base.navigationBarTheme.labelTextStyle),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: body(base.inputDecorationTheme.labelStyle),
    ),
    tooltipTheme: base.tooltipTheme
        .copyWith(textStyle: body(base.tooltipTheme.textStyle)),
  );
}

/// Increase text without discarding the device's (possibly nonlinear) scaling.
TextScaler memberTextScaler(TextScaler systemScaler) =>
    _MemberTextScaler(systemScaler);

class _MemberTextScaler extends TextScaler {
  const _MemberTextScaler(this.systemScaler);

  final TextScaler systemScaler;
  static const double factor = 1.1;

  @override
  double scale(double fontSize) => systemScaler.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(1);

  @override
  bool operator ==(Object other) =>
      other is _MemberTextScaler && other.systemScaler == systemScaler;

  @override
  int get hashCode => Object.hash(_MemberTextScaler, systemScaler);
}
