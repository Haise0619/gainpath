import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import '../../features/gamification/application/rewards_feature_host.dart';
import 'app_check_in_host.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/gamification/presentation/member/rewards_check_in_page.dart';
import '../../features/gamification/domain/app_check_in.dart';
import '../di/app_check_in_factory.dart';

List<int> weeklyEarnedReceipts(
    List<PointsHistoryEntry> entries, DateTime asOf) {
  final local = asOf.toUtc().add(const Duration(hours: 8));
  final monday = DateTime.utc(local.year, local.month, local.day)
      .subtract(Duration(days: local.weekday - 1));
  final result = List<int>.filled(7, 0);
  for (final e in entries) {
    if (e.wallet != 'spendable' ||
        e.points <= 0 ||
        e.occurredAtMillis > asOf.millisecondsSinceEpoch) {
      continue;
    }
    final day =
        DateTime.fromMillisecondsSinceEpoch(e.occurredAtMillis, isUtc: true)
            .add(const Duration(hours: 8));
    final entryMonday = DateTime.utc(day.year, day.month, day.day)
        .subtract(Duration(days: day.weekday - 1));
    final index = 6 - monday.difference(entryMonday).inDays ~/ 7;
    if (index >= 0 && index < 7) result[index] += e.points;
  }
  return result;
}

class LivePointsProgress extends StatelessWidget {
  const LivePointsProgress(
      {super.key,
      this.repository,
      this.checkInFactory = createAppCheckInRepository});
  final VerifiedRewardsRepository? repository;
  final AppCheckInRepositoryFactory checkInFactory;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        final session = state.session;
        if (session == null) {
          return const Scaffold(
              body: Center(child: Text('Sign in to view points.')));
        }
        Widget content(VerifiedRewardsRepository repo) => AppCheckInHost(
            key: ObjectKey(session),
            scope: session.scope,
            repositoryFactory: checkInFactory,
            builder: (checkIn, refresh, claim) => RewardsCheckInPage(
                key: ValueKey(session.scope),
                repository: repo,
                checkIn: checkIn,
                refreshCheckIn: refresh,
                claimCheckIn: claim));
        return repository == null
            ? RewardsFeatureHost(builder: content)
            : content(repository!);
      });
}
