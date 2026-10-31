import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart' show WorkoutProgram;
import 'package:gainpath_mobile/features/workout/application/workout_program_controller.dart';
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'workout_program_controller_test.dart'
    show MemoryProgramStore, programFixture;
import 'routine_journey_controller_test.dart' show MemoryJourneyStore;
import 'lateral_raise_metrics_test.dart' show lateralRaiseMetrics;

void main() {
  test(
      'Program lateral raise day reconciles measured reps and advances without manual completion',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final json = programFixture().toJson();
    for (final day in json['days'] as List) {
      if (day['kind'] == 'workout') {
        final exercise = day['routineSnapshot']['exercises'][0] as Map;
        exercise['exerciseId'] = 'standing-lateral-raise-front-v1';
        exercise['name'] = 'Standing Lateral Raise';
        exercise['sets'] = 2;
        exercise['reps'] = 1;
        exercise['restSeconds'] = 45;
      }
    }
    final store = MemoryProgramStore(scope),
        routines = MemoryJourneyStore(scope);
    var sequence = 0;
    final program = WorkoutProgramController(
        scope: scope,
        activeScope: () => scope,
        store: store,
        routineStore: routines,
        newId: () => 'program-${sequence++}');
    final workouts = WorkoutSessionRepository(
        scope: scope,
        activeScope: () => scope,
        store: InMemoryWorkoutSessionStore(scope: scope),
        uploadGateway: UnavailableWorkoutUploadGateway());
    addTearDown(program.dispose);
    addTearDown(workouts.dispose);
    await program.open();
    await program.enroll(
        WorkoutProgram.fromJson(json), DateTime.utc(2026, 11, 2), {1, 3, 5});
    final key = program.enrollment!.schedule.first.key;
    final launch = await program.begin(key);
    final journey = RoutineJourneyController(
        scope: scope,
        activeScope: () => scope,
        routine: launch.routine,
        store: routines,
        workouts: workouts,
        newId: () => 'capture-${sequence++}');
    addTearDown(journey.dispose);
    await journey.openProgramAttempt(launch.attemptId, 1);
    expect(
        journey.targetsFor(0), '2 sets · 1 reps per set · both arms together');
    final capture = await journey.prepareCapture(0);
    final at = DateTime.utc(2026, 11, 2);
    final metrics = lateralRaiseMetrics()
      ..['publishedRoutineId'] = launch.routine.id;
    // Synthetic test input to the real persistence/reconciliation path.
    final summary = WorkoutSessionSummary(
        sessionId: capture,
        userId: scope.userId,
        organizationId: scope.organizationId,
        exerciseId: 'standing-lateral-raise-front-v1',
        repetitions: 2,
        accuracy: 0,
        startedAt: at,
        endedAt: at.add(const Duration(seconds: 20)),
        provenance: WorkoutProvenance.realCamera,
        poseMetrics: WorkoutPoseMetrics.fromJson(metrics));
    await workouts.saveLocal(summary);
    await journey.refresh(completeRoutine: true);
    await program.open();
    expect(program.completedDays(1), 1);
    expect(program.attempt(key)!.fullRepetitions, 2);
    expect(program.attempt(key)!.selfReportedSets, 0);
    expect(program.nextWorkout(afterKey: key)!.key, isNot(key));
    expect(summary.isEligibleForRealUpload, false);
  });
}
