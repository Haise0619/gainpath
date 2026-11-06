import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Displays published exercise media without substituting a different exercise.
class WorkoutExerciseImage extends StatelessWidget {
  const WorkoutExerciseImage({super.key, required this.url, this.hero = false});

  final String url;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final uri = exerciseImageUri(url);
    Widget fallback() => hero
        ? Image.asset('assets/images/workout_hub_fallback.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            excludeFromSemantics: true)
        : const ColoredBox(
            color: AppColors.surfaceAlt,
            child: Center(
                child: Icon(Icons.fitness_center_rounded,
                    size: 24, color: AppColors.primarySoft)),
          );
    if (uri == null) return fallback();
    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
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
