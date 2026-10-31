import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/rewards_feature_host.dart';

class FitnessArcadeRankHost extends StatefulWidget {
  const FitnessArcadeRankHost({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  State<FitnessArcadeRankHost> createState() => _FitnessArcadeRankHostState();
}

class _FitnessArcadeRankHostState extends State<FitnessArcadeRankHost> {
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc?>();
    return StreamBuilder<AuthState>(
        stream: auth?.stream,
        builder: (context, _) {
          if (auth == null ||
              auth.state.session == null ||
              !AuthRolePolicy.canEnter(auth.state,
                  allowed: const {AppRole.member})) {
            return FitnessArcadeRank(onTap: () => widget.onTap());
          }
          return RewardsFeatureHost(
              key: ObjectKey(auth.state.session),
              builder: (repo) => FitnessArcadeRank(
                  repository: repo, onTap: () => widget.onTap()));
        });
  }
}

/// The existing earned-points ranking, explicitly separate from Game Score.
class FitnessArcadeRank extends StatefulWidget {
  const FitnessArcadeRank({super.key, this.repository, required this.onTap});
  final VerifiedRewardsRepository? repository;
  final VoidCallback onTap;
  @override
  State<FitnessArcadeRank> createState() => _FitnessArcadeRankState();
}

class _FitnessArcadeRankState extends State<FitnessArcadeRank> {
  EarnedPointsLeaderboard? _result;
  bool _loading = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FitnessArcadeRank oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) unawaited(_load());
  }

  Future<void> _load() async {
    final repo = widget.repository, generation = ++_generation;
    _result = null;
    _loading = repo != null && repo.current;
    if (!_loading) return;
    EarnedPointsLeaderboard? result;
    try {
      final response = await repo!.leaderboard(period: 'week');
      if (response.period == 'week') result = response;
    } catch (_) {/* Unknown rank is never a synthetic zero. */}
    if (!mounted || generation != _generation) return;
    setState(() {
      _result = repo!.current ? result : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
      stream: context.read<AuthBloc?>()?.stream,
      builder: (context, _) {
        final current = widget.repository?.current ?? false;
        final own = current ? _result?.you : null;
        final label = _loading && current
            ? 'Loading…'
            : own == null
                ? 'Unavailable · Refresh to retry'
                : own.rank == null
                    ? 'You · Unranked · ${own.points} earned points'
                    : 'You · #${own.rank} · ${own.points} earned points';
        return Material(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
                key: const Key('arcade-weekly-rank'),
                borderRadius: BorderRadius.circular(18),
                onTap: widget.onTap,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(children: [
                      const Icon(Icons.leaderboard_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Earned-points weekly rank',
                                style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 14,
                                    height: 1.3,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(label),
                          ])),
                    ]))));
      });
}
