import 'package:flutter/material.dart';
import '../../../domain/workout_backup.dart';
import '../../../domain/routine_attempt.dart';
import '../../../application/workout_backup_coordinator.dart';
import '../../../../../presentation/shared/workout_save_indicator.dart';

export '../../../../../presentation/shared/workout_save_indicator.dart';

/// Shared read-only status for a list row: no per-row stores or network work.
class WorkoutRecordSyncIndicator extends StatelessWidget {
  const WorkoutRecordSyncIndicator(
      {super.key, this.coordinator, this.record, this.attempt});
  final WorkoutBackupCoordinator? coordinator;
  final WorkoutBackupRecord? record;
  final RoutineAttempt? attempt;
  @override
  Widget build(BuildContext context) {
    final c = coordinator;
    if (c == null) return const WorkoutSaveIndicator();
    return ListenableBuilder(
        listenable: c,
        builder: (context, child) {
          if (!c.authorized) return const SizedBox.shrink();
          if (record != null &&
              (record!.payload['organizationId'] != c.scope.organizationId ||
                  record!.payload['userId'] != c.scope.userId)) {
            return const SizedBox.shrink();
          }
          final row = record ??
              c.records
                  .where((r) =>
                      r.kind == 'routine' &&
                      r.id == attempt?.id &&
                      attempt?.scope == c.scope &&
                      backupCanonical(r.payload['attempt']) ==
                          backupCanonical(attempt?.toJson()))
                  .firstOrNull;
          return WorkoutSaveIndicator(
              status:
                  row == null ? BackupRecordStatus.localOnly : c.statusFor(row),
              syncEnabled: c.state.enabled,
              onRetry: () {
                c.sync().catchError((Object _) {});
              });
        });
  }
}
