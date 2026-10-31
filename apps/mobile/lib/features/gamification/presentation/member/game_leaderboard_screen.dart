import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'game_competition_privacy.dart';

class GameLeaderboardScreen extends StatefulWidget {
  const GameLeaderboardScreen(
      {super.key, required this.repository, this.gameId = 'move-catch-v1'});
  final MiniGameCompetitionRepository repository;
  final String gameId;
  @override
  State<GameLeaderboardScreen> createState() => _GameLeaderboardScreenState();
}

class _GameLeaderboardScreenState extends State<GameLeaderboardScreen> {
  late String _game;
  String _period = 'week';
  MiniGameScoreLeaderboard? _result;
  bool _loading = false, _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _game = competitiveGameIds.contains(widget.gameId)
        ? widget.gameId
        : 'move-catch-v1';
    unawaited(_load());
  }

  @override
  void didUpdateWidget(GameLeaderboardScreen old) {
    super.didUpdateWidget(old);
    if (!identical(old.repository, widget.repository)) {
      _generation++;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final repo = widget.repository,
        game = _game,
        period = _period,
        generation = ++_generation;
    if (!repo.current) return;
    setState(() {
      _loading = true;
      _failed = false;
      _result = null;
    });
    try {
      final result = await repo
          .leaderboard(gameId: game, period: period)
          .timeout(const Duration(seconds: 12));
      if (!mounted || !repo.current || generation != _generation) return;
      if (result.scope != repo.scope ||
          result.gameId != game ||
          result.period != period) {
        throw const FormatException('Unowned standings');
      }
      setState(() => _result = result);
    } catch (_) {
      if (mounted && repo.current && generation == _generation) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _privacy() async {
    final repo = widget.repository;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Ranking privacy')),
            body: SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: GameCompetitionPrivacy(repository: repo))))));
    if (mounted && repo.current) await _load();
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
        if (!widget.repository.current) {
          return Scaffold(
              appBar: AppBar(title: const Text('Game rankings')),
              body: const Center(child: Text('Ranking session ended.')));
        }
        final title = _game == 'reach-tap-v1' ? 'Reach & Tap' : 'Move & Catch';
        return Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(title: Text('$title rankings'), actions: [
              IconButton(
                  tooltip: 'Refresh game rankings',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh))
            ]),
            body: SafeArea(
                child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final id in ['move-catch-v1', 'reach-tap-v1'])
                              ChoiceChip(
                                  label: Text(id == 'move-catch-v1'
                                      ? 'Move & Catch'
                                      : 'Reach & Tap'),
                                  selected: _game == id,
                                  onSelected: (value) {
                                    if (value && id != _game) {
                                      setState(() => _game = id);
                                      unawaited(_load());
                                    }
                                  })
                          ]),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final period in ['week', 'all-time'])
                              ChoiceChip(
                                  label: Text(
                                      period == 'week' ? 'Weekly' : 'All-time'),
                                  selected: _period == period,
                                  onSelected: (value) {
                                    if (value && period != _period) {
                                      setState(() => _period = period);
                                      unawaited(_load());
                                    }
                                  })
                          ]),
                          const SizedBox(height: 12),
                          const Text(
                              'Best eligible completed round · Game Score',
                              style: TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          const Text(
                              'Weekly resets Monday, Malaysia time. Replays improve your best; scores are never added together.'),
                          const SizedBox(height: 8),
                          const Text(miniGameCompetitionTrustLabel,
                              style: TextStyle(
                                  color: AppColors.inkSoft, fontSize: 12)),
                          const SizedBox(height: 16),
                          if (_loading)
                            const Center(child: CircularProgressIndicator())
                          else if (_failed) ...[
                            const Text('Could not load game rankings.'),
                            TextButton(
                                onPressed: _load, child: const Text('Retry'))
                          ] else if (_result != null)
                            ..._standings(_result!),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                              onPressed: _privacy,
                              icon: const Icon(Icons.privacy_tip_outlined),
                              label: const Text('Ranking privacy')),
                        ]))));
      });
  List<Widget> _standings(MiniGameScoreLeaderboard result) => [
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your best accepted score',
              style:
                  TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              result.you.rank == null
                  ? 'Unranked'
                  : '#${result.you.rank} · ${result.you.score} Game Score',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          if (result.you.rank == null)
            const Text('Opt in and complete a new round to join.'),
        ])),
        const SizedBox(height: 20),
        if (result.entries.isEmpty)
          const Text(
              'No accepted scores yet. Your first eligible round can start the rankings.')
        else ...[
          const Text('Top 3',
              style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final row in result.entries.take(3)) _row(row, podium: true),
          const SizedBox(height: 16),
          const Text('Top 20',
              style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final row in result.entries) _row(row),
        ],
      ];
  Widget _row(MiniGameScoreRank row, {bool podium = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: row.isYou ? AppColors.primaryTint : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (podium) ...[
              const Icon(Icons.emoji_events_outlined,
                  color: AppColors.accentDark),
              const SizedBox(width: 8)
            ],
            Text('#${row.rank}',
                style: const TextStyle(
                    color: AppColors.ink, fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    row.isYou ? '${row.displayName} · You' : row.displayName,
                    style: const TextStyle(color: AppColors.ink))),
            const SizedBox(width: 8),
            Flexible(
                child: Text('${row.score}',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w800)))
          ])));
}
