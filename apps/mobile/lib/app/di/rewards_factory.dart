import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../infrastructure/firebase/firebase_verified_rewards_repository.dart';
import 'coach_profile_factory.dart';

class RewardsFeatureHost extends StatelessWidget {
  const RewardsFeatureHost({super.key, required this.builder});
  final Widget Function(VerifiedRewardsRepository) builder;
  @override
  Widget build(BuildContext context) {
    final session = context.read<AuthBloc>().state.session;
    if (session == null) {
      return const Scaffold(
          body: Center(child: Text('Rewards unavailable for this session.')));
    }
    return CoachSessionHost(
        session: session,
        builder: (_, current) => builder(FirebaseVerifiedRewardsRepository(
            scope: session.scope, isCurrent: current)));
  }
}

/// Pushed vouchers must also hide captured account data when Auth changes.
class RewardsRepositoryGuard extends StatelessWidget {
  const RewardsRepositoryGuard(
      {super.key, required this.repository, required this.child});
  final VerifiedRewardsRepository repository;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!repository.connected) return child;
    return BlocBuilder<AuthBloc, AuthState>(
        builder: (_, state) => repository.current
            ? child
            : const Scaffold(
                body: Center(
                    child: Text('Rewards unavailable for this session.'))));
  }
}
