import '../numeric_fitness_goal.dart';
import 'local_member_progress.dart';

/// One saved routine-day workout attempt, independent of its camera set count.
/// Manual sets never become camera repetitions.
class WorkoutGoalObservation {
  const WorkoutGoalObservation(
      {required this.id,
      required this.startedAt,
      required this.observedAt,
      required this.cameraRepetitions,
      required this.manualSets,
      required this.context,
      required this.completed});
  final String id, context;
  final DateTime startedAt, observedAt;
  final int? cameraRepetitions;
  final int manualSets;
  final bool completed;
}

/// Read-only comparison of a saved target with measured captures. It grants no
/// achievement, rewards, medical conclusion or server-verified workout credit.
class FitnessGoalComparison {
  const FitnessGoalComparison(
      {required this.goal,
      required this.measuredValue,
      required this.measurementLabel,
      this.provisional = true});
  final NumericFitnessGoal goal;
  final double? measuredValue;
  final String measurementLabel;
  final bool provisional;
}

List<FitnessGoalComparison> compareFitnessGoals(
    MemberLocalProgress progress, Iterable<NumericFitnessGoal> goals,
    {double? profileWeightKg, Iterable<WorkoutGoalObservation>? workouts}) {
  final now = progress.asOf.toUtc();
  final today = DateTime.utc(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: today.weekday - DateTime.monday));
  final end = start.add(const Duration(days: 7));
  final observations = <String, WorkoutGoalObservation>{};
  for (final workout in workouts ?? <WorkoutGoalObservation>[]) {
    if (!workout.observedAt.isAfter(now) &&
        !workout.startedAt.isAfter(workout.observedAt)) {
      observations[workout.id] = workout;
    }
  }
  final ordered = observations.values.toList()
    ..sort((a, b) {
      final time = b.observedAt.compareTo(a.observedAt);
      return time != 0 ? time : a.id.compareTo(b.id);
    });
  final latest = ordered.isEmpty ? null : ordered.first;
  return List.unmodifiable(goals
      .where((goal) =>
          goal.status == NumericGoalStatus.active &&
          !goal.updatedAt.isAfter(now))
      .map((goal) {
    final (value, label) = switch (goal.category) {
      NumericGoalCategory.trainingFrequency => (
          workouts == null
              ? null
              : ordered
                  .where((r) =>
                      !r.startedAt.isBefore(start) && r.startedAt.isBefore(end))
                  .length
                  .toDouble(),
          'Saved workout attempts started this calendar week · Monday–Sunday UTC. '
              'Each routine-day attempt counts once; camera sets do not add workouts. '
              'The Malaysia reporting week uses UTC+08:00 instead. '
              '${workouts == null ? "Routine attempt history unavailable." : ""}',
        ),
      NumericGoalCategory.repetitions => (
          latest?.cameraRepetitions?.toDouble(),
          latest == null
              ? 'No whole routine attempt observation available; a camera capture is a set, not a workout.'
              : 'Latest whole routine attempt · ${latest.context} · '
                  '${latest.completed ? "completed" : "partial/in progress"} · '
                  'camera full repetitions across its exercises/sets only; '
                  '${latest.manualSets} self-reported sets kept separate; partial repetitions excluded. '
                  'No exercise-specific target match is inferred.',
        ),
      NumericGoalCategory.bodyWeight => (
          profileWeightKg != null &&
                  profileWeightKg.isFinite &&
                  profileWeightKg > 0
              ? profileWeightKg
              : null,
          profileWeightKg != null &&
                  profileWeightKg.isFinite &&
                  profileWeightKg > 0
              ? 'Current Profile weight · self-reported · measurement date unavailable; no weight trend inferred'
              : 'Body-weight measurement not recorded by camera captures'
        ),
    };
    return FitnessGoalComparison(
        goal: goal, measuredValue: value, measurementLabel: label);
  }));
}
