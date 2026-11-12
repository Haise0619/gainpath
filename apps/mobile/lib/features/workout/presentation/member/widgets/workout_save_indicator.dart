import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/workout_backup.dart';
import '../../../domain/routine_attempt.dart';
import '../../../application/workout_backup_coordinator.dart';

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

/// Cloud-copy state only. It never implies form verification or a reward.
class WorkoutSaveIndicator extends StatelessWidget {
  const WorkoutSaveIndicator(
      {super.key,
      this.status = BackupRecordStatus.localOnly,
      this.onRetry,
      this.onSetup,
      this.syncEnabled = false});
  final BackupRecordStatus status;
  final VoidCallback? onRetry, onSetup;
  final bool syncEnabled;
  @override
  Widget build(BuildContext context) {
    final failed = status == BackupRecordStatus.retryNeeded;
    final label = switch (status) {
      BackupRecordStatus.backedUp => 'Synced',
      BackupRecordStatus.syncing => 'Syncing',
      BackupRecordStatus.retryNeeded => 'Sync failed — Retry',
      BackupRecordStatus.conflict => 'Saved on this device · sync needs review',
      _ => 'Saved on this device',
    };
    final icon = switch (status) {
      BackupRecordStatus.backedUp => Icons.cloud_done_outlined,
      BackupRecordStatus.syncing => Icons.sync_rounded,
      BackupRecordStatus.retryNeeded => Icons.cloud_off_outlined,
      _ => Icons.check_circle_outline_rounded,
    };
    final content = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 8),
      Flexible(
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
          liveRegion: true,
          child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Padding(
                  key: ValueKey(label),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: failed && onRetry != null
                      ? TextButton(onPressed: onRetry, child: content)
                      : content))),
      if (status == BackupRecordStatus.pendingBackup && syncEnabled)
        const Text('Your result will sync automatically when connected.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
      if (onSetup != null)
        TextButton.icon(
            onPressed: onSetup,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Enable automatic sync')),
    ]);
  }
}
