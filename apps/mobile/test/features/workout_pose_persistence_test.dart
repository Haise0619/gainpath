import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/infrastructure/local/file_workout_session_store.dart';

final owner = SessionScope(userId: 'member-a', organizationId: 'gainpath');
final start = DateTime.utc(2026, 10, 8, 12);

WorkoutSessionSummary measured(
    {String id = 'real-session',
    SessionScope? scope,
    double? score = 88.5,
    int full = 3,
    int partial = 1,
    Map<String, WorkoutDeviationAggregate>? deviations}) {
  final account = scope ?? owner;
  return WorkoutSessionSummary(
      userId: account.userId,
      organizationId: account.organizationId,
      sessionId: id,
      exerciseId: 'F3b8xIr8ynBDd3gEICKX',
      repetitions: full,
      accuracy: score?.round() ?? 0,
      startedAt: start,
      endedAt: start.add(const Duration(seconds: 20)),
      provenance: WorkoutProvenance.realCamera,
      poseMetrics: WorkoutPoseMetrics(
          partialRepetitions: partial,
          trackedDurationMicros: 12000000,
          rejectedDurationMicros: 3000000,
          formScorePercent: score,
          scoringVersion: 'bodyweight-squat-side-v1',
          detectorId: 'blazepose-tflite',
          detectorVersion: 'mediapipe-full-e9a5c5cb-det-9ba9dd3d',
          cameraView: 'side',
          consentVersion: 'pose-local-summary-v1',
          consentedAt: start.subtract(const Duration(seconds: 2)),
          publishedRoutineId: 'routine-a',
          deviations: deviations ??
              {
                'trunkLean':
                    WorkoutDeviationAggregate(count: 1, maximumDegrees: 7.5),
              }));
}

class UploadSpy implements DemoWorkoutUploadGateway {
  int calls = 0;
  @override
  Future<WorkoutUploadReceipt> upload(WorkoutSessionSummary summary) async {
    calls++;
    return WorkoutUploadReceipt(acceptedAt: start, serverReference: 'demo');
  }
}

/// Models both ordinary failed write and a write committed before its response
/// fails. The caller must retry the exact stable summary in either case.
class FailOnceStore implements WorkoutSessionStore {
  FailOnceStore(this.delegate, {required this.afterCommit});
  final WorkoutSessionStore delegate;
  final bool afterCommit;
  bool fail = true;
  @override
  SessionScope get scope => delegate.scope;
  @override
  Future<T> exclusive<T>(Future<T> Function() action) =>
      delegate.exclusive(action);
  @override
  Future<List<WorkoutSessionRecord>> read() => delegate.read();
  @override
  Future<void> write(List<WorkoutSessionRecord> records) async {
    if (afterCommit || !fail) await delegate.write(records);
    if (fail) {
      fail = false;
      throw const FileSystemException('Interrupted write');
    }
  }
}

void main() {
  test('measured summary round-trips bounded nullable metrics and provenance',
      () {
    final summary = measured();
    final restored = WorkoutSessionSummary.fromJson(Map<String, Object?>.from(
        jsonDecode(jsonEncode(summary.toJson())) as Map));
    expect(restored, summary);
    expect(restored.hashCode, summary.hashCode);
    expect(summary.toJson()['summarySchemaVersion'], 3);
    expect(restored.formScorePercent, 88.5);
    expect(restored.repetitions, 3);
    expect(restored.partialRepetitions, 1);
    expect(restored.trackedDurationMicros, 12000000);
    expect(restored.poseMetrics!.detectorVersion,
        'mediapipe-full-e9a5c5cb-det-9ba9dd3d');
    expect(restored.poseMetrics!.deviations['trunkLean']!.maximumDegrees, 7.5);
    expect(restored.isEligibleForRealUpload, false);
    final unscored = measured(score: null, full: 0, partial: 0, deviations: {});
    expect(WorkoutSessionSummary.fromJson(unscored.toJson()).formScorePercent,
        isNull);
  });

  test('metrics freeze caller aggregates and reject unsupported/unbounded data',
      () {
    final aggregates = {
      'trunkLean': WorkoutDeviationAggregate(count: 1, maximumDegrees: 7)
    };
    final summary = measured(deviations: aggregates);
    aggregates.clear();
    expect(summary.poseMetrics!.deviations, hasLength(1));
    expect(
        () => summary.poseMetrics!.deviations.clear(), throwsUnsupportedError);
    expect(
        () => measured(deviations: {
              'kneeSafety':
                  WorkoutDeviationAggregate(count: 1, maximumDegrees: 10),
            }),
        throwsFormatException);
    expect(() => WorkoutDeviationAggregate(count: -1, maximumDegrees: 1),
        throwsFormatException);
    expect(
        () => WorkoutDeviationAggregate(count: 1, maximumDegrees: double.nan),
        throwsFormatException);
    expect(() => WorkoutDeviationAggregate(count: 0, maximumDegrees: 1),
        throwsFormatException);
  });

  test('corrupt v3 metrics fail closed rather than silently becoming legacy',
      () {
    final valid = measured().toJson();
    void rejectMetric(String key, Object? value) {
      final metrics = Map<String, Object?>.from(valid['poseMetrics'] as Map)
        ..[key] = value;
      expect(
          () => WorkoutSessionSummary.fromJson(
              {...valid, 'poseMetrics': metrics}),
          throwsFormatException);
    }

    rejectMetric('schemaVersion', 99);
    rejectMetric('formScorePercent', double.nan);
    rejectMetric('formScorePercent', 101);
    rejectMetric('trackedDurationMicros', 19000000);
    rejectMetric('rejectedDurationMicros', -1);
    rejectMetric('partialRepetitions', 10000);
    rejectMetric('scoringVersion', 'unknown-rule');
    rejectMetric('cameraView', 'front');
    rejectMetric('detectorId', 'simulated');
    rejectMetric('consentVersion', 'unknown-consent');
    rejectMetric(
        'consentedAt', start.add(const Duration(seconds: 1)).toIso8601String());
    rejectMetric('deviations', {
      'trunkLean': {'count': 5, 'maximumDegrees': 10}
    });
    expect(
        () => WorkoutSessionSummary.fromJson({...valid, 'poseMetrics': null}),
        throwsFormatException);
    expect(() => WorkoutSessionSummary.fromJson({...valid, 'sessionId': ''}),
        throwsFormatException);
    expect(
        () => WorkoutSessionSummary.fromJson({...valid, 'userId': 'member/a'}),
        throwsFormatException);
    expect(() => WorkoutSessionSummary.fromJson({...valid, 'landmarks': []}),
        throwsFormatException);
    expect(
        () => measured(score: 80, full: 0, partial: 0, deviations: {}).toJson(),
        throwsFormatException);
  });

  test('duration bounds resist native integer overflow', () {
    final valid = measured().toJson();
    final metrics = Map<String, Object?>.from(valid['poseMetrics'] as Map)
      ..['trackedDurationMicros'] = 9223372036854775807
      ..['rejectedDurationMicros'] = 1;
    expect(
        () =>
            WorkoutSessionSummary.fromJson({...valid, 'poseMetrics': metrics}),
        throwsFormatException);
  });

  test('full rep bounds resist native integer overflow', () {
    final valid = measured().toJson();
    final metrics = Map<String, Object?>.from(valid['poseMetrics'] as Map)
      ..['deviations'] = {};
    expect(
        () => WorkoutSessionSummary.fromJson({
              ...valid,
              'repetitions': 9223372036854775807,
              'poseMetrics': metrics
            }),
        throwsFormatException);
  });

  test('legacy and v2 summaries do not infer appended measured fields', () {
    final legacy = {...measured().toJson()}..remove('summarySchemaVersion');
    final restored = WorkoutSessionSummary.fromJson(legacy);
    expect(restored.poseMetrics, isNull);
    expect(restored.provenance, WorkoutProvenance.legacyUnknown);
    expect(restored.accuracy, 89);
    expect(restored.toJson()['summarySchemaVersion'], 2);
    final v2 = {
      ...legacy,
      'summarySchemaVersion': 2,
      'provenance': 'simulated'
    };
    expect(WorkoutSessionSummary.fromJson(v2).poseMetrics, isNull);
  });

  test('durable restart preserves metrics and stable-ID equality', () async {
    final directory =
        await Directory.systemTemp.createTemp('gainpath-real-metrics-');
    addTearDown(() => directory.delete(recursive: true));
    WorkoutSessionRepository repo(SessionScope scope) =>
        WorkoutSessionRepository(
            scope: scope,
            store: FileWorkoutSessionStore(directory: directory, scope: scope),
            uploadGateway: UnavailableWorkoutUploadGateway(),
            activeScope: () => scope);
    final summary = measured();
    await repo(owner).saveLocal(summary);
    final restarted = repo(owner);
    expect((await restarted.loadHistory()).single.summary, summary);
    await restarted.saveLocal(WorkoutSessionSummary.fromJson(summary.toJson()));
    expect(await restarted.loadHistory(), hasLength(1));
    await expectLater(
        restarted.saveLocal(measured(score: 89)), throwsStateError);
    expect(
        (await restarted.loadHistory()).single.summary.formScorePercent, 88.5);
    final other = SessionScope(userId: 'member-b', organizationId: 'gainpath');
    expect(await repo(other).loadHistory(), isEmpty);
    await expectLater(repo(other).saveLocal(summary), throwsStateError);
  });

  for (final committed in [false, true]) {
    test(
        'stable retry after ${committed ? "committed" : "uncommitted"} write failure saves once',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('gainpath-real-retry-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = WorkoutSessionRepository(
          scope: owner,
          store: FailOnceStore(
              FileWorkoutSessionStore(directory: directory, scope: owner),
              afterCommit: committed),
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => owner);
      final summary = measured();
      await expectLater(
          repository.saveLocal(summary), throwsA(isA<FileSystemException>()));
      await repository.saveLocal(summary);
      expect((await repository.loadHistory()).single.summary, summary);
    });
  }

  test('measured real results remain local even with an explicit demo gateway',
      () async {
    final gateway = UploadSpy();
    final repository =
        InMemoryWorkoutSessionRepository(scope: owner, uploadGateway: gateway);
    await repository.saveLocal(measured());
    final result = await repository.syncPending();
    expect(gateway.calls, 0);
    expect(result.acceptedCount, 0);
    expect((await repository.loadHistory()).single.status,
        WorkoutSyncStatus.pending);
  });

  test('measured records cannot acquire a local acceptance receipt', () async {
    final summary = measured();
    final pending = WorkoutSessionRecord(
            summary: summary, status: WorkoutSyncStatus.pending)
        .toJson();
    expect(
        () => WorkoutSessionRecord.fromJson({...pending, 'status': 'accepted'}),
        throwsFormatException);
    expect(
        () => WorkoutSessionRecord.fromJson(
            {...pending, 'serverReference': 'fake-receipt'}),
        throwsFormatException);
    expect(() => WorkoutSessionRecord.fromJson({...pending, 'acceptedAt': 123}),
        throwsFormatException);
    expect(
        () => WorkoutSessionRecord.fromJson({
              ...pending,
              'serverReference': {'fake': true}
            }),
        throwsFormatException);
    final store = InMemoryWorkoutSessionStore(scope: owner);
    await expectLater(
        store.write([
          WorkoutSessionRecord(
              summary: summary,
              status: WorkoutSyncStatus.accepted,
              acceptedAt: start,
              serverReference: 'fake')
        ]),
        throwsFormatException);
    expect(await store.read(), isEmpty);
  });

  test('the built-in demo gateway also rejects direct measured uploads',
      () async {
    final gateway = InMemoryWorkoutUploadGateway();
    await expectLater(gateway.upload(measured()), throwsUnsupportedError);
    expect(gateway.uploaded, isEmpty);
  });

  test('unmeasured real or fixture labels cannot acquire local acceptance', () {
    for (final provenance in [
      WorkoutProvenance.realCamera,
      WorkoutProvenance.recordedFixture
    ]) {
      final json = measured().toJson()..remove('poseMetrics');
      json['summarySchemaVersion'] = 2;
      json['provenance'] = provenance.name;
      final summary = WorkoutSessionSummary.fromJson(json);
      final record = WorkoutSessionRecord(
              summary: summary, status: WorkoutSyncStatus.pending)
          .toJson();
      expect(
          () =>
              WorkoutSessionRecord.fromJson({...record, 'status': 'accepted'}),
          throwsFormatException);
      expect(
          () => WorkoutSessionRecord.fromJson({...record, 'acceptedAt': 123}),
          throwsFormatException);
    }
  });

  test('account replacement invalidates real save and does not reassign data',
      () async {
    SessionScope? active = owner;
    final store = InMemoryWorkoutSessionStore(scope: owner);
    final repository = WorkoutSessionRepository(
        scope: owner,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => active);
    await repository.saveLocal(measured());
    active = SessionScope(userId: 'member-b', organizationId: 'gainpath');
    await expectLater(
        repository.saveLocal(measured(id: 'late')), throwsStateError);
    expect((await store.read()).single.summary.scope, owner);
  });
}
