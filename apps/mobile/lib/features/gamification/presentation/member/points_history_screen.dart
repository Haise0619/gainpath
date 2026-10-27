import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'reward_details.dart';
import '../../application/rewards_feature_host.dart';
import 'voucher_screen.dart';

class PointsHistoryScreen extends StatefulWidget {
  const PointsHistoryScreen({super.key, required this.repository});
  final VerifiedRewardsRepository repository;
  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  late Future<PointsHistorySnapshot> _future;
  String _direction = 'All', _source = 'All sources';
  static const _sources = {
    'All sources': '',
    'Check-in': 'app_check_in',
    'Mini-games': 'mini_game_participation',
    'Workouts': 'workout_reward',
    'Other rewards': 'activity_reward',
    'Manual credit': 'manual_credit',
    'Redemptions': 'redemption',
  };
  @override
  void initState() {
    super.initState();
    _future = widget.repository.pointsHistory();
  }

  @override
  void didUpdateWidget(PointsHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _future = widget.repository.pointsHistory();
    }
  }

  void _refresh() => setState(() {
        _future = widget.repository.pointsHistory();
      });
  Future<void> _voucher(String id) async {
    final repo = widget.repository;
    try {
      final result = await repo.voucher(id);
      if (!mounted || !repo.current || !identical(repo, widget.repository))
        return;
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) =>
                  VoucherScreen(redemption: result, repository: repo)));
    } catch (_) {
      if (mounted && repo.current && identical(repo, widget.repository)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open this voucher. Please retry.')));
      }
    }
  }

  String _label(String source) =>
      _sources.entries.firstWhere((e) => e.value == source).key;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Points History'), actions: [
          IconButton(
              tooltip: 'Refresh history',
              onPressed: widget.repository.current ? _refresh : null,
              icon: const Icon(Icons.refresh)),
        ]),
        body: RewardsRepositoryGuard(
            repository: widget.repository,
            child: SafeArea(
              child: FutureBuilder<PointsHistorySnapshot>(
                  future: _future,
                  builder: (context, result) {
                    if (!widget.repository.current)
                      return const Center(
                          child: Text('History unavailable for this session.'));
                    if (result.connectionState != ConnectionState.done)
                      return const Center(child: CircularProgressIndicator());
                    if (result.hasError || !result.hasData) {
                      return Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Could not load points history.'),
                        TextButton(
                            onPressed: _refresh, child: const Text('Retry')),
                      ]));
                    }
                    final data = result.data!;
                    final rows = data.entries.where((e) =>
                        e.wallet == 'spendable' &&
                        (_direction == 'All' ||
                            (_direction == 'Earned'
                                ? e.points > 0
                                : e.points < 0)) &&
                        (_source == 'All sources' ||
                            e.source == _sources[_source]));
                    return RefreshIndicator(
                        onRefresh: () async {
                          _refresh();
                          try {
                            await _future;
                          } catch (_) {}
                        },
                        child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        AppColors.primary,
                                        Color(0xFF492090)
                                      ]),
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('YOUR POINTS',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                letterSpacing: 1.5)),
                                        const SizedBox(height: 8),
                                        Text('${data.balance} points',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                      ])),
                              const SizedBox(height: 20),
                              Wrap(spacing: 8, children: [
                                for (final f in ['All', 'Earned', 'Spent'])
                                  ChoiceChip(
                                      label: Text(f),
                                      selected: _direction == f,
                                      onSelected: (_) =>
                                          setState(() => _direction = f))
                              ]),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                  key: const Key('history-source-filter'),
                                  initialValue: _source,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Source'),
                                  items: [
                                    for (final s in _sources.keys)
                                      DropdownMenuItem(value: s, child: Text(s))
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _source = value!)),
                              const SizedBox(height: 12),
                              if (!data.reconciled)
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                        'Earlier balance changes may not have history records.')),
                              if (rows.isEmpty)
                                const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Text(
                                        'No transactions in this filter.')),
                              for (final e in rows)
                                Card(
                                    child: ListTile(
                                  onTap: e.redemptionId == null
                                      ? null
                                      : () => _voucher(e.redemptionId!),
                                  leading: Icon(
                                      e.source == 'mini_game_participation'
                                          ? Icons.sports_esports_outlined
                                          : e.source == 'app_check_in'
                                              ? Icons
                                                  .local_fire_department_outlined
                                              : e.points > 0
                                                  ? Icons.add_circle_outline
                                                  : Icons.redeem_outlined,
                                      color: e.points > 0
                                          ? AppColors.success
                                          : AppColors.primary),
                                  title: Text(e.title),
                                  subtitle: Text(
                                      '${_label(e.source)}${e.redemptionId == null ? '' : ' · View voucher'}\n${rewardDate(e.occurredAtMillis)}'),
                                  isThreeLine: true,
                                  trailing: Text(
                                      '${e.points > 0 ? '+' : ''}${e.points}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: e.points > 0
                                              ? AppColors.success
                                              : AppColors.primary)),
                                )),
                            ]));
                  }),
            )),
      );
}
