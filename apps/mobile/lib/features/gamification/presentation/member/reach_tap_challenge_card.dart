import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gamification.dart';
import 'mini_game_details_screen.dart' show MiniGameCover;

class ReachTapChallengeCard extends StatelessWidget {
  const ReachTapChallengeCard({super.key, required this.onTap, this.content});
  final VoidCallback onTap;
  final MiniGameContent? content;
  @override
  Widget build(BuildContext context) => Tooltip(
      message: 'View Reach & Tap details',
      child: MotionChallengeCard(
          content: content ??
              MiniGameContent.defaults('built-in',
                  gameId: MiniGameContent.reachTapId),
          onTap: onTap));
}

class MotionChallengeCard extends StatelessWidget {
  const MotionChallengeCard({super.key, required this.content, required this.onTap});
  final MiniGameContent content;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          key: Key(content.gameId == MiniGameContent.reachTapId
              ? 'reach-tap-challenge-card'
              : 'move-catch-challenge-card'),
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
                aspectRatio: 1.2,
                child: Stack(fit: StackFit.expand, children: [
                  MiniGameCover(content: content),
                  const Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          size: 42, color: Colors.white)),
                ])),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('40 seconds · Camera',
                          style: TextStyle(color: AppColors.inkSoft)),
                      const SizedBox(height: 4),
                      const Text('All levels',
                          style: TextStyle(color: AppColors.primary)),
                    ])),
          ])));
}
