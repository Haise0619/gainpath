import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'mini_game_details_screen.dart';
import 'reward_details.dart';

/// A preview is informational: only the foreground membership actions are live.
class LockedRewardsPreview extends StatelessWidget {
  const LockedRewardsPreview(
      {super.key,
      required this.sectionTitle,
      required this.title,
      required this.description,
      required this.previewLabel,
      required this.onViewPlans,
      required this.child,
      this.onBrowse});
  final String sectionTitle, title, description, previewLabel;
  final Future<void> Function() onViewPlans;
  final VoidCallback? onBrowse;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final overlay = Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: .07),
                  blurRadius: 18,
                  offset: const Offset(0, 5))
            ]),
        child: Column(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: AppColors.primaryTint, shape: BoxShape.circle),
              child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: Colors.white, size: 24))),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.inkSoft, fontSize: 14, height: 1.45)),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: onViewPlans,
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 50),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: const Text('View membership plans',
                      textAlign: TextAlign.center))),
          if (onBrowse != null)
            TextButton(
                onPressed: onBrowse,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child:
                    const Text('Browse rewards', textAlign: TextAlign.center)),
        ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(sectionTitle,
          style: const TextStyle(
              color: AppColors.ink,
              fontSize: 19,
              height: 1.25,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      DecoratedBox(
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryTint, AppColors.bg]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.hairline)),
          child: Column(children: [
            Semantics(
                label: previewLabel,
                child: IgnorePointer(
                    key: const ValueKey('locked-preview-content'),
                    child: ExcludeFocus(
                        child: ExcludeSemantics(
                            child: Opacity(
                                opacity: .62,
                                child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 12, 12, 30),
                                    child: child)))))),
            // The foreground overlaps the preview surface without fixing its height.
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 240),
                        child: overlay,
                        builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                                offset: Offset(0, (1 - value) * 6),
                                child: child))))),
          ])),
    ]);
  }
}

class FreeMiniGamesPreview extends StatelessWidget {
  const FreeMiniGamesPreview({super.key, required this.onViewPlans});
  final Future<void> Function() onViewPlans;
  @override
  Widget build(BuildContext context) => LockedRewardsPreview(
      sectionTitle: 'Play Mini-Games',
      title: 'More play. More possibilities.',
      description:
          'Unlock Mini-Games with Basic or Premium. Keep earning your daily check-in points for free.',
      previewLabel:
          'Move & Catch and Reach & Tap. Mini-Games require Basic or Premium membership.',
      onViewPlans: onViewPlans,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final id in [
          MiniGameContent.supportedId,
          MiniGameContent.reachTapId
        ]) ...[
          if (id == MiniGameContent.reachTapId) const SizedBox(width: 10),
          Expanded(
              child: _GamePreview(
                  content: MiniGameContent.defaults('preview', gameId: id))),
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
                aspectRatio: 1.25, child: MiniGameCover(content: content))),
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
