import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/app_check_in_cubit.dart';
import '../../application/member_achievements_controller.dart';
import '../../application/rewards_feature_host.dart';
import '../../application/reward_goal_host.dart';
import '../../application/share_check_in_badge_button.dart';
import '../../domain/app_check_in.dart';
import 'app_check_in_card.dart';
import 'fitness_arcade_games.dart';
import 'fitness_arcade_rank.dart';
import 'reward_shop_screen.dart';
import 'my_rewards_screen.dart';
import 'leaderboard_screen.dart';
import 'points_history_screen.dart';
import 'member_achievements_screen.dart';
import 'training_achievement_preview.dart';

/// P1A: composition only; existing check-in/earning/game/redemption services own state.
class AppCheckInDashboard extends StatefulWidget {
  const AppCheckInDashboard(
      {super.key,
      required this.state,
      required this.onClaim,
      required this.onRefresh,
      this.achievements,
      this.gamesSection,
      this.weeklyRankSection,
      this.rewardGoalSection});
  final AppCheckInState state;
  final Future<void> Function() onClaim, onRefresh;
  final MemberAchievementsController? achievements;
  final Widget? gamesSection, weeklyRankSection, rewardGoalSection;
  @override
  State<AppCheckInDashboard> createState() => _AppCheckInDashboardState();
}

class _AppCheckInDashboardState extends State<AppCheckInDashboard> {
  int _gamesRevision = 0, _rankRevision = 0;
  Future<void>? _refreshRequest;
  Future<void> _walletRefresh() =>
      _refreshRequest ??= Future<void>.sync(widget.onRefresh).whenComplete(() {
        _refreshRequest = null;
      });
  AppCheckInState get state => widget.state;
  Future<void> _refresh() async {
    final scope = state.snapshot?.scope;
    final achievements = widget.achievements;
    await Future.wait<void>([
      _walletRefresh(),
      if (achievements != null) achievements.refresh(),
    ]);
    if (mounted && state.snapshot?.scope == scope) {
      setState(() {
        _gamesRevision++;
        _rankRevision++;
      });
    }
  }

  Future<void> _afterGame() async {
    final scope = state.snapshot?.scope;
    await _walletRefresh();
    if (mounted && state.snapshot?.scope == scope) {
      setState(() => _rankRevision++);
    }
  }

  Future<void> _claim() async {
    final scope = state.snapshot?.scope;
    await widget.onClaim();
    if (mounted && state.snapshot?.scope == scope) {
      setState(() => _rankRevision++);
    }
  }

  Future<void> Function() get onRefresh => _refresh;
  Future<void> Function() get onClaim => _claim;

  void _history(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => RewardsFeatureHost(
              builder: (repo) => PointsHistoryScreen(repository: repo))));
  Future<void> _shop(BuildContext context) => Navigator.of(context).push<void>(
        MaterialPageRoute(
            builder: (_) => RewardShopScreen(
                  connected: true,
                  onBalanceChanged: onRefresh,
                )),
      );

  void _rankings(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => RewardsFeatureHost(
              builder: (repo) =>
                  LeaderboardScreen(connected: true, repository: repo))));
  void _badges(BuildContext context) {
    if (widget.achievements case final controller?) {
      Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) =>
                  MemberAchievementsScreen(controller: controller)));
      return;
    }
    final snapshot = state.snapshot;
    final auth = context.read<AuthBloc?>();
    final captured = auth?.state.session;
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => StreamBuilder<AuthState>(
                stream: auth?.stream,
                builder: (_, __) {
                  final current = auth == null ||
                      (identical(auth.state.session, captured) &&
                          captured?.scope == snapshot?.scope &&
                          AuthRolePolicy.canEnter(auth.state,
                              allowed: const {AppRole.member}));
                  return Scaffold(
                      appBar: AppBar(title: const Text('Check-in badges')),
                      body: !current || snapshot == null
                          ? const Center(
                              child:
                                  Text('Badges unavailable for this session.'))
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                  Text(
                                      '${snapshot.badges.where((b) => b.unlockedAtMillis != null).length}/${snapshot.badges.length} unlocked',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 16),
                                  for (final badge in snapshot.badges)
                                    _BadgeProgress(
                                        badge: badge, snapshot: snapshot),
                                ]));
                })));
  }

  @override
  Widget build(BuildContext context) {
    final achievements = widget.achievements;
    final s = state.snapshot;
    return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Rewards')),
        body: RefreshIndicator(
            onRefresh: onRefresh,
            child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.heroGradient,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/rewards_hero_banner.webp',
                                  fit: BoxFit.cover,
                                  alignment: Alignment.centerRight,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.25),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('YOUR POINTS',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  letterSpacing: 1,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              SvgPicture.asset(
                                                'assets/icons/reward_point.svg',
                                                width: 32,
                                                height: 32,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(s?.balance.toString() ?? '—',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .displaySmall
                                                      ?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w800)),
                                            ],
                                          ),
                                          if (s == null)
                                            const Text('Balance unavailable',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF190F2E)
                                            .withValues(alpha: 0.45),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.25),
                                          width: 1,
                                        ),
                                      ),
                                      child: IconButton(
                                        tooltip: 'Points History',
                                        onPressed: () => _history(context),
                                        icon: const Icon(Icons.history_rounded,
                                            color: Colors.white, size: 22),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      AppCheckInCard(
                        state: state,
                        onClaim: onClaim,
                        onRefresh: onRefresh,
                        homeDense: true,
                      ),
                      const SizedBox(height: 26),
                      TrainingAchievementPreview(
                        controller: achievements,
                        onViewAll: () => _badges(context),
                      ),
                      const SizedBox(height: 26),
                      widget.gamesSection ??
                          FitnessArcadeHost(
                              key: ValueKey('games-$_gamesRevision'),
                              onReturn: _afterGame),
                      const SizedBox(height: 26),
                      widget.weeklyRankSection ??
                          FitnessArcadeRankHost(
                              key: ValueKey('rank-$_rankRevision'),
                              onTap: () => _rankings(context)),
                      const SizedBox(height: 26),
                      Row(children: [
                        const Expanded(
                            child: MemberSectionHeader(
                                title: 'Points & vouchers', padded: false)),
                        TextButton(
                          onPressed: () => _shop(context),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Shop'),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 16),
                              ]),
                        ),
                      ]),
                      widget.rewardGoalSection ??
                          RewardGoalHost(
                            key: ValueKey('goal-$_rankRevision'),
                            onShop: () => _shop(context),
                            onBalanceChanged: onRefresh,
                            fallback: const SizedBox.shrink(),
                          ),
                      const SizedBox(height: 26),
                      LayoutBuilder(builder: (context, constraints) {
                        final actions = [
                          _WalletAction(
                            icon: Icons.confirmation_number_outlined,
                            label: 'My Rewards',
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                  builder: (_) => const MyRewardsScreen()),
                            ),
                          ),
                          _WalletAction(
                            icon: Icons.history_rounded,
                            label: 'Points History',
                            onTap: () => _history(context),
                          ),
                        ];
                        final scale =
                            MediaQuery.textScalerOf(context).scale(14);
                        if (constraints.maxWidth < 285 || scale > 23) {
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                actions.first,
                                const SizedBox(height: 8),
                                actions.last,
                              ]);
                        }
                        return Row(children: [
                          Expanded(child: actions.first),
                          const SizedBox(width: 10),
                          Expanded(child: actions.last),
                        ]);
                      }),
                    ]))));
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600))),
        Icon(Icons.chevron_right,
            size: 16, color: theme.colorScheme.onSurfaceVariant),
      ]),
    );
  }
}

class _BadgeProgress extends StatelessWidget {
  const _BadgeProgress({required this.badge, required this.snapshot});
  final AppCheckInBadge badge;
  final AppCheckInSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final unlocked = badge.unlockedAtMillis != null;
    final progress = snapshot.currentStreak.clamp(0, badge.requiredStreak);
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                  unlocked
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_outline,
                  color: unlocked ? AppColors.primary : AppColors.inkSoft),
              title: Text(badge.title),
              subtitle: Text(unlocked
                  ? 'Unlocked · ${DateTime.fromMillisecondsSinceEpoch(badge.unlockedAtMillis!, isUtc: true).add(const Duration(hours: 8)).toIso8601String().substring(0, 10)}'
                  : '$progress/${badge.requiredStreak} days')),
          if (!unlocked)
            LinearProgressIndicator(value: progress / badge.requiredStreak),
          if (unlocked) ...[ShareCheckInBadgeButton(badge: badge)],
        ])));
  }
}
