import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/published_routine_view.dart';
import '../domain/routine_attempt.dart';
import '../domain/routine_journey.dart';
import '../domain/routine_plan_signature.dart';

/// Read-only projection of the same compatible checkpoint used by the journey.
class WorkoutHubAttempt {
  const WorkoutHubAttempt({this.checkpoint, required this.total, this.day = 1});
  final RoutineCheckpoint? checkpoint;
  final int total;
  final int day;
  factory WorkoutHubAttempt.fromCheckpoints(
      {required SessionScope scope,
      required PublishedRoutine routine,
      required List<RoutineCheckpoint> checkpoints,
      Set<String> scheduledAttemptIds = const {}}) {
    final days = routine.exercises.map((e) => e.dayNumber).toSet().toList()
      ..sort();
    final signature = routinePlanSignature(routine);
    final compatible = checkpoints
        .where((c) =>
            c.scope == scope &&
            c.routineId == routine.id &&
            c.planSignature == signature &&
            !scheduledAttemptIds.contains(c.id) &&
            days.contains(c.day))
        .toList()
      ..sort((a, b) => b.updatedAtMicros.compareTo(a.updatedAtMicros));
    final checkpoint = compatible.isEmpty ? null : compatible.first;
    final day = checkpoint?.day ?? (days.isEmpty ? 1 : days.first);
    return WorkoutHubAttempt(
        checkpoint: checkpoint,
        day: day,
        total: routine.exercises.where((e) => e.dayNumber == day).length);
  }
  bool get startsNewAttempt =>
      checkpoint?.finished == true && checkpoint?.attempt?.isComplete == true;
  RoutineAttempt? get attempt => startsNewAttempt ? null : checkpoint?.attempt;
  int get completed => attempt?.completedExercises ?? 0;
  bool get resumeUnfinished =>
      checkpoint?.finished == true && !startsNewAttempt;
  String get actionLabel => checkpoint == null || startsNewAttempt
      ? 'Start workout'
      : resumeUnfinished
          ? 'Resume Unfinished Exercises'
          : 'Continue workout';
  String get statusLabel => checkpoint == null || startsNewAttempt
      ? 'Not started'
      : resumeUnfinished
          ? 'Partially completed'
          : 'In progress';
}
