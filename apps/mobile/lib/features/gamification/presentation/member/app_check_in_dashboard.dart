import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/app_check_in_cubit.dart';
import '../../domain/app_check_in.dart';
import 'app_check_in_card.dart';
import 'mini_games_screen.dart';
import 'reward_shop_screen.dart';
import 'my_rewards_screen.dart';
import 'leaderboard_screen.dart';
import 'points_history_screen.dart';
import '../../application/rewards_feature_host.dart';
import '../../application/mini_game_content_feature_host.dart';
import 'mini_game_reward_status_panel.dart';
import 'mini_game_participation_panel.dart';

class AppCheckInDashboard extends StatelessWidget {
  const AppCheckInDashboard(
      {super.key,
      required this.state,
      required this.onClaim,
      required this.onRefresh});
  final AppCheckInState state;
  final Future<void> Function() onClaim, onRefresh;

  void _history(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => RewardsFeatureHost(
              builder: (repo) => PointsHistoryScreen(repository: repo))));

  @override
  Widget build(BuildContext context) {
    final s = state.snapshot;
    final unlocked = s?.badges.where((b) => b.unlockedAtMillis != null).length;
    final pending = s?.badges.where((b) => b.unlockedAtMillis == null).toList()
      ?..sort((a, b) => a.requiredStreak.compareTo(b.requiredStreak));
    final next = pending == null || pending.isEmpty ? null : pending.first;
    final badgesKey = GlobalKey();
    final game = _ExploreCard(
        icon: Icons.sports_esports_rounded,
        color: AppColors.primary,
        title: 'Mini-games',
        stat: '1 camera game',
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => MiniGameContentFeatureHost(
                      builder: (reader, bestScores, rewards, participation) =>
                          MiniGamesScreen(
                              connected: true,
                              reader: reader,
                              bestScoreStore: bestScores,
                              rewardStatus: participation == null
                                  ? MiniGameRewardStatusPanel(reader: rewards)
                                  : MiniGameParticipationPanel(
                                      repository: participation)))));
          if (context.mounted) await onRefresh();
        });
    final badges = _ExploreCard(
        icon: Icons.military_tech_rounded,
        color: AppColors.warning,
        title: 'Badges',
        stat: s == null
            ? 'Load rewards to view'
            : '$unlocked/${s.badges.length} unlocked',
        onTap: () {
          final target = badgesKey.currentContext;
          if (target != null) {
            Scrollable.ensureVisible(target,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 250));
          }
        });
    final shop = _ExploreCard(
        icon: Icons.card_giftcard_rounded,
        color: AppColors.success,
        title: 'Redeem points',
        stat: 'Browse rewards',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => RewardShopScreen(
                    connected: true, onBalanceChanged: onRefresh))));
    final leaderboard = _ExploreCard(
        icon: Icons.leaderboard_rounded,
        color: AppColors.info,
        title: 'Leaderboard',
        stat: 'Weekly & all-time ranks',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => RewardsFeatureHost(
                    builder: (repo) => LeaderboardScreen(
                        connected: true, repository: repo)))));
    return Scaffold(
        appBar: AppBar(title: const Text('Rewards'), actions: [
          IconButton(
              tooltip: 'Points History',
              icon: const Icon(Icons.history),
              onPressed: () => _history(context)),
          IconButton(
              tooltip: 'Refresh rewards',
              onPressed: state.claiming ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded)),
        ]),
        body: RefreshIndicator(
            onRefresh: onRefresh,
            child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: .22),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10))
                              ]),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('YOUR POINTS',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        letterSpacing: 1.4,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text(s?.balance.toString() ?? '—',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 18),
                                Wrap(spacing: 20, runSpacing: 8, children: [
                                  _HeroStat(
                                      icon: Icons.local_fire_department_rounded,
                                      label: s == null
                                          ? 'Streak unavailable'
                                          : '${s.currentStreak} day streak'),
                                  _HeroStat(
                                      icon: Icons.military_tech_rounded,
                                      label: unlocked == null
                                          ? 'Badges unavailable'
                                          : '$unlocked ${unlocked == 1 ? 'badge' : 'badges'}'),
                                ]),
                                if (s == null) ...[
                                  const SizedBox(height: 8),
                                  const Text('Server balance unavailable',
                                      style: TextStyle(color: Colors.white))
                                ],
                              ])),
                      const SizedBox(height: 24),
                      const Eyebrow('Streak'),
                      Panel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            if (s == null)
                              const Text(
                                  'Your streak appears after rewards load.')
                            else ...[
                              ProgressRow(
                                  next == null
                                      ? 'All check-in badges unlocked'
                                      : next.requiredStreak == 1
                                          ? 'Progress to first check-in'
                                          : 'Progress to ${next.requiredStreak}-day badge',
                                  next == null
                                      ? 1
                                      : s.currentStreak / next.requiredStreak,
                                  next == null
                                      ? '${s.badges.length}/${s.badges.length}'
                                      : '${s.currentStreak}/${next.requiredStreak}',
                                  color: AppColors.accent),
                              const SizedBox(height: 6),
                              Text(
                                  'Longest streak so far: ${s.longestStreak} days',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ],
                            const SizedBox(height: 12),
                            AppCheckInCard(
                                state: state,
                                onClaim: onClaim,
                                onRefresh: onRefresh,
                                compact: true),
                          ])),
                      const SizedBox(height: 24),
                      const Eyebrow('Explore'),
                      LayoutBuilder(builder: (context, constraints) {
                        if (constraints.maxWidth < 330 ||
                            MediaQuery.textScalerOf(context).scale(14) > 21) {
                          return Column(children: [
                            for (final card in [
                              game,
                              badges,
                              shop,
                              leaderboard
                            ])
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: card)
                          ]);
                        }
                        Widget row(Widget a, Widget b) =>
                            IntrinsicHeight(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  Expanded(child: a),
                                  const SizedBox(width: 12),
                                  Expanded(child: b)
                                ]));
                        return Column(children: [
                          row(game, badges),
                          const SizedBox(height: 12),
                          row(shop, leaderboard)
                        ]);
                      }),
                      const SizedBox(height: 20),
                      const Eyebrow('More to explore'),
                      Panel(
                          padding: EdgeInsets.zero,
                          child: Column(children: [
                            ListTile(
                                leading: const Icon(
                                    Icons.confirmation_number_outlined,
                                    color: AppColors.primary),
                                title: const Text('My Rewards'),
                                subtitle: const Text(
                                    'Vouchers, details and collection QR'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const MyRewardsScreen()))),
                            const Divider(height: 1, indent: 56),
                            ListTile(
                                leading: const Icon(Icons.history_rounded,
                                    color: AppColors.primary),
                                title: const Text('Points History'),
                                subtitle:
                                    const Text('All earned and spent points'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _history(context)),
                          ])),
                      const SizedBox(height: 24),
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Eyebrow('Recent check-ins'),
                            TextButton(
                                onPressed: () => _history(context),
                                child: const Text('View all activity'))
                          ]),
                      Panel(
                          padding: EdgeInsets.zero,
                          child: s == null || s.recentClaims.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(s == null
                                      ? 'Check-in activity appears after rewards load.'
                                      : 'No app check-ins yet. Claim your first check-in above.'))
                              : Column(children: [
                                  for (var i = 0;
                                      i < s.recentClaims.take(3).length;
                                      i++) ...[
                                    if (i > 0)
                                      const Divider(height: 1, indent: 64),
                                    _CheckInActivity(claim: s.recentClaims[i]),
                                  ]
                                ])),
                      const SizedBox(height: 24),
                      Eyebrow('Check-in badges', key: badgesKey),
                      if (s == null)
                        const Text('Your badges appear after rewards load.')
                      else
                        for (final badge in s.badges)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Panel(
                                  padding: EdgeInsets.zero,
                                  child: ListTile(
                                      leading: Icon(
                                          badge.unlockedAtMillis == null
                                              ? Icons.lock_outline_rounded
                                              : Icons.workspace_premium_rounded,
                                          color: badge.unlockedAtMillis == null
                                              ? AppColors.inkSoft
                                              : AppColors.primary),
                                      title: Text(badge.title),
                                      subtitle: Text(badge.unlockedAtMillis ==
                                              null
                                          ? '${badge.requiredStreak} consecutive check-in day${badge.requiredStreak == 1 ? '' : 's'}'
                                          : 'Unlocked · no additional points')))),
                    ]))));
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600))),
      ]);
}

/// Reuses the original Rewards Explore card styling without fixed grid heights.
class _ExploreCard extends StatelessWidget {
  const _ExploreCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.stat,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String title, stat;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Panel(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 23)),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(stat, style: Theme.of(context).textTheme.bodyMedium),
      ]));
}

class _CheckInActivity extends StatelessWidget {
  const _CheckInActivity({required this.claim});
  final AppCheckInClaim claim;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.local_fire_department_rounded,
                color: AppColors.warning, size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 6,
                children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Daily check-in claimed',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(claim.date, style: Theme.of(context).textTheme.bodySmall),
              ]),
              Text('+${claim.points} pts',
                  style: const TextStyle(
                      color: AppColors.success, fontWeight: FontWeight.w700)),
            ])),
      ]));
}
