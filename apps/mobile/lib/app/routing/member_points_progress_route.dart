import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import '../../features/gamification/application/rewards_feature_host.dart';
import 'app_check_in_host.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/gamification/presentation/member/points_history_screen.dart';
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
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      final session = state.session;
      if (session == null) {
        return const Scaffold(
            body: Center(child: Text('Sign in to view points.')));
      }
      Widget content(VerifiedRewardsRepository repo) => AppCheckInHost(
          key: ObjectKey(session),
          scope: session.scope,
          repositoryFactory: checkInFactory,
          builder: (checkIn, refresh, claim) => _PointsReceipts(
              repository: repo,
              streak: checkIn.snapshot?.currentStreak,
              longest: checkIn.snapshot?.longestStreak));
      return repository == null
          ? RewardsFeatureHost(builder: content)
          : content(repository!);
    });
  }
}

class _PointsReceipts extends StatefulWidget {
  const _PointsReceipts({required this.repository, this.streak, this.longest});
  final VerifiedRewardsRepository repository;
  final int? streak, longest;
  @override
  State<_PointsReceipts> createState() => _PointsReceiptsState();
}

class _PointsReceiptsState extends State<_PointsReceipts> {
  late final Future<PointsHistorySnapshot> _future =
      widget.repository.pointsHistory();
  @override
  Widget build(BuildContext context) => RewardsRepositoryGuard(
      repository: widget.repository,
      child: Scaffold(
          appBar: AppBar(title: const Text('Points & streak')),
          body: FutureBuilder<PointsHistorySnapshot>(
              future: _future,
              builder: (context, snapshot) {
                if (!widget.repository.current) {
                  return const Center(
                      child: Text('Points unavailable for this session.'));
                }
                if (snapshot.hasError) {
                  return const Center(
                      child:
                          Text('Points history unavailable. Reopen to retry.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                final weeks =
                    weeklyEarnedReceipts(data.entries, DateTime.now());
                return ListView(padding: const EdgeInsets.all(20), children: [
                  Text('Spendable balance: ${data.balance} points'),
                  Text(widget.streak == null
                      ? 'Check-in streak unavailable'
                      : 'Check-in streak: ${widget.streak} days; longest: ${widget.longest} days'),
                  const SizedBox(height: 20),
                  const Text(
                      'Earned points in returned receipts · Malaysia weeks'),
                  if (!data.reconciled)
                    const Text(
                        'Receipt history is incomplete. Weekly sums are recorded receipts only.'),
                  for (var i = 0; i < weeks.length; i++)
                    ListTile(
                        title:
                            Text(i == 6 ? 'This week' : '${6 - i} weeks ago'),
                        trailing: Text('${weeks[i]} points')),
                  TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => PointsHistoryScreen(
                                  repository: widget.repository))),
                      child: const Text('View reward receipts'))
                ]);
              })));
}
