import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/routing/program_adherence_snapshot.dart';
import 'package:gainpath_mobile/features/workout/application/workout_program_controller.dart';
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'routine_journey_controller_test.dart' show MemoryJourneyStore;
import 'workout_program_controller_test.dart'
    show MemoryProgramStore, programFixture;

void main() {
  test('partial, completion, repeated loads and reschedule preserve one slot',
      () async {
    final scope = SessionScope(userId: 'm', organizationId: 'g');
    final store = MemoryProgramStore(scope),
        routines = MemoryJourneyStore(scope);
    final program = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: store,
        routineStore: routines,
        newId: () => 'one');
    await program.open();
    await program
        .enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final key = program.enrollment!.schedule.first.key;
    await program.reschedule(key, DateTime.utc(2026, 11, 1));
    final launch = await program.begin(key);
    final workouts = WorkoutSessionRepository(
        scope: scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        activeScope: () => scope,
        uploadGateway: UnavailableWorkoutUploadGateway());
    final routine = RoutineJourneyController(
        scope: scope,
        activeScope: () => scope,
        routine: launch.routine,
        store: routines,
        workouts: workouts,
        newId: () => 'unused');
    await routine.openProgramAttempt(launch.attemptId, 1);
    await routine.markManualSet(0);
    Future<ProgramAdherenceSummary> read() async => (await loadProgramAdherence(
            scope: scope,
            activeScope: () => scope,
            programStore: store,
            routineStore: routines,
            now: DateTime.utc(2026, 11, 10)))
        .single;
    var summary = await read();
    expect(summary.count(ProgramAdherenceStatus.partial), 1);
    expect(summary.days.firstWhere((d) => d.key == key).date,
        DateTime.utc(2026, 11, 1));
    await routine.markManualSet(0);
    await routine.finish();
    summary = await read();
    expect(summary.completed, 1);
    expect((await read()).completed, 1);
    expect(summary.scheduled, 12);
    routine.dispose();
    program.dispose();
    workouts.dispose();
  });
}
