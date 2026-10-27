import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/mini_game_round_coordinator.dart';

class MiniGameRoundStatusPanel extends StatelessWidget {
  const MiniGameRoundStatusPanel({super.key, required this.coordinator});
  final MiniGameRoundCoordinator coordinator;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: coordinator,
      builder: (context, _) {
        final c = coordinator;
        final title = switch (c.state) {
          MiniGameRoundSyncState.idle => 'Round timing not sent',
          MiniGameRoundSyncState.starting => 'Preparing round check',
          MiniGameRoundSyncState.recording => 'Round timing recorded',
          MiniGameRoundSyncState.submitting => 'Checking round timing…',
          MiniGameRoundSyncState.awaitingVerification => 'Round timing checked',
          MiniGameRoundSyncState.unavailable => 'Round timing unavailable',
        };
        return Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(c.state == MiniGameRoundSyncState.awaitingVerification
              ? 'Awaiting physical gameplay verification. No reward points were awarded.'
              : 'Local game score and personal best are separate from this optional check. No reward points are awarded.'),
          if (c.state == MiniGameRoundSyncState.unavailable) ...[
            const SizedBox(height: 6),
            const Text(
                'You can keep playing. Missing timing is never filled in as verified play.'),
            if (c.canRetry)
              TextButton.icon(
                  onPressed: c.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry round check')),
          ],
          if (c.state == MiniGameRoundSyncState.starting ||
              c.state == MiniGameRoundSyncState.submitting)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator()),
        ]));
      });
}
