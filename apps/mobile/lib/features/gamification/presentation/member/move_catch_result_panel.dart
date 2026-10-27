import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Round statistics and local persistence feedback, separate from reward points.
class MoveCatchResultPanel extends StatelessWidget {
  const MoveCatchResultPanel({
    super.key,
    required this.score,
    required this.caught,
    required this.missed,
    required this.obstacles,
    required this.bestScore,
    required this.bestScoreAvailable,
    required this.bestSaved,
    required this.scoreSaveFailed,
    required this.onReplay,
    required this.onExit,
    this.error,
    this.rewardStatus,
  });

  final int score, caught, missed, obstacles, bestScore;
  final bool bestScoreAvailable, bestSaved, scoreSaveFailed;
  final VoidCallback? onReplay;
  final VoidCallback onExit;
  final String? error;
  final Widget? rewardStatus;

  @override
  Widget build(BuildContext context) => ColoredBox(
      color: AppColors.bg,
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Icon(Icons.emoji_events_rounded,
                            size: 44, color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text('Round complete',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    color: AppColors.ink,
                                    fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Move & Catch', textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary,
                                      Color(0xFF9365E8)
                                    ]),
                                borderRadius: BorderRadius.circular(28)),
                            child: Semantics(
                                label: 'Game score $score',
                                excludeSemantics: true,
                                child: Column(children: [
                                  const Icon(Icons.star_rounded,
                                      color: Color(0xFFFFD34E), size: 36),
                                  const SizedBox(height: 8),
                                  const Text('Game score',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                  Text('$score',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 64,
                                          height: 1.2,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Game scores are not reward points.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white)),
                                ]))),
                        const SizedBox(height: 16),
                        LayoutBuilder(builder: (context, constraints) {
                          final largeText =
                              MediaQuery.textScalerOf(context).scale(16) > 22;
                          final tiles = [
                            _stat(Icons.star_outline_rounded, 'Caught', caught),
                            _stat(Icons.south_rounded, 'Missed', missed),
                            _stat(
                                Icons.diamond_outlined, 'Obstacles', obstacles)
                          ];
                          if (largeText || constraints.maxWidth < 320) {
                            return Column(children: [
                              for (final tile in tiles)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: tile)
                            ]);
                          }
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < tiles.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  Expanded(child: tiles[i])
                                ]
                              ]);
                        }),
                        const SizedBox(height: 16),
                        _section(
                            icon: Icons.workspace_premium_outlined,
                            title: bestScoreAvailable
                                ? 'Personal best: $bestScore'
                                : 'Personal best unavailable',
                            body: scoreSaveFailed
                                ? 'Personal best could not be saved. This round is still complete.'
                                : bestSaved
                                    ? 'Personal best saved on this device.'
                                    : 'This device keeps your personal best for your account.'),
                        const SizedBox(height: 12),
                        rewardStatus ??
                            _section(
                                icon: Icons.stars_outlined,
                                title: 'Reward points',
                                status: 'Not active',
                                body:
                                    'No reward points are awarded for this game.'),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(error!,
                              style: const TextStyle(color: AppColors.danger))
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.all(16),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white),
                            onPressed: onReplay,
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Play again')),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.all(16),
                                foregroundColor: AppColors.primary),
                            onPressed: onExit,
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back to games')),
                      ])))));

  Widget _stat(IconData icon, String label, int value) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text('$value',
            style: const TextStyle(
                color: AppColors.ink,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        Text(label, textAlign: TextAlign.center),
      ]));

  Widget _section(
          {required IconData icon,
          required String title,
          required String body,
          String? status}) =>
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(status,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700))
            ],
            const SizedBox(height: 8),
            Text(body)
          ]));
}
