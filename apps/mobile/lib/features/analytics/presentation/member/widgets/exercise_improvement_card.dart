import 'package:flutter/material.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/exercise_improvement.dart';
import '../../../../workout/domain/routine_attempt.dart';
import '../../../domain/member_workout_report.dart';

class ExerciseImprovementCard extends StatelessWidget {
  const ExerciseImprovementCard(
      {super.key,
      required this.progress,
      this.onOpenWorkout,
      this.routineProgress});
  final MemberLocalProgress progress;
  final RoutineProgress? routineProgress;
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Previous vs recent'),
          const Text(
              'Comparable camera captures only. Counts describe each capture; duration and targets may differ.'),
          if (progress.records.isEmpty)
            const Panel(
                child: Text('Save two compatible captures to compare.')),
          for (final comparison in exerciseImprovements(progress))
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      reportExerciseNames(routineProgress?.records ?? const [])[
                              comparison.latest.exerciseId] ??
                          reportExerciseLabel(comparison.latest.exerciseId),
                      style: Theme.of(context).textTheme.titleMedium),
                  if (comparison.previous == null)
                    const Text('Not enough compatible captures yet.')
                  else ...[
                    Text(
                        'Full reps: ${comparison.previous!.repetitions} → ${comparison.latest.repetitions} · partial attempts: ${comparison.previous!.partialRepetitions} → ${comparison.latest.partialRepetitions}'),
                    Text(comparison.scoreChange == null
                        ? 'Estimated Form Score comparison unavailable: a capture has no score.'
                        : 'Estimated Form Score: ${comparison.previous!.formScorePercent!.toStringAsFixed(1)} → ${comparison.latest.formScorePercent!.toStringAsFixed(1)} (${comparison.scoreChange! >= 0 ? '+' : ''}${comparison.scoreChange!.toStringAsFixed(1)} points)'),
                  ],
                  Text('Recent: ${reportDate(comparison.latest.endedAt)} MYT'),
                  Text(
                      'Recent routine target: ${linkedRoutineTarget(comparison.latest, routineProgress) ?? 'unavailable (no unique linked plan)'}'),
                  if (comparison.previous != null)
                    Text(
                        'Previous routine target: ${linkedRoutineTarget(comparison.previous!, routineProgress) ?? 'unavailable (no unique linked plan)'}'),
                  const Text(
                      'Routine targets describe the authored plan, not a per-capture target or verified completion.'),
                  Wrap(spacing: 8, children: [
                    if (comparison.previous != null && onOpenWorkout != null)
                      TextButton(
                          onPressed: () => onOpenWorkout!(comparison.previous!),
                          child: const Text('Previous capture')),
                    if (onOpenWorkout != null)
                      TextButton(
                          onPressed: () => onOpenWorkout!(comparison.latest),
                          child: const Text('Recent capture')),
                  ]),
                  ExpansionTile(
                      title: const Text('Measurement details'),
                      children: [
                        Text('Exercise ID: ${comparison.latest.exerciseId}'),
                        Text(
                            '${comparison.latest.cameraView} · ${comparison.latest.scoringVersion} · ${comparison.latest.detectorId}/${comparison.latest.detectorVersion}'),
                        const Text(
                            'Provisional measurements. Manual sets are separate; no load, physical accuracy or workout acceptance is inferred.'),
                      ]),
                ])),
        ],
      );
}
