import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/published_routine_view.dart';

enum RoutineNextAction { start, tutorial }

/// Shown after durable save and camera shutdown, before the next setup consent.
class RoutineNextExerciseSheet extends StatelessWidget {
  const RoutineNextExerciseSheet(
      {super.key,
      required this.previousExercise,
      required this.exercise,
      required this.completedExercises,
      required this.totalExercises,
      required this.capabilityLabel,
      required this.guidance,
      this.hasTracking = true,
      this.perArmTargets = false});
  final bool perArmTargets;
  final bool hasTracking;
  final String previousExercise, capabilityLabel, guidance;
  final PublishedRoutineExercise exercise;
  final int completedExercises, totalExercises;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 20),
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 36),
              const SizedBox(height: 8),
              Text('$previousExercise complete',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                  'Saved on this device · $completedExercises / $totalExercises exercises complete',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 20),
              const Eyebrow('Up next'),
              Text(exercise.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                  '${exercise.sets} sets · ${exercise.reps} reps${perArmTargets ? ' per arm' : ''} per set'),
              Text(capabilityLabel,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(guidance, style: const TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 8),
              Text(hasTracking
                  ? 'Take a moment to get ready. Tracking starts after your camera setup confirmation.'
                  : 'Follow the tutorial, then mark sets as done on the routine page. Completion is self-reported.'),
              const SizedBox(height: 20),
              FilledButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, RoutineNextAction.start),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Start next exercise')),
              OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, RoutineNextAction.tutorial),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Review tutorial')),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to routine')),
            ]),
      ));
}
