import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../application/member_achievements_controller.dart';
import '../../domain/member_achievements.dart';
import 'achievement_artwork.dart';
import 'achievement_sharing.dart';

class MemberAchievementsScreen extends StatefulWidget {
  const MemberAchievementsScreen({super.key, required this.controller});

  final MemberAchievementsController controller;

  @override
  State<MemberAchievementsScreen> createState() =>
      _MemberAchievementsScreenState();
}

class _MemberAchievementsScreenState extends State<MemberAchievementsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.loadIfNeeded());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('My Achievements'),
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.ink,
        ),
        backgroundColor: AppColors.bg,
        body: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final controller = widget.controller;
            final data = controller.snapshot;
            if (data == null) {
              if (!controller.current) {
                return const Center(
                    child: Text('Achievements unavailable for this session.'));
              }
              return Center(
                child: controller.failed
                    ? FilledButton.tonal(
                        onPressed: controller.refresh,
                        child: const Text('Retry loading achievements'),
                      )
                    : const CircularProgressIndicator(
                        semanticsLabel: 'Loading achievements'),
              );
            }
            return RefreshIndicator(
              onRefresh: controller.refresh,
              child: LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
                final outer = width >= 600 ? 24.0 : 14.0;
                const gap = 10.0;
                final tileWidth =
                    (width - 2 * outer - (columns - 1) * gap) / columns;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(outer, 8, outer,
                      24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    _Overview(data: data),
                    if (controller.stale) ...[
                      const SizedBox(height: 10),
                      const Text('Showing last synced achievements.'),
                    ],
                    if (!data.complete) ...[
                      const SizedBox(height: 10),
                      const Text(
                          'Some workout progress is still being synced.'),
                    ],
                    if (data.next case final next?) ...[
                      const SizedBox(height: 18),
                      _NextAchievement(
                        badge: next,
                        onTap: () =>
                            showAchievementDetails(context, controller, next),
                      ),
                    ],
                    for (final category in const ['check-in', 'workout'])
                      if (data.badges
                          .any((badge) => badge.category == category)) ...[
                        const SizedBox(height: 22),
                        Text(
                          category == 'check-in'
                              ? 'Check-in Achievements'
                              : 'Workout Achievements',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.ink),
                        ),
                        if (category == 'workout' && data.complete)
                          const Text(
                              'Progress updates after Workout Backup syncs.',
                              style: TextStyle(color: AppColors.inkSoft)),
                        const SizedBox(height: 9),
                        _AchievementGrid(
                          badges: data.badges
                              .where((badge) => badge.category == category)
                              .toList(),
                          columns: columns,
                          tileWidth: tileWidth,
                          gap: gap,
                          onTap: (badge) => showAchievementDetails(
                              context, controller, badge),
                        ),
                      ],
                  ],
                );
              }),
            );
          },
        ),
      );
}

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid({
    required this.badges,
    required this.columns,
    required this.tileWidth,
    required this.gap,
    required this.onTap,
  });

  final List<MemberAchievement> badges;
  final int columns;
  final double tileWidth, gap;
  final ValueChanged<MemberAchievement> onTap;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var start = 0; start < badges.length; start += columns) ...[
            if (start > 0) SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final badge in badges.skip(start).take(columns)) ...[
                    if (badge != badges[start]) SizedBox(width: gap),
                    SizedBox(
                      width: tileWidth,
                      child: _AchievementTile(
                        badge: badge,
                        onTap: () => onTap(badge),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data});

  final MemberAchievements data;

  @override
  Widget build(BuildContext context) {
    final unlocked = data.unlockedCount;
    final total = data.badges.length;
    final fraction = total == 0 ? 0.0 : unlocked / total;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF28174E), Color(0xFF583293)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('$unlocked / $total badges unlocked',
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: fraction,
            semanticsLabel: 'Collection completion',
            backgroundColor: const Color(0xFF6C5692),
            color: const Color(0xFFE2CCFF),
            stopIndicatorColor: Colors.transparent,
            trackGap: 0,
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 8),
          Text(
              '${(fraction * 100).round()}% complete  •  ${data.currentStreak}-day streak',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFFF2E5FF))),
        ]),
      ),
    );
  }
}

class _NextAchievement extends StatelessWidget {
  const _NextAchievement({required this.badge, required this.onTap});

  final MemberAchievement badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = (badge.target - badge.progress).clamp(0, badge.target);
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Next Achievement',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: AppColors.primaryDark)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AchievementArtwork(id: badge.id, unlocked: true, size: 65),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(badge.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: AppColors.ink)),
                      const SizedBox(height: 3),
                      Text(badge.description,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.inkSoft)),
                    ]),
              ),
            ]),
            const SizedBox(height: 8),
            _AchievementProgressBar(badge: badge),
            const SizedBox(height: 6),
            Text('${badge.progressLabel} · $remaining remaining',
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: AppColors.ink)),
          ]),
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.badge, required this.onTap});

  final MemberAchievement badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor =
        badge.unlocked ? AppColors.primaryDark : AppColors.membershipFreeInk;
    final titleColor = badge.unlocked ? Colors.white : AppColors.ink;
    return Material(
      color: badge.unlocked
          ? const Color(0xFF37205F)
          : AppColors.membershipFreeTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(
            color: badge.unlocked
                ? const Color(0xFF694594)
                : const Color(0xFFCBD5E1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            SizedBox(
              width: 78,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AchievementArtwork(
                      id: badge.id, unlocked: badge.unlocked, size: 68),
                  if (!badge.unlocked)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.membershipFreeInk,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(
                            color: AppColors.membershipFreeTint,
                            width: 2,
                          )),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.lock_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(badge.title,
                style: theme.textTheme.titleMedium?.copyWith(color: titleColor),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color:
                    badge.unlocked ? AppColors.primaryTint : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Icon(
                      badge.unlocked
                          ? Icons.check_circle_rounded
                          : Icons.lock_outline_rounded,
                      color: statusColor,
                      size: 14,
                    ),
                    Text(badge.unlocked ? 'Unlocked' : 'Locked',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AchievementProgressBar extends StatelessWidget {
  const _AchievementProgressBar({required this.badge});

  final MemberAchievement badge;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
        value: badge.fraction,
        semanticsLabel: badge.progressLabel,
        color: AppColors.primary,
        backgroundColor: AppColors.hairline,
        stopIndicatorColor: Colors.transparent,
        trackGap: 0,
        minHeight: 7,
        borderRadius: BorderRadius.circular(20),
      );
}

Future<void> showAchievementDetails(BuildContext context,
    MemberAchievementsController controller, MemberAchievement initial) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final badge = controller.snapshot?.badges
            .where((badge) => badge.id == initial.id)
            .firstOrNull;
        if (badge == null) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Achievement unavailable for this session.'),
          );
        }
        final theme = Theme.of(context);
        final date = badge.unlockedAt?.add(const Duration(hours: 8));
        final progressKnown =
            controller.snapshot!.complete || badge.category == 'check-in';
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 0, 24, 24 + MediaQuery.paddingOf(context).bottom),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
                child: AchievementArtwork(
                    id: badge.id, unlocked: badge.unlocked, size: 102)),
            const SizedBox(height: 10),
            Text(badge.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: AppColors.ink)),
            const SizedBox(height: 5),
            Text(
                date == null
                    ? 'Locked'
                    : 'Unlocked · ${MaterialLocalizations.of(context).formatMediumDate(date)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 16),
            Text('Unlock requirement',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: AppColors.ink)),
            Text(badge.description,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 12),
            if (progressKnown || badge.unlocked) ...[
              _AchievementProgressBar(badge: badge),
              const SizedBox(height: 5),
              Text(badge.progressLabel,
                  style: const TextStyle(color: AppColors.ink)),
            ] else
              const Text('Workout progress unavailable until sync completes.'),
            if (badge.unlocked) ...[
              const SizedBox(height: 14),
              AchievementShareButton(badge: badge, controller: controller),
            ],
          ]),
        );
      },
    ),
  );
}

class AchievementShareButton extends StatefulWidget {
  const AchievementShareButton(
      {super.key,
      required this.badge,
      required this.controller,
      this.compact = false});

  final MemberAchievement badge;
  final MemberAchievementsController controller;
  final bool compact;

  @override
  State<AchievementShareButton> createState() => _AchievementShareButtonState();
}

class _AchievementShareButtonState extends State<AchievementShareButton> {
  bool _busy = false;

  Future<void> _share() async {
    final controller = widget.controller;
    if (_busy || !controller.current) return;
    final badge = widget.badge;
    bool sameSession() =>
        mounted &&
        identical(widget.controller, controller) &&
        controller.current;
    setState(() => _busy = true);
    try {
      await shareAchievement(
          id: badge.id,
          name: badge.title,
          description: badge.description,
          unlockedAt: badge.unlockedAt!,
          isCurrent: sameSession);
    } catch (_) {
      if (sameSession()) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            content: Text('Sharing is unavailable. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.compact
      ? TextButton(onPressed: _busy ? null : _share, child: const Text('Share'))
      : FilledButton.icon(
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(_busy ? 'Opening…' : 'Share Achievement'));
}
