import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import '../../../infrastructure/local/reward_goal_store.dart';
import '../presentation/member/reward_goal_card.dart';
import 'rewards_feature_host.dart';

class RewardGoalHost extends StatelessWidget {
  const RewardGoalHost(
      {super.key, required this.onShop, required this.fallback});
  final FutureOr<void> Function() onShop;
  final Widget fallback;
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc?>();
    if (auth == null) return fallback;
    return StreamBuilder<AuthState>(
        stream: auth.stream,
        builder: (context, _) {
          final session = auth.state.session;
          if (session == null ||
              !AuthRolePolicy.canEnter(auth.state,
                  allowed: const {AppRole.member})) {
            return fallback;
          }
          return RewardsFeatureHost(
              key: ObjectKey(session),
              builder: (repo) => RewardGoalCard(
                  repository: repo,
                  scope: session.scope,
                  store: LocalRewardGoalStore(),
                  onShop: onShop));
        });
  }
}
