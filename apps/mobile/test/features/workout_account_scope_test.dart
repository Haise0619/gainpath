import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/infrastructure/local/file_workout_session_store.dart';

WorkoutSessionSummary summary(SessionScope scope, String id) =>
    WorkoutSessionSummary(
      userId: scope.userId,
      organizationId: scope.organizationId,
      sessionId: id,
      exerciseId: 'squat',
      repetitions: 4,
      accuracy: 85,
      startedAt: DateTime.utc(2026),
      endedAt: DateTime.utc(2026, 1, 1, 0, 1),
    );

class _DelayedUpload implements WorkoutUploadGateway {
  final started = Completer<void>();
  final release = Completer<void>();
  int calls = 0;
  @override
  Future<WorkoutUploadReceipt> upload(WorkoutSessionSummary summary) async {
    calls++;
    if (!started.isCompleted) started.complete();
    await release.future;
    return WorkoutUploadReceipt(
        acceptedAt: DateTime.utc(2026), serverReference: summary.sessionId);
  }
}

void main() {
  final a = SessionScope(userId: 'user/a', organizationId: 'org/one');
  final b = SessionScope(userId: 'user_a', organizationId: 'org/one');
  final c = SessionScope(userId: 'user/a', organizationId: 'org_one');

  test('durable histories isolate original user and organization IDs',
      () async {
    final directory = await Directory.systemTemp.createTemp('gainpath-scope-');
    addTearDown(() => directory.delete(recursive: true));
    WorkoutSessionRepository repository(SessionScope scope) =>
        WorkoutSessionRepository(
          scope: scope,
          store: FileWorkoutSessionStore(directory: directory, scope: scope),
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => scope,
        );
    await repository(a).saveLocal(summary(a, 'same-id'));
    expect(await repository(b).loadHistory(), isEmpty);
    expect(await repository(c).loadHistory(), isEmpty);
    expect(
        await repository(
                SessionScope(userId: 'USER/a', organizationId: 'org/one'))
            .loadHistory(),
        isEmpty);
    await repository(b).saveLocal(summary(b, 'same-id'));
    final restored = (await repository(a).loadHistory()).single.summary;
    expect(restored.userId, 'user/a');
    expect(restored.organizationId, 'org/one');
    await expectLater(
        repository(a).saveLocal(summary(b, 'wrong-owner')), throwsStateError);
  });

  test(
      'two file-store instances serialize concurrent saves and acknowledgements',
      () async {
    final directory = await Directory.systemTemp.createTemp('gainpath-race-');
    addTearDown(() => directory.delete(recursive: true));
    final gateway = _DelayedUpload();
    WorkoutSessionRepository repository() => WorkoutSessionRepository(
        scope: a,
        store: FileWorkoutSessionStore(directory: directory, scope: a),
        uploadGateway: gateway,
        activeScope: () => a);
    final first = repository();
    final second = repository();
    await first.saveLocal(summary(a, 'one'));
    final syncing = first.syncPending();
    await gateway.started.future;
    final saving = second.saveLocal(summary(a, 'two'));
    final duplicateSync = second.syncPending();
    gateway.release.complete();
    await Future.wait([syncing, saving, duplicateSync]);
    await second.syncPending();
    expect(gateway.calls, 2);
    expect(await repository().loadHistory(), hasLength(2));
    expect(
        (await first.loadHistory())
            .every((record) => record.status == WorkoutSyncStatus.accepted),
        isTrue);
    await first.saveLocal(summary(a, 'one'));
    expect(
        (await first.loadHistory())
            .every((record) => record.status == WorkoutSyncStatus.accepted),
        isTrue);
  });

  test('account switch during upload leaves original outbox pending', () async {
    SessionScope? active = a;
    final store = InMemoryWorkoutSessionStore(scope: a);
    final gateway = _DelayedUpload();
    final repository = WorkoutSessionRepository(
        scope: a,
        store: store,
        uploadGateway: gateway,
        activeScope: () => active);
    await repository.saveLocal(summary(a, 'one'));
    final sync = repository.syncPending();
    final fails = expectLater(sync, throwsStateError);
    await gateway.started.future;
    active = b;
    gateway.release.complete();
    await fails;
    expect((await store.read()).single.status, WorkoutSyncStatus.pending);
    await expectLater(repository.loadHistory(), throwsStateError);
    await expectLater(repository.syncPending(), throwsStateError);
    active = a;
    repository.dispose();
    await expectLater(repository.syncPending(), throwsStateError);
    expect(gateway.calls, 1);
  });

  test('a conflicting save cannot overwrite an existing completed workout',
      () async {
    final repository = InMemoryWorkoutSessionRepository(scope: a);
    final original = summary(a, 'one');
    await repository.saveLocal(original);
    final conflicting = WorkoutSessionSummary(
        userId: a.userId,
        organizationId: a.organizationId,
        sessionId: 'one',
        exerciseId: 'squat',
        repetitions: 999,
        accuracy: 85,
        startedAt: DateTime.utc(2026),
        endedAt: DateTime.utc(2026, 1, 1, 0, 1));
    await expectLater(repository.saveLocal(conflicting), throwsStateError);
    expect((await repository.loadHistory()).single.summary, original);
  });
}
