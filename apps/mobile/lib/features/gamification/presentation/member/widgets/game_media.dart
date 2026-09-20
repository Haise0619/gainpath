import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

Widget gameHero(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.ink),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M3.3 — View Gamification Dashboard.
