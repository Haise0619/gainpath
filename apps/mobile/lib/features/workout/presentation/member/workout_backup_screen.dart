import 'package:flutter/material.dart';
import '../../application/workout_backup_coordinator.dart';
import '../../domain/workout_backup.dart';

class WorkoutBackupScreen extends StatelessWidget {
  const WorkoutBackupScreen(
      {super.key, this.coordinator, this.error, this.onRetry, this.onChanged});
  final WorkoutBackupCoordinator? coordinator;
  final String? error;
  final VoidCallback? onRetry;
  final Future<void> Function()? onChanged;
  Future<void> _enable(
      BuildContext context, WorkoutBackupCoordinator c, bool value) async {
    if (value) {
      final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Back up workout history?'),
                  content: const SingleChildScrollView(
                      child: Text(
                          'Store your exercise summaries, routine targets and progress in your private account backup. No video or skeleton frames are uploaded. AI measurements remain provisional and self-reported sets stay separate. Backup does not earn rewards or verify form. Turning this off stops future sync; it does not delete existing cloud copies.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Enable backup'))
                  ]));
      if (accepted != true || !c.authorized) return;
    }
    await c.setEnabled(value);
    await onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = coordinator;
    if (c == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Workout backup')),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            Text(error ?? 'Cloud backup awaiting activation',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
                'Your workout results remain saved on this device. Backup and restore become available after the prepared backend is activated.'),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry'))
          ]));
    }
    return ListenableBuilder(
        listenable: c,
        builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Workout backup')),
            body: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (!c.authorized)
                    const Text('Sign in to view this account’s backup.')
                  else ...[
                    Text(c.label,
                        style: Theme.of(context).textTheme.headlineSmall),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Back up and restore history'),
                        subtitle: const Text(
                            'Private summaries and routine progress · optional'),
                        value: c.state.enabled,
                        onChanged:
                            c.busy ? null : (v) => _enable(context, c, v)),
                    const Text(
                        'Saved copies remain provisional. Backup status is separate from workout verification or rewards.'),
                    if (c.busy) const LinearProgressIndicator(),
                    if (c.state.lastError != null)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                              'Backup could not finish. Your local results are retained. Retry when connected.')),
                    FilledButton.icon(
                        onPressed: !c.state.enabled || c.busy
                            ? null
                            : () async {
                                await c.sync();
                                await onChanged?.call();
                              },
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Sync now')),
                    const SizedBox(height: 16),
                    for (final row in c.records)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(row.kind == 'routine'
                                        ? '${(row.payload['attempt'] as Map)['routine']['title']} · Day ${row.payload['day']}'
                                        : 'Exercise result · ${row.payload['exerciseId']}'),
                                    Text(switch (c.statusFor(row)) {
                                      BackupRecordStatus.localOnly =>
                                        'Saved locally',
                                      BackupRecordStatus.syncing => 'Syncing',
                                      BackupRecordStatus.backedUp =>
                                        'Backed up',
                                      BackupRecordStatus.retryNeeded =>
                                        'Retry needed',
                                      BackupRecordStatus.conflict =>
                                        'Conflict · local data kept'
                                    }),
                                    if (c.statusFor(row) ==
                                        BackupRecordStatus.conflict) ...[
                                      const Text(
                                          'Local progress was not replaced. Any existing cloud copy is retained.'),
                                      if (c.canKeepLocal(row))
                                        TextButton(
                                            onPressed: c.busy
                                                ? null
                                                : () async {
                                                    final yes = await showDialog<
                                                            bool>(
                                                        context: context,
                                                        builder: (context) =>
                                                            AlertDialog(
                                                                title: const Text(
                                                                    'Keep this device’s progress?'),
                                                                content: const Text(
                                                                    'Make this local routine copy the current backup. The previous cloud revision remains archived.'),
                                                                actions: [
                                                                  TextButton(
                                                                      onPressed: () => Navigator.pop(
                                                                          context,
                                                                          false),
                                                                      child: const Text(
                                                                          'Cancel')),
                                                                  FilledButton(
                                                                      onPressed: () => Navigator.pop(
                                                                          context,
                                                                          true),
                                                                      child: const Text(
                                                                          'Keep local'))
                                                                ]));
                                                    if (yes == true &&
                                                        c.authorized) {
                                                      await c
                                                          .keepLocal(row.key);
                                                      await onChanged?.call();
                                                    }
                                                  },
                                            child: const Text(
                                                'Keep local progress')),
                                    ],
                                  ]))),
                    if (c.records.isEmpty)
                      const Text(
                          'No saved workout summaries or routine attempts yet.'),
                  ],
                ])));
  }
}
