import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/infrastructure/local/file_workout_session_store.dart';

class _RealUploadSpy implements WorkoutUploadGateway {
  int calls = 0;
  @override
  Future<WorkoutUploadReceipt> upload(WorkoutSessionSummary summary) async {
    calls++;
    return WorkoutUploadReceipt(
        acceptedAt: DateTime.utc(2026), serverReference: summary.sessionId);
  }
}

void main() {
  final scope = SessionScope(userId: 'member-1', organizationId: 'gainpath');
  final demo = WorkoutSessionSummary(
    userId: scope.userId,
    organizationId: scope.organizationId,
    sessionId: 'demo-session',
    exerciseId: 'F3b8xIr8ynBDd3gEICKX',
    repetitions: 8,
    accuracy: 90,
    startedAt: DateTime.utc(2026),
    endedAt: DateTime.utc(2026, 1, 1, 0, 1),
  );

  test(
      'legacy migration preserves local results without trusting a provenance label',
      () {
    final old = Map<String, Object?>.of(demo.toJson())
      ..remove('summarySchemaVersion');
    // Even an appended real-camera label does not upgrade a pre-migration record.
    old['provenance'] = 'realCamera';
    final restored = WorkoutSessionSummary.fromJson(old);
    expect(restored.provenance, WorkoutProvenance.legacyUnknown);
    expect(restored.repetitions, 8);
    expect(restored.accuracy, 90);
    expect(restored.isEligibleForRealUpload, isFalse);
    expect(WorkoutSessionSummary.fromJson(restored.toJson()).provenance,
        WorkoutProvenance.legacyUnknown);
    for (final provenance in WorkoutProvenance.values) {
      expect(
          WorkoutSessionSummary.fromJson(
                  {...demo.toJson(), 'provenance': provenance.name})
              .isEligibleForRealUpload,
          isFalse);
    }
    expect(
        () => WorkoutSessionSummary.fromJson(
            {...demo.toJson(), 'summarySchemaVersion': 99}),
        throwsFormatException);
    expect(
        () => WorkoutSessionSummary.fromJson(
            {...demo.toJson(), 'provenance': 'unsupported'}),
        throwsFormatException);
  });

  test(
      'installing a real gateway cannot upload old or simulated records after restart',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('gainpath-provenance-');
    addTearDown(() => directory.delete(recursive: true));
    // The pre-migration storage format, with no provenance/version/evidence.
    final legacyJson = <String, Object?>{
      'userId': scope.userId,
      'organizationId': scope.organizationId,
      'sessionId': 'legacy-session',
      'exerciseId': demo.exerciseId,
      'repetitions': 8,
      'accuracy': 90,
      'startedAt': demo.startedAt.toIso8601String(),
      'endedAt': demo.endedAt.toIso8601String(),
    };
    final legacy = WorkoutSessionSummary.fromJson(legacyJson);
    final store = FileWorkoutSessionStore(directory: directory, scope: scope);
    await store.write([
      WorkoutSessionRecord(summary: legacy, status: WorkoutSyncStatus.pending),
      WorkoutSessionRecord(summary: demo, status: WorkoutSyncStatus.pending),
    ]);
    final upload = _RealUploadSpy();
    final restarted = WorkoutSessionRepository(
      scope: scope,
      store: FileWorkoutSessionStore(directory: directory, scope: scope),
      uploadGateway: upload,
      activeScope: () => scope,
    );
    final result = await restarted.syncPending();
    expect(upload.calls, 0);
    expect(result.acceptedCount, 0);
    expect((await restarted.loadHistory()).map((r) => r.status),
        everyElement(WorkoutSyncStatus.pending));
  });
}
