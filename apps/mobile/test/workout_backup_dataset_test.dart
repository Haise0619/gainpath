import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_contracts.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'package:gainpath_mobile/infrastructure/local/file_workout_session_store.dart';
import 'routine_journey_controller_test.dart' as fixture;

void main() {
  test(
      'dataset workout roundtrip preserves current scope and existing Firebase payload',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('gainpath-scoped-workout-');
    try {
      final scope = SessionScope(
          userId: 'member',
          organizationId: 'gainpath',
          datasetScope: const VerifiedDatasetScope(
              datasetId: 'fyp-v1',
              seedId: 'gainpath-fyp-v1',
              revision: 1,
              rootPath: 'orgs/gainpath/cohorts/fyp-v1'));
      final original = WorkoutBackupRecord.session(fixture.measured(
          SessionScope(userId: 'member', organizationId: 'gainpath'), 's1'));
      final raw = original.payload;
      final summary = WorkoutSessionSummary.fromJson(raw, scope: scope);
      expect(summary.scope, scope);
      expect(summary.toJson(), raw);
      final store = FileWorkoutSessionStore(directory: directory, scope: scope);
      await store.exclusive(() => store.write([
            WorkoutSessionRecord(
                summary: summary, status: WorkoutSyncStatus.pending)
          ]));
      final restored = (await store.exclusive(store.read)).single.summary;
      expect(restored.scope, scope);
      expect(WorkoutBackupRecord.session(restored).digest, original.digest);
      expect(
          () => WorkoutSessionSummary.fromJson(raw,
              scope: SessionScope(
                  userId: 'someone-else', organizationId: 'gainpath')),
          throwsFormatException);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
