import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../application/member_achievements_controller.dart';
import '../../domain/member_achievements.dart';
import 'achievement_artwork.dart';

class TrainingAchievementPreview extends StatelessWidget {
  const TrainingAchievementPreview({
    super.key,
    required this.controller,
    required this.onViewAll,
  });

  final MemberAchievementsController? controller;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final source = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(
              child: MemberSectionHeader(
                  title: 'Training achievements', padded: false)),
          TextButton(
              key: const ValueKey('training-achievements-view-all'),
              onPressed: onViewAll,
              child: const Text('View all')),
        ]),
        if (source == null)
          const Panel(
              padding: EdgeInsets.all(10),
              child: Text('Training badges unavailable'))
        else
          ListenableBuilder(
            listenable: source,
            builder: (context, _) => _card(context, source),
          ),
      ],
    );
  }

  Widget _card(BuildContext context, MemberAchievementsController source) {
    final data = source.snapshot;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (!source.current || data == null || !data.complete) {
      return Panel(
        child: !source.current
            ? const Text('Training badges unavailable')
            : source.failed
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Could not load training badges',
                          style: TextStyle(color: colors.error)),
                      TextButton(
                          onPressed: source.refresh,
                          child: const Text('Retry')),
                    ],
                  )
                : data == null
                    ? const LinearProgressIndicator(
                        semanticsLabel: 'Loading training badges')
                    : const Text('Waiting for confirmed training progress'),
      );
    }

    final training = MemberAchievements(
      currentStreak: data.currentStreak,
      badges: data.badges.where((badge) => badge.category == 'workout'),
    );
    final next = source.stale ? null : training.next;
    if (training.badges.isEmpty) {
      return const Panel(child: Text('No training badges available'));
    }
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${training.unlockedCount}/${training.badges.length} badges unlocked',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final badge in training.badges.take(4))
                Expanded(
                  child: Center(
                    child: Semantics(
                      label:
                          '${badge.title}, ${badge.unlocked ? 'unlocked' : 'locked'}',
                      child: Stack(
                        alignment: AlignmentDirectional.bottomEnd,
                        children: [
                          AchievementArtwork(
                              id: badge.id, unlocked: badge.unlocked, size: 52),
                          if (!badge.unlocked)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(Icons.lock_outline,
                                    size: 13, color: colors.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (next != null) ...[
            const Divider(height: 22, color: AppColors.hairline),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(next.title,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    )),
                Text(next.progressLabel,
                    style: text.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: next.fraction,
              minHeight: 5,
              color: colors.primary,
              backgroundColor: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(4),
              semanticsLabel: '${next.title} progress',
              semanticsValue: next.progressLabel,
            ),
          ] else if (source.stale) ...[
            const SizedBox(height: 8),
            Text('Showing last confirmed badges', style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
