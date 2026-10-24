import '../numeric_fitness_goal.dart';
import 'local_member_progress.dart';

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
    MemberLocalProgress progress, Iterable<NumericFitnessGoal> goals) {
  final now = progress.asOf.toUtc();
  final today = DateTime.utc(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: today.weekday - DateTime.monday));
  final end = start.add(const Duration(days: 7));
  return List.unmodifiable(goals
      .where((goal) =>
          goal.status == NumericGoalStatus.active &&
          !goal.updatedAt.isAfter(now))
      .map((goal) {
    final (value, label) = switch (goal.category) {
      NumericGoalCategory.trainingFrequency => (
          progress.records
              .where(
                  (r) => !r.endedAt.isBefore(start) && r.endedAt.isBefore(end))
              .length
              .toDouble(),
          'Saved captures this calendar week · Monday–Sunday UTC',
        ),
      NumericGoalCategory.repetitions => (
          progress.records.isEmpty
              ? null
              : progress.records.first.repetitions.toDouble(),
          'Latest saved capture · full repetitions only',
        ),
      NumericGoalCategory.bodyWeight => (
          null,
          'Body-weight measurement not recorded by camera captures'
        ),
    };
    return FitnessGoalComparison(
        goal: goal, measuredValue: value, measurementLabel: label);
  }));
}
