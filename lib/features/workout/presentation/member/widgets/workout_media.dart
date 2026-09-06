import 'package:flutter/material.dart';
import 'package:gainpath/app/theme/theme.dart';

const routineHeroImage =
    'https://images.unsplash.com/photo-1584863231364-2edc166de576?auto=format&fit=crop&w=1200&q=80';
const cameraHeroImage =
    'https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?auto=format&fit=crop&w=1200&q=80';

/// Full-bleed network image with a graceful gradient fallback so a dead
/// link never breaks the layout — the same defensive pattern used across
/// the onboarding and profile-setup flows.
Widget networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.ink),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M2.2 — Pre-Workout Preparation. A Staging Menu hub: three optional
/// detours (Watch Tutorial, View Routine, Review Camera Setup) that each
/// loop back here, plus the one action that actually leaves the screen
/// forward — Proceed to Workout.
