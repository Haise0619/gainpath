import '../domain/program_enrollment.dart';
import '../domain/routine_attempt.dart';
import '../domain/published_routine_view.dart';
import 'workout_program_controller.dart';

class ScheduledWorkoutPreview {
  ScheduledWorkoutPreview(
      {required this.routine,
      required this.day,
      required this.dayKey,
      required this.enrollmentId,
      required this.date,
      required this.snapshot,
      required this.inProgress,
      this.attempt});
  final PublishedRoutine routine;
  final int day;
  final String dayKey, enrollmentId, snapshot;
  final DateTime date;
  final bool inProgress;
  final RoutineAttempt? attempt;
}

class WorkoutHubProgram {
  WorkoutHubProgram(this.controller, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final WorkoutProgramController controller;
  final DateTime Function() _clock;
  String? get recoveryDayLabel {
    final now = _clock().toUtc().add(const Duration(hours: 8));
    final days = controller.enrollment?.schedule.where((d) =>
        d.date.year == now.year &&
        d.date.month == now.month &&
        d.date.day == now.day &&
        d.definition.kind != 'workout');
    if (days == null || days.isEmpty) return null;
    return days.first.definition.kind == 'rest'
        ? 'Rest day today'
        : 'Active recovery today';
  }

  ScheduledWorkoutPreview? _current() {
    final enrollment = controller.enrollment;
    final day = controller.nextWorkout();
    if (enrollment == null || day == null) return null;
    final definition = day.definition;
    final snapshot = definition.routineSnapshot;
    final routineId = definition.routineId;
    if (snapshot == null || routineId == null) return null;
    final routine = PublishedRoutine.fromDocument(
        routineId, Map<String, dynamic>.from(snapshot));
    return ScheduledWorkoutPreview(
      routine: routine,
      day: definition.routineDay,
      dayKey: day.key,
      enrollmentId: enrollment.id,
      date: day.date,
      snapshot: canonicalProgramJson(snapshot),
      inProgress: enrollment.progress[day.key]?.attemptId != null,
      attempt: controller.attempt(day.key),
    );
  }

  Future<ScheduledWorkoutPreview?> refresh() async {
    await controller.open();
    if (!controller.authorized) throw StateError('Member account changed');
    return _current();
  }

  Future<ProgramRoutineLaunch> start(ScheduledWorkoutPreview shown) async {
    final current = await refresh();
    if (current == null ||
        current.enrollmentId != shown.enrollmentId ||
        current.dayKey != shown.dayKey ||
        current.date != shown.date ||
        current.day != shown.day ||
        current.snapshot != shown.snapshot ||
        current.inProgress != shown.inProgress) {
      throw StateError('The program has changed; review it before starting.');
    }
    return controller.begin(shown.dayKey);
  }
}
