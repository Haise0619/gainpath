import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Read-only public game results. No balance or score editing is exposed.
class MiniGameStandingsScreen extends StatefulWidget {
  const MiniGameStandingsScreen({super.key, required this.repository});
  final MiniGameCompetitionRepository repository;
  @override
  State<MiniGameStandingsScreen> createState() =>
      _MiniGameStandingsScreenState();
}

class _MiniGameStandingsScreenState extends State<MiniGameStandingsScreen> {
  String _game = 'move-catch-v1', _period = 'week';
  MiniGameScoreLeaderboard? _result;
  bool _loading = false, _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation, repo = widget.repository;
    setState(() {
      _loading = true;
      _failed = false;
      _result = null;
    });
    try {
      final r = await repo.leaderboard(gameId: _game, period: _period);
      if (mounted && generation == _generation && repo.current) {
        setState(() => _result = r);
      }
    } catch (_) {
      if (mounted && generation == _generation && repo.current) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Game standings')),
      body: !widget.repository.current
          ? const Center(child: Text('This Admin session has ended.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Independent game leaderboards',
                        style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(miniGameCompetitionTrustLabel),
                    const Text(
                        'One best eligible completed round per Member. No Reward Points are awarded by ranking.'),
                    const SizedBox(height: 20),
                    Wrap(spacing: 16, runSpacing: 12, children: [
                      DropdownButton<String>(
                          value: _game,
                          items: const [
                            DropdownMenuItem(
                                value: 'move-catch-v1',
                                child: Text('Move & Catch')),
                            DropdownMenuItem(
                                value: 'reach-tap-v1',
                                child: Text('Reach & Tap'))
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              _game = v;
                              _load();
                            }
                          }),
                      DropdownButton<String>(
                          value: _period,
                          items: const [
                            DropdownMenuItem(
                                value: 'week', child: Text('Weekly')),
                            DropdownMenuItem(
                                value: 'all-time', child: Text('All-time'))
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              _period = v;
                              _load();
                            }
                          }),
                      OutlinedButton.icon(
                          onPressed: _loading ? null : _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'))
                    ]),
                    const SizedBox(height: 20),
                    if (_loading)
                      const LinearProgressIndicator()
                    else if (_failed)
                      const Text(
                          'Could not load game standings. Refresh to retry.')
                    else if (_result != null) ...[
                      Text(
                          '${_result!.totalParticipants} ranked Members · Top 20'),
                      const SizedBox(height: 12),
                      if (_result!.entries.isEmpty)
                        const Text('No eligible published rounds yet.'),
                      if (_result!.entries.isNotEmpty)
                        SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(columns: const [
                              DataColumn(label: Text('Rank')),
                              DataColumn(label: Text('Member')),
                              DataColumn(
                                  label: Text('Best accepted Game Score'),
                                  numeric: true)
                            ], rows: [
                              for (final row in _result!.entries)
                                DataRow(cells: [
                                  DataCell(Text('#${row.rank}')),
                                  DataCell(Text(row.displayName)),
                                  DataCell(Text('${row.score}'))
                                ])
                            ]))
                    ]
                  ])));
}
