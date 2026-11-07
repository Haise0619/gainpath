import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/published_routine_view.dart';
import '../domain/routine_attempt.dart';
import '../domain/routine_journey.dart';
import '../domain/routine_plan_signature.dart';

/// Read-only projection of the same compatible checkpoint used by the journey.
class WorkoutHubAttempt {
  const WorkoutHubAttempt({this.checkpoint, required this.total});
  final RoutineCheckpoint? checkpoint;
  final int total;
  factory WorkoutHubAttempt.fromCheckpoints(
      {required SessionScope scope,
      required PublishedRoutine routine,
      required List<RoutineCheckpoint> checkpoints}) {
    final days = routine.exercises.map((e) => e.dayNumber).toSet().toList()
      ..sort();
    final compatible = checkpoints
        .where((c) =>
            c.scope == scope &&
            c.routineId == routine.id &&
            c.planSignature == routinePlanSignature(routine) &&
            days.contains(c.day))
        .toList()
      ..sort((a, b) => b.updatedAtMicros.compareTo(a.updatedAtMicros));
    final checkpoint = compatible.isEmpty ? null : compatible.first;
    final day = checkpoint?.day ?? (days.isEmpty ? 1 : days.first);
    return WorkoutHubAttempt(
        checkpoint: checkpoint,
        total: routine.exercises.where((e) => e.dayNumber == day).length);
  }
  RoutineAttempt? get attempt => checkpoint?.attempt;
  int get completed => attempt?.completedExercises ?? 0;
  bool get resumeUnfinished =>
      checkpoint?.finished == true && attempt?.isComplete != true;
  String get actionLabel => checkpoint == null
      ? 'Start workout'
      : checkpoint!.finished
          ? attempt?.isComplete == true
              ? 'View Workout Summary'
              : 'Resume Unfinished Exercises'
          : 'Continue workout';
  String get statusLabel => checkpoint == null
      ? 'Not started'
      : checkpoint!.finished
          ? attempt?.isComplete == true
              ? 'Completed'
              : 'Partially completed'
          : 'In progress';
}
