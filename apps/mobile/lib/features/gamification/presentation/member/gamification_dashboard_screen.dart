import 'dart:math' as math;
import '../../application/app_check_in_cubit.dart';
import 'app_check_in_dashboard.dart';
import 'package:flutter/material.dart';
import '../../application/gamification_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/identity.dart';
import 'badges_screen.dart';
import 'leaderboard_screen.dart';
import '../../application/rewards_feature_host.dart';
import 'mini_games_screen.dart';
import 'reward_shop_screen.dart';

class GamificationDashboardScreen extends StatelessWidget {
  const GamificationDashboardScreen(
      {super.key,
      this.live = false,
      this.checkIn,
      this.onClaim,
      this.onRefreshCheckIn});
  final AppCheckInState? checkIn;
  final Future<void> Function()? onClaim, onRefreshCheckIn;
  final bool live;

  static const _activity = [
    [
      'Daily check-in claimed',
      '+50 pts',
      Icons.local_fire_department_rounded,
      AppColors.warning
    ],
    [
      'New high score - Squat Rush',
      '+180 pts',
      Icons.sports_esports_rounded,
      AppColors.primary
    ],
    [
      'Redeemed Protein Shake Voucher',
      '-400 pts',
      Icons.card_giftcard_rounded,
      AppColors.danger
    ],
  ];

  @override
  Widget build(BuildContext context) {
    if (live && checkIn != null) {
      return AppCheckInDashboard(
          state: checkIn!,
          onClaim: onClaim ?? () async {},
          onRefresh: onRefreshCheckIn ?? () async {});
    }
    final unlocked = live
        ? null
        : context
            .read<GamificationRepository>()
            .badges
            .where((b) => b.unlocked)
            .length;
    final rank = live
        ? const ['-', '', '']
        : context.read<GamificationRepository>().leaderboard.firstWhere(
            (r) => r[1] == context.read<MemberProfileRepository>().memberName,
            orElse: () => const ['-', '', '']);

    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: PageBody(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('YOUR POINTS',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70)),
                          const SizedBox(height: 6),
                          if (live)
                            const Text('-',
                                style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white))
                          else
                            TweenAnimationBuilder<int>(
                              tween: IntTween(
                                  begin: 0,
                                  end: context
                                      .watch<GamificationBloc>()
                                      .state
                                      .points),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) => Text('$value',
                                  style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.1,
                                      letterSpacing: -1.5)),
                            ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => live
                                  ? RewardsFeatureHost(
                                      builder: (repo) => LeaderboardScreen(
                                          connected: true, repository: repo))
                                  : const LeaderboardScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.leaderboard_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text('#${rank[0]} this week',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _miniStat(
                        Icons.local_fire_department_rounded,
                        live
                            ? 'Streak -'
                            : '${context.watch<GamificationBloc>().state.streak} day streak'),
                    _miniStat(Icons.military_tech_rounded,
                        live ? 'Badges -' : '$unlocked badges'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Streak'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProgressRow(
                  'Progress to 14-day badge',
                  live
                      ? 0
                      : context.watch<GamificationBloc>().state.streak / 14,
                  live
                      ? '-'
                      : '${context.watch<GamificationBloc>().state.streak}/14',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 6),
                Text(
                    live
                        ? 'Streak history is not connected yet.'
                        : 'Longest streak so far: ${context.watch<GamificationBloc>().state.longestStreak} days',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Explore'),
          LayoutBuilder(builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 12) / 2;
            final titleStyle = Theme.of(context).textTheme.titleMedium;
            final statStyle =
                Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12);
            double heightOf(String text, TextStyle? style) {
              final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textScaler: MediaQuery.textScalerOf(context),
                  textDirection: Directionality.of(context))
                ..layout(maxWidth: math.max(1, tileWidth - 34));
              final height = painter.height;
              painter.dispose();
              return height;
            }

            final titleHeight = [
              'Mini-games',
              'Badges',
              'Redeem points',
              'Leaderboard'
            ].map((title) => heightOf(title, titleStyle)).reduce(math.max);
            return GridView.count(
              childAspectRatio: tileWidth /
                  math.max(
                      tileWidth / 1.25,
                      42 +
                          14 +
                          titleHeight +
                          2 +
                          heightOf('-', statStyle) +
                          34),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _ExploreCard(
                  icon: Icons.sports_esports_rounded,
                  color: AppColors.primary,
                  title: 'Mini-games',
                  stat: live
                      ? '-'
                      : '${context.read<GamificationRepository>().miniGames.length} challenges',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MiniGamesScreen(connected: live))),
                ),
                _ExploreCard(
                  icon: Icons.military_tech_rounded,
                  color: AppColors.warning,
                  title: 'Badges',
                  stat: live
                      ? '-'
                      : '$unlocked/${context.read<GamificationRepository>().badges.length} unlocked',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => BadgesScreen(connected: live))),
                ),
                _ExploreCard(
                  icon: Icons.card_giftcard_rounded,
                  color: AppColors.success,
                  title: 'Redeem points',
                  stat: live
                      ? '-'
                      : '${context.read<GamificationRepository>().rewards.length} rewards',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => RewardShopScreen(connected: live))),
                ),
                _ExploreCard(
                  icon: Icons.leaderboard_rounded,
                  color: AppColors.info,
                  title: 'Leaderboard',
                  stat: live ? '-' : 'Rank #${rank[0]}',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => live
                              ? RewardsFeatureHost(
                                  builder: (repo) => LeaderboardScreen(
                                      connected: true, repository: repo))
                              : const LeaderboardScreen())),
                ),
              ],
            );
          }),
          const SizedBox(height: 20),
          const Eyebrow('Recent activity'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(_activity.length, (i) {
                final a = _activity[i];
                final positive = (a[1] as String).startsWith('+');
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, indent: 62),
                    ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: (a[3] as Color).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(a[2] as IconData,
                            size: 18, color: a[3] as Color),
                      ),
                      title: Text(live ? '-' : a[0] as String,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                      trailing: Text(live ? '-' : a[1] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: positive
                                  ? AppColors.success
                                  : AppColors.danger)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      );
}

class _ExploreCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String stat;
  final VoidCallback? onTap;

  const _ExploreCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.stat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(stat,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

/// AD-M3.1 - Browse Mini-Games. A featured "Challenge of the Day" hero
/// plus a media-card grid for the rest, so the camera-tracked challenges
/// read as something worth picking, not settings rows.
