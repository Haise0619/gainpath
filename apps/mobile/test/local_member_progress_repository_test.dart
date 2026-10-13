import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/analytics/data/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_contract.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'package:gainpath_mobile/infrastructure/local/file_workout_session_store.dart';
import 'package:gainpath_mobile/infrastructure/local/file_real_workout_sync_store.dart';
import 'package:gainpath_mobile/app/di/local_member_progress_factory.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
WorkoutSessionSummary measured(String id, {int reps = 4, double? score = 80}) {
  final start = DateTime.utc(2026, 10, 12, 2);
  return WorkoutSessionSummary(
    userId: scope.userId,
    organizationId: scope.organizationId,
    sessionId: id,
    exerciseId: 'squat',
    repetitions: reps,
    accuracy: 99,
    startedAt: start,
    endedAt: start.add(const Duration(seconds: 10)),
    provenance: WorkoutProvenance.realCamera,
    poseMetrics: WorkoutPoseMetrics(
        partialRepetitions: 1,
        trackedDurationMicros: 6000000,
        rejectedDurationMicros: 2000000,
        formScorePercent: score,
        scoringVersion: 'bodyweight-squat-side-v1',
        detectorId: 'blazepose-tflite',
        detectorVersion: 'v1',
        cameraView: 'side',
        consentVersion: workoutConsentVersion,
        consentedAt: start,
        publishedRoutineId: 'routine'),
  );
}

RealWorkoutSubmission submission(WorkoutSessionSummary s, {int? reps}) =>
    RealWorkoutSubmission.fromJson({
      'schemaVersion': 2,
      'requestId': 'request-${s.sessionId}',
      'organizationId': s.organizationId,
      'memberId': s.userId,
      'sessionId': s.sessionId,
      'exerciseId': s.exerciseId,
      'publishedRoutineId': 'routine',
      'provenance': 'real_camera',
      'cameraView': 'side',
      'detectorId': 'blazepose-tflite',
      'detectorVersion': 'v1',
      'scoringVersion': 'bodyweight-squat-side-v1',
      'consentVersion': workoutConsentVersion,
      'consentAcknowledgementId': 'ack',
      'startedAtMillis': s.startedAt.millisecondsSinceEpoch,
      'endedAtMillis': s.endedAt.millisecondsSinceEpoch,
      'repetitions': reps ?? s.repetitions,
      'formScorePercent': s.formScorePercent,
      'trackedDurationMillis': 6000,
      'rejectedDurationMillis': 2000,
    });
WorkoutAcceptance receipt(RealWorkoutSubmission s) =>
    WorkoutAcceptance.fromJson({
      'schemaVersion': 2,
      'requestId': s.toJson()['requestId'],
      'sessionId': s.sessionId,
      'status': 'accepted',
      'acceptedAtMillis': s.toJson()['endedAtMillis'],
    });

class DelayedStore extends InMemoryWorkoutSessionStore {
  DelayedStore() : super(scope: scope);
  final release = Completer<void>();
  @override
  Future<List<WorkoutSessionRecord>> read() async {
    await release.future;
    return super.read();
  }
}

class BrokenSyncStore extends MemoryRealWorkoutSyncStore {
  BrokenSyncStore() : super(scope: scope);
  @override
  Future<RealWorkoutSyncState> read() =>
      Future.error(const FormatException('corrupt'));
}

class RawStore extends InMemoryWorkoutSessionStore {
  RawStore(this.records) : super(scope: scope);
  final List<WorkoutSessionRecord> records;
  @override
  Future<List<WorkoutSessionRecord>> read() async => records;
}

void main() {
  test('incomplete measured rows are excluded with a visible warning',
      () async {
    final s = measured('unfinished');
    final unfinished = WorkoutSessionSummary(
        sessionId: s.sessionId,
        userId: s.userId,
        organizationId: s.organizationId,
        exerciseId: s.exerciseId,
        repetitions: s.repetitions,
        accuracy: s.accuracy,
        startedAt: s.startedAt,
        endedAt: s.startedAt,
        provenance: s.provenance,
        poseMetrics: s.poseMetrics);
    final result = await StoredLocalMemberProgressRepository(
        scope: scope,
        workoutStore: RawStore([
          WorkoutSessionRecord(
              summary: unfinished, status: WorkoutSyncStatus.pending)
        ]),
        syncStore: MemoryRealWorkoutSyncStore(scope: scope),
        activeScope: () => scope).load();
    expect(result.records, isEmpty);
    expect(result.summaries, isEmpty);
    expect(result.warnings, isNotEmpty);
  });
  test('capture intent means pending only with matching prior consent',
      () async {
    final summaries = [measured('pending-intent'), measured('late-intent')];
    final store = InMemoryWorkoutSessionStore(scope: scope);
    await store.write([
      for (final s in summaries)
        WorkoutSessionRecord(summary: s, status: WorkoutSyncStatus.pending)
    ]);
    WorkoutConsentAcknowledgement ack(int time) =>
        WorkoutConsentAcknowledgement.fromJson({
          'schemaVersion': 1,
          'requestId': 'consent',
          'organizationId': scope.organizationId,
          'memberId': scope.userId,
          'consentVersion': workoutConsentVersion,
          'acknowledgementId': 'ack',
          'acknowledgedAtMillis': time
        });
    final sync = MemoryRealWorkoutSyncStore(scope: scope);
    await sync.write(RealWorkoutSyncState(captureIntents: {
      summaries[0].sessionId:
          ack(summaries[0].startedAt.millisecondsSinceEpoch),
      summaries[1].sessionId: ack(summaries[1].endedAt.millisecondsSinceEpoch)
    }));
    final result = await StoredLocalMemberProgressRepository(
        scope: scope,
        workoutStore: store,
        syncStore: sync,
        activeScope: () => scope).load();
    expect(result.records.map((r) => r.status),
        [LocalWorkoutRecordStatus.pending, LocalWorkoutRecordStatus.unknown]);
    expect((await sync.read()).entries, isEmpty);
    expect((await sync.read()).captureIntents.length, 2);
  });
  test('failed status-store creation does not hide readable local measurements',
      () async {
    final store = InMemoryWorkoutSessionStore(scope: scope);
    await store.write([
      WorkoutSessionRecord(
          summary: measured('local'), status: WorkoutSyncStatus.pending)
    ]);
    final repo = await createLocalMemberProgressRepository(scope, () => scope,
        storeFactory: (_) async => store,
        syncStoreFactory: (_) => Future.error(StateError('unavailable')));
    final result = await repo.load();
    expect(result.records.single.repetitions, 4);
    expect(result.records.single.status, LocalWorkoutRecordStatus.unknown);
    expect(result.warnings, isNotEmpty);
  });
  test('reads only measured real records and never substitutes legacy accuracy',
      () async {
    final real = measured('real', score: null);
    final simulated = WorkoutSessionSummary(
        sessionId: 'demo',
        exerciseId: 'squat',
        userId: scope.userId,
        organizationId: scope.organizationId,
        repetitions: 100,
        accuracy: 100,
        startedAt: real.startedAt,
        endedAt: real.endedAt);
    final store = InMemoryWorkoutSessionStore(scope: scope);
    await store.write([
      for (final s in [real, simulated])
        WorkoutSessionRecord(summary: s, status: WorkoutSyncStatus.pending)
    ]);
    final repo = StoredLocalMemberProgressRepository(
        scope: scope,
        workoutStore: store,
        syncStore: MemoryRealWorkoutSyncStore(scope: scope),
        activeScope: () => scope);
    final result = await repo.load();
    expect(result.records.map((e) => e.sessionId), ['real']);
    expect(result.records.single.formScorePercent, isNull);
    expect(result.records.single.status, LocalWorkoutRecordStatus.localOnly);
  });
  test('maps matching pending retry rejected and durable accepted receipts',
      () async {
    final states = [
      RealWorkoutSyncStatus.pending,
      RealWorkoutSyncStatus.retryable,
      RealWorkoutSyncStatus.rejected,
      RealWorkoutSyncStatus.accepted
    ];
    final summaries = [for (final state in states) measured(state.name)];
    final store = InMemoryWorkoutSessionStore(scope: scope);
    await store.write([
      for (final s in summaries)
        WorkoutSessionRecord(summary: s, status: WorkoutSyncStatus.pending)
    ]);
    final sync = MemoryRealWorkoutSyncStore(scope: scope);
    await sync.write(RealWorkoutSyncState(entries: [
      for (var i = 0; i < states.length; i++)
        RealWorkoutSyncEntry(
            submission: submission(summaries[i]),
            status: states[i],
            failureCode: i == 1
                ? 'unavailable'
                : i == 2
                    ? 'failed-precondition'
                    : null,
            acceptance: i == 3 ? receipt(submission(summaries[i])) : null)
    ]));
    final result = await StoredLocalMemberProgressRepository(
        scope: scope,
        workoutStore: store,
        syncStore: sync,
        activeScope: () => scope).load();
    expect(result.records.map((e) => e.status), [
      LocalWorkoutRecordStatus.pending,
      LocalWorkoutRecordStatus.retryable,
      LocalWorkoutRecordStatus.rejected,
      LocalWorkoutRecordStatus.accepted
    ]);
    expect(result.records.last.acceptedAt, summaries.last.endedAt);
  });
  test(
      'same session id with conflicting submission never grants accepted status',
      () async {
    final s = measured('one');
    final wrong = submission(s, reps: 9);
    final store = InMemoryWorkoutSessionStore(scope: scope);
    await store.write(
        [WorkoutSessionRecord(summary: s, status: WorkoutSyncStatus.pending)]);
    final sync = MemoryRealWorkoutSyncStore(scope: scope);
    await sync.write(RealWorkoutSyncState(entries: [
      RealWorkoutSyncEntry(
          submission: wrong,
          status: RealWorkoutSyncStatus.accepted,
          acceptance: receipt(wrong))
    ]));
    final result = await StoredLocalMemberProgressRepository(
        scope: scope,
        workoutStore: store,
        syncStore: sync,
        activeScope: () => scope).load();
    expect(result.records.single.status, LocalWorkoutRecordStatus.unknown);
    expect(result.records.single.acceptedAt, isNull);
    expect(result.warnings, isNotEmpty);
  });
  test(
      'unreadable sync metadata retains local counts with unknown upload state',
      () async {
    final store = InMemoryWorkoutSessionStore(scope: scope);
    await store.write([
      WorkoutSessionRecord(
          summary: measured('one'), status: WorkoutSyncStatus.pending)
    ]);
    final result = await StoredLocalMemberProgressRepository(
        scope: scope,
        workoutStore: store,
        syncStore: BrokenSyncStore(),
        activeScope: () => scope).load();
    expect(result.records.single.repetitions, 4);
    expect(result.records.single.status, LocalWorkoutRecordStatus.unknown);
    expect(result.warnings, isNotEmpty);
  });
  test('account replacement during read cannot publish prior account history',
      () async {
    SessionScope? active = scope;
    final store = DelayedStore();
    final pending = StoredLocalMemberProgressRepository(
        scope: scope,
        workoutStore: store,
        syncStore: MemoryRealWorkoutSyncStore(scope: scope),
        activeScope: () => active).load();
    final assertion = expectLater(pending, throwsStateError);
    active = SessionScope(userId: 'next', organizationId: 'gainpath');
    store.release.complete();
    await assertion;
  });
  test('reads durable stores after restart without mutating records or outbox',
      () async {
    final dir = await Directory.systemTemp.createTemp('member-progress-');
    try {
      final store = FileWorkoutSessionStore(directory: dir, scope: scope);
      await store.exclusive(() => store.write([
            WorkoutSessionRecord(
                summary: measured('disk'), status: WorkoutSyncStatus.pending)
          ]));
      final sync = FileRealWorkoutSyncStore(directory: dir, scope: scope);
      await sync.exclusive(() => sync.write(RealWorkoutSyncState()));
      final before = {
        for (final f in dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.json')))
          f.path: await f.readAsString()
      };
      final result = await StoredLocalMemberProgressRepository(
          scope: scope,
          workoutStore: FileWorkoutSessionStore(directory: dir, scope: scope),
          syncStore: FileRealWorkoutSyncStore(directory: dir, scope: scope),
          activeScope: () => scope).load();
      expect(result.records.single.sessionId, 'disk');
      for (final entry in before.entries) {
        expect(await File(entry.key).readAsString(), entry.value);
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
