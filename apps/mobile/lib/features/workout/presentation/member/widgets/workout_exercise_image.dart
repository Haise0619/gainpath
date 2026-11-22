import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';

/// Displays published exercise media without substituting a different exercise.
class WorkoutExerciseImage extends StatelessWidget {
  const WorkoutExerciseImage({
    super.key,
    required this.url,
    this.hero = false,
    this.fit = BoxFit.contain,
    this.backgroundColor,
  });

  final String url;
  final bool hero;
  final BoxFit fit;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final uri = exerciseImageUri(url);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg =
        isDark ? const Color(0xFF221734) : const Color(0xFFF7F5FA);
    final effectiveBg = backgroundColor ?? defaultBg;
    final iconColor =
        isDark ? const Color(0xFF8B5CF6) : const Color(0xFF9E87C8);

    Widget fallback() => hero
        ? Image.asset('assets/images/workout_hub_fallback.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            excludeFromSemantics: true)
        : Container(
            color: effectiveBg,
            alignment: Alignment.center,
            child: Icon(
              Icons.fitness_center_rounded,
              size: 26,
              color: iconColor,
            ),
          );

    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: hero ? BoxFit.cover : fit,
        width: double.infinity,
        height: double.infinity,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    if (uri == null) return fallback();
    return Image.network(
      uri.toString(),
      fit: hero ? BoxFit.cover : fit,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: hero ? 1000 : 240,
      excludeFromSemantics: true,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : fallback(),
      errorBuilder: (_, __, ___) => fallback(),
    );
  }
}
