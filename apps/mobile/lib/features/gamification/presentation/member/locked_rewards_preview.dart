import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'mini_game_details_screen.dart';
import 'reward_details.dart';
import '../../../../presentation/shared/locked_membership_preview.dart';

export '../../../../presentation/shared/locked_membership_preview.dart';

class FreeMiniGamesPreview extends StatefulWidget {
  const FreeMiniGamesPreview(
      {super.key, required this.onViewPlans, this.reader});
  final Future<void> Function() onViewPlans;
  final MiniGameContentReader? reader;
  @override
  State<FreeMiniGamesPreview> createState() => _FreeMiniGamesPreviewState();
}

class _FreeMiniGamesPreviewState extends State<FreeMiniGamesPreview> {
  Map<String, MiniGameContent> _games = {};
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(FreeMiniGamesPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.reader, widget.reader)) {
      _games = {};
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final reader = widget.reader, generation = ++_generation;
    if (reader == null || !reader.current) return;
    try {
      final games = await reader.load();
      if (!mounted || generation != _generation || !reader.current) return;
      if (games.any((game) =>
              game.organizationId != reader.scope.organizationId ||
              !MiniGameContent.supportedIds.contains(game.gameId)) ||
          games.map((game) => game.gameId).toSet().length != games.length) {
        return;
      }
      setState(() => _games = {for (final game in games) game.gameId: game});
    } catch (_) {
      // Built-in art remains an honest fallback when published covers cannot load.
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LockedRewardsPreview(
      sectionTitle: 'Play Mini-Games',
      title: 'More play. More possibilities.',
      description:
          'Unlock Mini-Games with Basic or Premium. Keep earning your daily check-in points for free.',
      previewLabel:
          'Move & Catch and Reach & Tap. Mini-Games require Basic or Premium membership.',
      onViewPlans: widget.onViewPlans,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final id in [
          MiniGameContent.supportedId,
          MiniGameContent.reachTapId
        ]) ...[
          if (id == MiniGameContent.reachTapId) const SizedBox(width: 10),
          Expanded(
              child: _GamePreview(
                  content: widget.reader?.current == false
                      ? MiniGameContent.defaults('preview', gameId: id)
                      : _games[id] ??
                          MiniGameContent.defaults('preview', gameId: id))),
        ],
      ]));
}

class _GamePreview extends StatelessWidget {
  const _GamePreview({required this.content});
  final MiniGameContent content;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: AspectRatio(
                aspectRatio: 16 / 9, child: MiniGameCover(content: content))),
        const SizedBox(height: 10),
        Text(content.title,
            style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Move • Play • Earn',
            style:
                TextStyle(color: AppColors.inkSoft, fontSize: 11, height: 1.3)),
      ]));
}

class FreeRewardGoalPreview extends StatelessWidget {
  const FreeRewardGoalPreview(
      {super.key,
      required this.item,
      required this.onViewPlans,
      required this.onBrowse});
  final VerifiedRewardItem? item;
  final Future<void> Function() onViewPlans;
  final VoidCallback onBrowse;
  @override
  Widget build(BuildContext context) => LockedRewardsPreview(
      sectionTitle: 'My Reward Goal',
      title: 'Your points have possibilities',
      description: item?.premiumOnly == true
          ? 'Keep saving your points. This reward is exclusive to Premium members.'
          : 'Keep saving your points. Turn them into gym rewards with Basic or Premium.',
      previewLabel: item == null
          ? 'Reward shop preview. No published rewards available yet.'
          : '${item!.title}. ${item!.pointCost} points. Redemption requires membership.',
      onViewPlans: onViewPlans,
      onBrowse: onBrowse,
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            RewardCover(url: item?.imageUrl ?? ''),
            const SizedBox(height: 12),
            Text(item?.title ?? 'Find your next reward',
                style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.3)),
            const SizedBox(height: 6),
            Text(
                item == null
                    ? 'New rewards appear here when available'
                    : '${item!.pointCost} points',
                style: const TextStyle(
                    color: AppColors.primary, fontSize: 14, height: 1.3)),
            if (item?.premiumOnly == true)
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Premium Exclusive',
                      style:
                          TextStyle(color: AppColors.primary, fontSize: 12))),
          ])));
}
