import 'package:gainpath_domain/analytics.dart';
import '../../workout/domain/routine_attempt.dart';

/// Adjacent captures within the exact exercise/rule/model/view contract.
/// Missing scores remain gaps; these differences do not establish fitness gains.
class ExerciseImprovement {
  const ExerciseImprovement(this.latest, this.previous);
  final LocalWorkoutProgressRecord latest;
  final LocalWorkoutProgressRecord? previous;
  double? get scoreChange =>
      previous?.formScorePercent == null || latest.formScorePercent == null
          ? null
          : latest.formScorePercent! - previous!.formScorePercent!;
}

List<ExerciseImprovement> exerciseImprovements(MemberLocalProgress progress) =>
    [
      for (final group in progress.formSeries)
        if (group.records.isNotEmpty) _comparison(group.records),
    ];

ExerciseImprovement _comparison(List<LocalWorkoutProgressRecord> records) {
  final sorted = [...records]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
  return ExerciseImprovement(
      sorted.first, sorted.length < 2 ? null : sorted[1]);
}

/// Authored plan context, never an inferred per-capture target or achievement.
String? linkedRoutineTarget(
    LocalWorkoutProgressRecord record, RoutineProgress? routines) {
  if (routines == null) return null;
  final links = <String>[];
  for (final attempt in routines.records) {
    if (attempt.scope != record.scope) continue;
    for (final entry in attempt.entries) {
      if (!entry.sessionIds.contains(record.sessionId) ||
          entry.index < 0 ||
          entry.index >= attempt.routine.exercises.length) {
        continue;
      }
      final exercise = attempt.routine.exercises[entry.index];
      if (exercise.exerciseId != record.exerciseId ||
          exercise.dayNumber != attempt.day) {
        continue;
      }
      links.add(
          '${attempt.routine.title} · day ${attempt.day}: ${exercise.sets} sets × ${exercise.reps} reps');
    }
  }
  return links.length == 1 ? links.single : null;
}
