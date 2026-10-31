import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/app_check_in_cubit.dart';
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

/// P1A: composition only; existing check-in/earning/game/redemption services own state.
class AppCheckInDashboard extends StatefulWidget {
  const AppCheckInDashboard(
      {super.key,
      required this.state,
      required this.onClaim,
      required this.onRefresh,
      this.gamesSection,
      this.weeklyRankSection});
  final AppCheckInState state;
  final Future<void> Function() onClaim, onRefresh;
  final Widget? gamesSection, weeklyRankSection;
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
    await _walletRefresh();
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
  void _rankings(BuildContext context) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => RewardsFeatureHost(
              builder: (repo) =>
                  LeaderboardScreen(connected: true, repository: repo))));
  void _badges(BuildContext context) {
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                              borderRadius: BorderRadius.circular(22)),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('YOUR POINTS',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(s?.balance.toString() ?? '—',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800)),
                                  if (s == null)
                                    const Text('Balance unavailable',
                                        style: TextStyle(color: Colors.white)),
                                ])),
                            IconButton(
                                tooltip: 'Points History',
                                onPressed: () => _history(context),
                                icon: const Icon(Icons.history_rounded,
                                    color: Colors.white)),
                          ])),
                      const SizedBox(height: 12),
                      Panel(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      Text('Daily check-in',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      Text(
                                          s == null
                                              ? 'Streak unavailable'
                                              : '${s.currentStreak} day streak',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ]),
                                if (s != null) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    for (final day in s.days)
                                      Expanded(
                                          child: Semantics(
                                              label:
                                                  '${day.date}, ${day.claimed ? 'checked in' : 'not checked in'}',
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 2),
                                                  child: Container(
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                          color: day.claimed
                                                              ? AppColors
                                                                  .primary
                                                              : AppColors
                                                                  .hairline,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  6),
                                                          border: day.date ==
                                                                  s.today
                                                              ? Border.all(
                                                                  color: AppColors
                                                                      .primary)
                                                              : null)))))
                                  ]),
                                ],
                                const SizedBox(height: 8),
                                AppCheckInCard(
                                    state: state,
                                    onClaim: onClaim,
                                    onRefresh: onRefresh,
                                    compact: true),
                              ])),
                      const SizedBox(height: 18),
                      widget.gamesSection ??
                          FitnessArcadeHost(
                              key: ValueKey('games-$_gamesRevision'),
                              onReturn: _afterGame),
                      const SizedBox(height: 16),
                      widget.weeklyRankSection ??
                          FitnessArcadeRankHost(
                              key: ValueKey('rank-$_rankRevision'),
                              onTap: () => _rankings(context)),
                      const SizedBox(height: 12),
                      RewardGoalHost(
                          key: ValueKey('goal-$_rankRevision'),
                          onShop: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) => RewardShopScreen(
                                      connected: true,
                                      onBalanceChanged: onRefresh))),
                          fallback: Panel(
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                  leading: const Icon(
                                      Icons.card_giftcard_rounded,
                                      color: AppColors.primary),
                                  title: const Text('Redeem points'),
                                  subtitle: const Text('Find your next reward'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (_) => RewardShopScreen(
                                              connected: true,
                                              onBalanceChanged: onRefresh)))))),
                      const SizedBox(height: 12),
                      Panel(
                          padding: EdgeInsets.zero,
                          child: Column(children: [
                            _Shortcut(
                                icon: Icons.confirmation_number_outlined,
                                title: 'My Rewards',
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const MyRewardsScreen()))),
                            _Shortcut(
                                icon: Icons.military_tech_outlined,
                                title: 'Badges',
                                onTap: () => _badges(context)),
                            _Shortcut(
                                icon: Icons.history_rounded,
                                title: 'Points History',
                                onTap: () => _history(context)),
                            _Shortcut(
                                icon: Icons.leaderboard_outlined,
                                title: 'Leaderboards',
                                onTap: () => _rankings(context)),
                          ])),
                    ]))));
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(
      {required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap);
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
          if (unlocked) ...[
            const Text('No additional points'),
            ShareCheckInBadgeButton(badge: badge)
          ],
        ])));
  }
}
