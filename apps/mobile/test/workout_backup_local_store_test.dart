import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/data/stored_workout_backup_local.dart';
import 'package:gainpath_mobile/features/workout/application/workout_backup_coordinator.dart';
import 'workout_backup_test.dart' as backup;
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'package:gainpath_mobile/infrastructure/local/file_routine_journey_store.dart';
import 'package:gainpath_mobile/infrastructure/local/file_workout_backup_store.dart';
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'routine_journey_controller_test.dart' as fixture;

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  late Directory dir;
  late FileRoutineJourneyStore journeys;
  late InMemoryWorkoutSessionStore workouts;
  SessionScope? active;
  StoredWorkoutBackupLocal local() => StoredWorkoutBackupLocal(
      scope: scope,
      activeScope: () => active,
      workouts: workouts,
      routines: journeys);
  setUp(() async {
    active = scope;
    dir = await Directory.systemTemp.createTemp('backup-local-');
    journeys = FileRoutineJourneyStore(directory: dir, scope: scope);
    workouts = InMemoryWorkoutSessionStore(scope: scope);
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test(
      'restored exercise summary remains unaccepted and duplicate restore is harmless',
      () async {
    final row = WorkoutBackupRecord.session(fixture.measured(scope, 's1'));
    expect(await local().restore(row, null), true);
    expect(await local().restore(row, null), true);
    final saved = (await workouts.read()).single;
    expect(saved.status, WorkoutSyncStatus.pending);
    expect(saved.acceptedAt, isNull);
    expect(saved.summary.sessionId, 's1');
  });
  test('routine restore preserves unknown/local newer/conflicting revisions',
      () async {
    var id = 0;
    final repo = WorkoutSessionRepository(
        scope: scope,
        store: workouts,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    final c = RoutineJourneyController(
        scope: scope,
        activeScope: () => active,
        routine: fixture.routineFixture(),
        store: journeys,
        workouts: repo,
        newId: () => 'r-${id++}');
    await c.openDay(1);
    final older = WorkoutBackupRecord.routine(c.checkpoint!);
    await c.markManualSet(1);
    final newer = WorkoutBackupRecord.routine(c.checkpoint!);
    expect(await local().restore(older, newer.digest), false);
    expect((await journeys.load()).single.manualSets[1], 1);
    expect(await local().restore(newer, '0' * 64), false);
    final copy = FileRoutineJourneyStore(
        directory: Directory('${dir.path}/new-device'), scope: scope);
    final restored = StoredWorkoutBackupLocal(
        scope: scope,
        activeScope: () => active,
        workouts: workouts,
        routines: copy);
    expect(await restored.restore(newer, null), true);
    expect(WorkoutBackupRecord.routine((await copy.load()).single).digest,
        newer.digest);
    c.dispose();
  });
  test(
      'backup opt-in and conflict metadata survive reopening and isolate account paths',
      () async {
    final store = FileWorkoutBackupStore(directory: dir, scope: scope);
    final state = BackupState(
        enabled: true,
        baselines: {'session-s1': 'a' * 64},
        conflicts: {'routine-r1': 'b' * 64},
        lastError: 'unavailable');
    await store.write(state);
    final reopened = FileWorkoutBackupStore(directory: dir, scope: scope);
    expect((await reopened.read()).toJson(), state.toJson());
    final other = FileWorkoutBackupStore(
        directory: dir,
        scope: SessionScope(userId: 'other', organizationId: 'gainpath'));
    expect((await other.read()).enabled, false);
  });
  test('signed out account cannot restore', () async {
    active = null;
    await expectLater(
        local().restore(
            WorkoutBackupRecord.session(fixture.measured(scope, 's1')), null),
        throwsStateError);
    expect(await workouts.read(), isEmpty);
  });
  test(
      'completed routine restores on another device with linked measured history',
      () async {
    var sequence = 0;
    final repository = WorkoutSessionRepository(
        scope: scope,
        store: workouts,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    final c = RoutineJourneyController(
        scope: scope,
        activeScope: () => active,
        routine: fixture.routineFixture(),
        store: journeys,
        workouts: repository,
        newId: () => 'restore-${sequence++}');
    await c.openDay(1);
    final capture = await c.prepareCapture(0);
    await repository.saveLocal(fixture.measured(scope, capture));
    await c.refresh();
    await c.markManualSet(1);
    await c.markManualSet(1);
    await c.finish();
    final remote = backup.Remote();
    for (final row in await local().read()) {
      remote.records[row.key] = row;
    }
    final otherWorkouts = InMemoryWorkoutSessionStore(scope: scope);
    final otherJourneys = FileRoutineJourneyStore(
        directory: Directory('${dir.path}/other-device'), scope: scope);
    final otherLocal = StoredWorkoutBackupLocal(
        scope: scope,
        activeScope: () => active,
        workouts: otherWorkouts,
        routines: otherJourneys);
    final coordinator = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => active,
        local: otherLocal,
        gateway: remote,
        store: backup.Metadata(scope));
    await coordinator.load();
    await coordinator.setEnabled(true);
    final result = (await otherJourneys.load()).single;
    expect(result.id, c.checkpoint!.id);
    expect(result.attempt!.isComplete, true);
    expect(result.attempt!.selfReportedSets, 2);
    expect(result.attempt!.fullRepetitions, 2);
    expect(
        (await otherWorkouts.read()).single.status, WorkoutSyncStatus.pending);
    expect(coordinator.state.lastError, isNull);
    coordinator.dispose();
    c.dispose();
  });
  test('conflicting immutable exercise prevents its linked routine upload',
      () async {
    var sequence = 0;
    final repository = WorkoutSessionRepository(
        scope: scope,
        store: workouts,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    final c = RoutineJourneyController(
        scope: scope,
        activeScope: () => active,
        routine: fixture.routineFixture(),
        store: journeys,
        workouts: repository,
        newId: () => 'conflict-${sequence++}');
    await c.openDay(1);
    final capture = await c.prepareCapture(0);
    await repository.saveLocal(fixture.measured(scope, capture));
    await c.refresh();
    final remote = backup.Remote();
    final conflicting =
        WorkoutBackupRecord.session(fixture.measured(scope, capture, reps: 1));
    remote.records[conflicting.key] = conflicting;
    final sync = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => active,
        local: local(),
        gateway: remote,
        store: backup.Metadata(scope));
    await sync.load();
    await sync.setEnabled(true);
    expect(remote.records.keys.where((key) => key.startsWith('routine-')),
        isEmpty);
    expect(sync.statusFor(WorkoutBackupRecord.routine(c.checkpoint!)),
        BackupRecordStatus.conflict);
    sync.dispose();
    c.dispose();
  });
}
