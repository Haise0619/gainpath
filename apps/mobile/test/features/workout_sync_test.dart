import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'dart:io';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/infrastructure/local/file_workout_session_store.dart';

void main() {
  test('concurrent saves retain every completed session', () async {
    final repository = InMemoryWorkoutSessionRepository();
    await Future.wait(List.generate(
        12,
        (index) => repository.saveLocal(
              WorkoutSessionSummary(
                  sessionId: 'session-$index',
                  exerciseId: 'squat',
                  repetitions: 1,
                  accuracy: 80,
                  startedAt: DateTime.utc(2026),
                  endedAt: DateTime.utc(2026, 1, 1, 0, 1)),
            )));
    expect(await repository.loadHistory(), hasLength(12));
  });

  final summary = WorkoutSessionSummary(
    sessionId: 'session-1',
    exerciseId: 'bodyweight_squat',
    repetitions: 8,
    accuracy: 91,
    startedAt: DateTime.utc(2026, 9, 18),
    endedAt: DateTime.utc(2026, 9, 18, 0, 5),
  );

  test('session summaries round-trip through a storage-safe map', () {
    final restored = WorkoutSessionSummary.fromJson(summary.toJson());

    expect(restored, summary);
  });

  test('accepted uploads are not uploaded again', () async {
    final uploader = InMemoryWorkoutUploadGateway();
    final repository = InMemoryWorkoutSessionRepository(
      uploadGateway: uploader,
    );

    await repository.saveLocal(summary);
    final firstSync = await repository.syncPending();
    final secondSync = await repository.syncPending();

    expect(firstSync.acceptedCount, 1);
    expect(firstSync.failedCount, 0);
    expect(secondSync.acceptedCount, 0);
    expect(uploader.uploaded, [summary]);
    expect((await repository.loadHistory()).single.status,
        WorkoutSyncStatus.accepted);
  });

  test('file store restores records across repository instances', () async {
    final directory = await Directory.systemTemp.createTemp('gainpath-outbox-');
    addTearDown(() => directory.delete(recursive: true));
    final scope = SessionScope(userId: 'demo-user', organizationId: 'demo-org');
    final store = FileWorkoutSessionStore(directory: directory, scope: scope);
    final record = WorkoutSessionRecord(
      summary: summary,
      status: WorkoutSyncStatus.pending,
    );

    await store.write([record]);

    final restored =
        await FileWorkoutSessionStore(directory: directory, scope: scope)
            .read();
    expect(restored, hasLength(1));
    expect(restored.single.summary, summary);
    expect(restored.single.status, WorkoutSyncStatus.pending);
  });

  test('failed uploads remain pending for a later retry', () async {
    final repository = InMemoryWorkoutSessionRepository(
      uploadGateway: _FailingWorkoutUploadGateway(),
    );

    await repository.saveLocal(summary);
    final result = await repository.syncPending();

    expect(result.acceptedCount, 0);
    expect(result.failedCount, 1);
    expect((await repository.loadHistory()).single.status,
        WorkoutSyncStatus.pending);
  });
}

class _FailingWorkoutUploadGateway implements WorkoutUploadGateway {
  @override
  Future<WorkoutUploadReceipt> upload(WorkoutSessionSummary summary) {
    throw StateError('network unavailable');
  }
}
