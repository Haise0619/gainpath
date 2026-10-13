import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/real_workout_sync_presentation.dart';
import '../../domain/real_workout_sync.dart';

class RealWorkoutSyncPanel extends StatefulWidget {
  const RealWorkoutSyncPanel(
      {super.key, required this.repository, required this.sessionId});
  final RealWorkoutSyncPresentation repository;
  final String sessionId;
  @override
  State<RealWorkoutSyncPanel> createState() => _RealWorkoutSyncPanelState();
}

class _RealWorkoutSyncPanelState extends State<RealWorkoutSyncPanel> {
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not update upload status. The local result is still saved.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final repo = widget.repository;
        final entry = repo.entries
            .where((e) => e.submission.sessionId == widget.sessionId)
            .firstOrNull;
        final title = switch (entry?.status) {
          RealWorkoutSyncStatus.accepted => 'Server accepted',
          RealWorkoutSyncStatus.pending => 'Upload pending',
          RealWorkoutSyncStatus.retryable => 'Upload needs retry',
          RealWorkoutSyncStatus.rejected =>
            entry?.failureCode == 'consent-revoked'
                ? 'Uploads disabled'
                : 'Upload not accepted',
          null => 'Local result only'
        };
        final message = switch (entry?.status) {
          RealWorkoutSyncStatus.accepted =>
            'The server stored this summary. This does not certify motion accuracy.',
          RealWorkoutSyncStatus.pending =>
            'Waiting to submit this measured summary. Acceptance is not confirmed.',
          RealWorkoutSyncStatus.retryable =>
            'The service could not confirm acceptance. Retry uses the same saved request.',
          RealWorkoutSyncStatus.rejected => entry?.failureCode ==
                  'failed-precondition'
              ? 'Consent, routine or model validation requirements were not met. Current model acceptance remains disabled pending physical validation.'
              : entry?.failureCode == 'consent-revoked'
                  ? 'Future uploads are disabled. A request sent before revocation may already have been accepted; revocation does not delete server summaries.'
                  : 'The service rejected this request (${entry?.failureCode}). This result stays on this device.',
          null =>
            'No upload request is saved for this session. Consent must have been acknowledged before capture.'
        };
        return Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.warning)),
          if (repo.revocationPending)
            const Text(
                'Upload consent is disabled here; server revocation is pending.'),
          if (_busy || repo.syncing)
            const Padding(
                padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
          if (entry?.status == RealWorkoutSyncStatus.pending ||
              entry?.status == RealWorkoutSyncStatus.retryable ||
              repo.revocationPending)
            OutlinedButton(
                onPressed: _busy || repo.syncing
                    ? null
                    : () => unawaited(_run(repo.sync)),
                child: const Text('Retry sync')),
          if (repo.consent != null)
            TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final yes = await confirmSheet(context,
                            title: 'Disable workout uploads?',
                            message:
                                'Pending requests using this consent will stay local. Already accepted server summaries are retained.',
                            confirmLabel: 'Disable uploads');
                        if (yes && mounted) await _run(repo.revokeConsent);
                      },
                child: const Text('Disable workout uploads')),
        ]));
      });
}
