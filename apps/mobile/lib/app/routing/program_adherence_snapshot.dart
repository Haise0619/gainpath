import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/program_enrollment.dart';
import '../../features/workout/domain/routine_journey.dart';
import '../../features/workout/application/workout_program_controller.dart';
import '../../features/analytics/domain/program_adherence.dart';
export '../../features/analytics/domain/program_adherence.dart';

/// Reuses the journey's exact linked-attempt validation without selecting or
/// saving enrollment state. All controllers operate on immutable read snapshots.
Future<List<ProgramAdherenceSummary>> loadProgramAdherence({
  required SessionScope scope,
  required SessionScope? Function() activeScope,
  required ProgramEnrollmentStore programStore,
  required RoutineJourneyStore routineStore,
  required DateTime now,
}) async {
  void guard() {
    if (activeScope() != scope ||
        programStore.scope != scope ||
        routineStore.scope != scope) {
      throw StateError('Program analytics account changed');
    }
  }

  guard();
  final journal = await programStore.load();
  guard();
  final checkpoints = await routineStore.load();
  guard();
  final result = <ProgramAdherenceSummary>[];
  for (final enrollment in journal.enrollments) {
    final controller = WorkoutProgramController(
        scope: scope,
        activeScope: activeScope,
        store: _SnapshotPrograms(
            scope,
            ProgramJournal(
                revision: journal.revision,
                activeId: enrollment.id,
                enrollments: [enrollment])),
        routineStore: _SnapshotRoutines(scope, checkpoints),
        newId: () => throw UnsupportedError('Read-only analytics'));
    try {
      await controller.open();
      guard();
      final seen = <String>{};
      final days = <ProgramAdherenceDay>[];
      for (final day in enrollment.schedule) {
        final link = enrollment.progress[day.key];
        final attempt = controller.attempt(day.key);
        final unique = link?.attemptId == null || seen.add(link!.attemptId!);
        final status = day.definition.kind != 'workout'
            ? ProgramAdherenceStatus.rest
            : unique && attempt?.isComplete == true
                ? ProgramAdherenceStatus.completed
                : link?.skipped == true
                    ? ProgramAdherenceStatus.skipped
                    : unique && attempt != null
                        ? ProgramAdherenceStatus.partial
                        : ProgramAdherenceStatus.pending;
        days.add(ProgramAdherenceDay(
            day.key, day.date, day.definition.week, status));
      }
      days.sort((a, b) => a.date.compareTo(b.date));
      result.add(ProgramAdherenceSummary(enrollment, days,
          isCurrent: enrollment.id == journal.activeId));
    } finally {
      controller.dispose();
    }
  }
  guard();
  return List.unmodifiable(result);
}

class _SnapshotPrograms implements ProgramEnrollmentStore {
  _SnapshotPrograms(this.scope, this.journal);
  @override
  final SessionScope scope;
  final ProgramJournal journal;
  @override
  Future<ProgramJournal> load() async => journal;
  @override
  Future<void> save(ProgramJournal journal, {required int expectedRevision}) =>
      Future.error(UnsupportedError('Read-only analytics'));
}

class _SnapshotRoutines implements RoutineJourneyStore {
  _SnapshotRoutines(this.scope, this.checkpoints);
  @override
  final SessionScope scope;
  final List<RoutineCheckpoint> checkpoints;
  @override
  Future<List<RoutineCheckpoint>> load() async => checkpoints;
  @override
  Future<void> save(RoutineCheckpoint checkpoint) =>
      Future.error(UnsupportedError('Read-only analytics'));
}
