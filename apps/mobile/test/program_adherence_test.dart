import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/app/routing/program_adherence_snapshot.dart';
import 'package:gainpath_mobile/features/workout/domain/program_enrollment.dart';
import 'routine_journey_controller_test.dart' show MemoryJourneyStore;
import 'workout_program_controller_test.dart'
    show MemoryProgramStore, programFixture;

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  test('summary reads scheduled days without modifying the journal', () async {
    final store = MemoryProgramStore(scope);
    final p = programFixture();
    final schedule =
        ProgramSchedule.create(p, DateTime.utc(2026, 11, 2), {1, 3, 5});
    store.journal =
        ProgramJournal(revision: 4, activeId: 'enrollment', enrollments: [
      ProgramEnrollment(
          id: 'enrollment',
          program: p,
          schedule: schedule,
          progress: {
            schedule.first.key: const ProgramDayProgress(skipped: true)
          })
    ]);
    final result = await loadProgramAdherence(
        scope: scope,
        activeScope: () => scope,
        programStore: store,
        routineStore: MemoryJourneyStore(scope),
        now: DateTime.utc(2026, 11, 10));
    expect(result.single.isCurrent, isTrue);
    expect(result.single.scheduled, 12);
    expect(result.single.skipped, 1);
    expect(result.single.completed, 0);
    expect(result.single.weeks.length, 4);
    expect(store.journal.revision, 4);
  });
  test('changed account refuses journal', () async {
    await expectLater(
        loadProgramAdherence(
            scope: scope,
            activeScope: () => null,
            programStore: MemoryProgramStore(scope),
            routineStore: MemoryJourneyStore(scope),
            now: DateTime.utc(2026, 11, 2)),
        throwsStateError);
  });
}
