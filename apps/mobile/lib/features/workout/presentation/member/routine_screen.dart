import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/workout.dart';
import '../../domain/published_routine_view.dart';
import 'exercise_tutorial_screen.dart';
import 'widgets/workout_media.dart';

class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key, this.publishedRoutine, this.tutorialBuilder});
  final PublishedRoutine? publishedRoutine;
  final Widget Function(BuildContext, PublishedRoutineExercise)?
      tutorialBuilder;

  @override
  Widget build(BuildContext context) {
    final routine = publishedRoutine?.exercises ??
        context.read<WorkoutRepository>().routine;
    return Scaffold(
      appBar: AppBar(
          title: Text(publishedRoutine == null
              ? 'Today\'s routine'
              : publishedRoutine!.title)),
      body: PageBody(
        children: [
          Text(
              publishedRoutine == null
                  ? '${routine.length} exercises in order. Tap one to review its form cues.'
                  : '${routine.length} exercises in order. Tap one to review its published tutorial.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          ...routine.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: EdgeInsets.zero,
                onTap: publishedRoutine == null
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ExerciseTutorialScreen(exercise: e)))
                    : () {
                        final builder = tutorialBuilder;
                        if (builder == null) {
                          showUnavailable(context);
                          return;
                        }
                        final row = publishedRoutine!.exercises[i];
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (ctx) => builder(ctx, row)));
                      },
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
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800)),
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
                            Text(e.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                                publishedRoutine == null
                                    ? '${e.sets} sets  ·  ${e.reps} reps  ·  90s rest'
                                    : '${e.sets} sets  ·  ${e.reps} reps',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Icon(Icons.play_circle_outline_rounded,
                          color: AppColors.primary, size: 22),
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

/// UC-2.2 — Published rows use an app-composed tutorial destination;
/// mock rows retain the isolated animated demonstration.
