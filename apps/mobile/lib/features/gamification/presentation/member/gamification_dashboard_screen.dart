import 'package:flutter/material.dart';
import '../../application/gamification_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/identity.dart';
import 'badges_screen.dart';
import 'leaderboard_screen.dart';
import 'mini_games_screen.dart';
import 'reward_shop_screen.dart';

class GamificationDashboardScreen extends StatelessWidget {
  const GamificationDashboardScreen({super.key});

  static const _activity = [
    ['Daily check-in claimed', '+50 pts', Icons.local_fire_department_rounded, AppColors.warning],
    ['New high score — Squat Rush', '+180 pts', Icons.sports_esports_rounded, AppColors.primary],
    ['Redeemed Protein Shake Voucher', '-400 pts', Icons.card_giftcard_rounded, AppColors.danger],
  ];

  @override
  Widget build(BuildContext context) {
    final unlocked = context.read<GamificationRepository>().badges.where((b) => b.unlocked).length;
    final rank = context.read<GamificationRepository>().leaderboard.firstWhere((r) => r[1] == context.read<MemberProfileRepository>().memberName, orElse: () => const ['—', '', '']);

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
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 10)),
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
                                  fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Colors.white70)),
                          const SizedBox(height: 6),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: context.watch<GamificationBloc>().state.points),
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
                          context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.leaderboard_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text('#${rank[0]} this week',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _miniStat(Icons.local_fire_department_rounded, '${context.watch<GamificationBloc>().state.streak} day streak'),
                    const SizedBox(width: 18),
                    _miniStat(Icons.military_tech_rounded, '$unlocked badges'),
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
                  context.watch<GamificationBloc>().state.streak / 14,
                  '${context.watch<GamificationBloc>().state.streak}/14',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 6),
                Text('Longest streak so far: ${context.watch<GamificationBloc>().state.longestStreak} days',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Explore'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              _ExploreCard(
                icon: Icons.sports_esports_rounded,
                color: AppColors.primary,
                title: 'Mini-games',
                stat: '${context.read<GamificationRepository>().miniGames.length} challenges',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MiniGamesScreen())),
              ),
              _ExploreCard(
                icon: Icons.military_tech_rounded,
                color: AppColors.warning,
                title: 'Badges',
                stat: '$unlocked/${context.read<GamificationRepository>().badges.length} unlocked',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen())),
              ),
              _ExploreCard(
                icon: Icons.card_giftcard_rounded,
                color: AppColors.success,
                title: 'Redeem points',
                stat: '${context.read<GamificationRepository>().rewards.length} rewards',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardShopScreen())),
              ),
              _ExploreCard(
                icon: Icons.leaderboard_rounded,
                color: AppColors.info,
                title: 'Leaderboard',
                stat: 'Rank #${rank[0]}',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
              ),
            ],
          ),
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
                        child: Icon(a[2] as IconData, size: 18, color: a[3] as Color),
                      ),
                      title: Text(a[0] as String,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                      trailing: Text(a[1] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: positive ? AppColors.success : AppColors.danger)),
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
  final VoidCallback onTap;

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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(stat, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

/// AD-M3.1 — Browse Mini-Games. A featured "Challenge of the Day" hero
/// plus a media-card grid for the rest, so the camera-tracked challenges
/// read as something worth picking, not settings rows.
