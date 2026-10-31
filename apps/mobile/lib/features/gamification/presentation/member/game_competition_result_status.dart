import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/mini_game_competition_coordinator.dart';
import '../../application/mini_game_round_coordinator.dart';

class GameCompetitionResultStatus extends StatelessWidget {
  const GameCompetitionResultStatus({super.key, required this.coordinator});
  final MiniGameCompetitionCoordinator coordinator;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: coordinator,
      builder: (context, _) {
        final c = coordinator;
        if (!c.current) return const Text('Ranking session ended.');
        final receipt = c.receipt, timing = c.timing;
        final unavailable = c.submissionFailed ||
            timing.state == MiniGameRoundSyncState.unavailable;
        final message = receipt != null
            ? 'Accepted Game Score: ${receipt.score}'
            : !c.roundParticipating
                ? 'Not participating in game rankings'
                : unavailable
                    ? 'Could not confirm this game result.'
                    : c.submitting
                        ? 'Submitting game result…'
                        : 'Confirming completed round…';
        return Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Game rankings',
              style:
                  TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppColors.ink)),
          const SizedBox(height: 6),
          const Text(miniGameCompetitionTrustLabel,
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
          if (unavailable && c.roundParticipating) ...[
            const SizedBox(height: 8),
            const Text(
                'Your local result and Reward Points status are unchanged.'),
            if (c.canRetry)
              TextButton(
                  onPressed: c.retry, child: const Text('Retry game result'))
            else
              const Text('Play a new round to try game rankings again.')
          ],
        ]));
      });
}
