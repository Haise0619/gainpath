import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

/// Defensive online-image loader: a broken/slow link never breaks the
/// layout — the same pattern already used across onboarding, profile
/// setup, the workout module, and gamification.
Widget networkAvatar(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}
