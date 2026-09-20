import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/workout.dart';
import 'exercise_tutorial_screen.dart';
import 'widgets/workout_media.dart';

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routine = context.read<WorkoutRepository>().routine;
    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s routine')),
      body: PageBody(
        children: [
          Text('${routine.length} exercises in order. Tap one to review its form cues.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          ...routine.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: EdgeInsets.zero,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ExerciseTutorialScreen(exercise: e))),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: networkHero(e.imageUrl),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text('${e.sets} sets  ·  ${e.reps} reps  ·  90s rest',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Icon(Icons.play_circle_outline_rounded, color: AppColors.primary, size: 22),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// UC-2.2 — Watch Exercise Tutorial. A simulated video player: tapping
/// play swaps the thumbnail for the same animated pose-demo used on the
/// live tracking screen, with a real scrubber and replay so it reads and
/// behaves like a video even though nothing is actually streamed.
