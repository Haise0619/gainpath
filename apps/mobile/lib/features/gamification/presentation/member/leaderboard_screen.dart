import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/rewards_feature_host.dart';
import 'legacy_leaderboard_view.dart';
import 'leaderboard_standings.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.connected = false, this.repository});
  final bool connected;
  final VerifiedRewardsRepository? repository;
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _period = 'week';
  Future<EarnedPointsLeaderboard>? _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LeaderboardScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.repository, widget.repository)) _load();
  }

  void _load() {
    final repo = widget.repository, period = _period;
    _future = repo == null
        ? null
        : Future<EarnedPointsLeaderboard>.sync(
            () => repo.leaderboard(period: period));
    _future?.ignore();
  }

  void _refresh() => setState(_load);
  @override
  Widget build(BuildContext context) {
    if (widget.repository == null && !widget.connected) {
      return const LegacyLeaderboardView();
    }
    final repo = widget.repository;
    if (repo == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Leaderboard')),
          body: const Center(
              child: Text('Leaderboard unavailable for this session.')));
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Leaderboard'), actions: [
          IconButton(
              tooltip: 'Refresh leaderboard',
              onPressed: repo.current ? _refresh : null,
              icon: const Icon(Icons.refresh))
        ]),
        body: RewardsRepositoryGuard(
            repository: repo,
            child: SafeArea(
                child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                          style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.selected)
                                          ? AppColors.primary
                                          : Colors.transparent),
                              foregroundColor: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.selected)
                                          ? Colors.white
                                          : AppColors.inkSoft),
                              minimumSize:
                                  const WidgetStatePropertyAll(Size(0, 48)),
                              textStyle: const WidgetStatePropertyAll(
                                  TextStyle(fontWeight: FontWeight.w700))),
                          segments: const [
                            ButtonSegment(
                                value: 'week', label: Text('This week')),
                            ButtonSegment(
                                value: 'all_time', label: Text('All time'))
                          ],
                          selected: {_period},
                          onSelectionChanged: (value) => setState(() {
                                _period = value.first;
                                _load();
                              })))),
              Expanded(
                  child: FutureBuilder<EarnedPointsLeaderboard>(
                      future: _future,
                      builder: (context, result) {
                        if (!repo.current) {
                          return const Center(
                              child: Text(
                                  'Leaderboard unavailable for this session.'));
                        }
                        if (result.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (result.hasError || !result.hasData) {
                          return Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                const Text('Could not load leaderboard.'),
                                TextButton(
                                    onPressed: _refresh,
                                    child: const Text('Retry'))
                              ]));
                        }
                        final data = result.data!;
                        return RefreshIndicator(
                            onRefresh: () async {
                              _refresh();
                              try {
                                await _future;
                              } catch (_) {}
                            },
                            child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                children: [
                                  LeaderboardStandings(data: data),
                                ]));
                      })),
            ]))));
  }
}
