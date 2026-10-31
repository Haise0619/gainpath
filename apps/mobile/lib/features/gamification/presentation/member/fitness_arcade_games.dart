import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/mini_game_content_feature_host.dart';
import '../../domain/move_catch_ports.dart';
import '../../domain/reach_tap_ports.dart';
import '../../domain/reach_tap_participation_repository.dart';
import '../../domain/mini_game_launch.dart';
import 'mini_game_details_screen.dart';
import '../../application/game_leaderboard_host.dart';
import 'mini_games_screen.dart';
import 'mini_game_participation_panel.dart';

/// Uses the existing scoped feature composition only for an actual Member.
class FitnessArcadeHost extends StatefulWidget {
  const FitnessArcadeHost({super.key, required this.onReturn});
  final Future<void> Function() onReturn;

  @override
  State<FitnessArcadeHost> createState() => _FitnessArcadeHostState();
}

class _FitnessArcadeHostState extends State<FitnessArcadeHost> {
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
            return FitnessArcadeGames(onReturn: () => widget.onReturn());
          }
          return MiniGameContentFeatureHost(
              key: ObjectKey(auth.state.session),
              builder: (reader, best, _, participation) => Builder(
                  builder: (context) => FitnessArcadeGames(
                      reader: reader,
                      bestScoreStore: best,
                      reachTapHistory: context.read<ReachTapHistoryStore>(),
                      participation: participation,
                      reachParticipation: context
                          .read<ReachTapParticipationRepository?>()
                          ?.repository,
                      onReturn: () => widget.onReturn())));
        });
  }
}

/// Descriptive game discovery. Overview reads never claim or award points.
class FitnessArcadeGames extends StatefulWidget {
  const FitnessArcadeGames(
      {super.key,
      this.reader,
      this.bestScoreStore,
      this.reachTapHistory,
      this.participation,
      this.reachParticipation,
      required this.onReturn});
  final MiniGameContentReader? reader;
  final MoveCatchBestScoreStore? bestScoreStore;
  final ReachTapHistoryStore? reachTapHistory;
  final MiniGameParticipationRepository? participation, reachParticipation;
  final Future<void> Function() onReturn;

  @override
  State<FitnessArcadeGames> createState() => _FitnessArcadeGamesState();
}

class _FitnessArcadeGamesState extends State<FitnessArcadeGames> {
  final _content = <String, MiniGameContent>{};
  int? _moveBest, _reachBest;
  MiniGameParticipation? _participation, _reachParticipation;
  int _generation = 0;
  int _moveVersion = 0,
      _reachVersion = 0,
      _participationVersion = 0,
      _reachParticipationVersion = 0;
  bool _guidesLoading = false, _guideFailed = false;
  bool _moveLoading = false, _reachLoading = false;
  bool _participationLoading = false,
      _reachParticipationLoading = false,
      _opening = false;

  bool get _current =>
      (widget.reader?.current ?? true) &&
      (widget.participation?.current ?? true) &&
      (widget.reachParticipation?.current ?? true);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FitnessArcadeGames oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.reader, oldWidget.reader) ||
        !identical(widget.bestScoreStore, oldWidget.bestScoreStore) ||
        !identical(widget.reachTapHistory, oldWidget.reachTapHistory) ||
        !identical(widget.participation, oldWidget.participation) ||
        !identical(widget.reachParticipation, oldWidget.reachParticipation)) {
      unawaited(_load());
    }
  }

  bool _accept(int generation) =>
      mounted && generation == _generation && _current;

  Future<void> _load() async {
    final generation = ++_generation;
    _content.clear();
    _moveBest = _reachBest = null;
    _participation = _reachParticipation = null;
    _guideFailed = false;
    final reader = widget.reader;
    _guidesLoading = reader != null && _current;
    _moveLoading = _guidesLoading && widget.bestScoreStore != null;
    _reachLoading = _guidesLoading && widget.reachTapHistory != null;
    _participationLoading = widget.participation != null && _current;
    _reachParticipationLoading = widget.reachParticipation != null && _current;
    // Each read publishes independently; a slow guide must not hide local PBs.
    await Future.wait([
      _loadGuides(generation),
      _loadMoveBest(generation),
      _loadReachBest(generation),
      _loadParticipation(generation),
      _loadParticipation(generation, reach: true),
    ]);
  }

  Future<void> _loadGuides(int generation) async {
    final reader = widget.reader;
    if (!_guidesLoading || reader == null) return;
    try {
      final rows = await reader.load();
      if (!_accept(generation)) return;
      setState(() {
        for (final row in rows) {
          if (row.organizationId == reader.scope.organizationId &&
              MiniGameContent.supportedIds.contains(row.gameId)) {
            _content[row.gameId] = row;
          }
        }
        _guidesLoading = false;
        _guideFailed = _content.length != MiniGameContent.supportedIds.length;
      });
    } catch (_) {
      if (!_accept(generation)) return;
      setState(() {
        _guidesLoading = false;
        _guideFailed = true;
      });
    }
  }

  Future<void> _loadMoveBest(int generation) async {
    final reader = widget.reader, store = widget.bestScoreStore;
    if (!_moveLoading || reader == null || store == null) return;
    final version = ++_moveVersion;
    int? best;
    try {
      best = await store.load(reader.scope);
    } catch (_) {/* Storage failure remains unknown. */}
    if (!_accept(generation) || version != _moveVersion) return;
    setState(() {
      _moveBest = best;
      _moveLoading = false;
    });
  }

  Future<void> _loadReachBest(int generation) async {
    final reader = widget.reader, store = widget.reachTapHistory;
    if (!_reachLoading || reader == null || store == null) return;
    final version = ++_reachVersion;
    int? best;
    try {
      best = (await store.load(reader.scope)).bestScore;
    } catch (_) {/* Storage failure remains unknown. */}
    if (!_accept(generation) || version != _reachVersion) return;
    setState(() {
      _reachBest = best;
      _reachLoading = false;
    });
  }

  Future<void> _loadParticipation(int generation, {bool reach = false}) async {
    final repo = reach ? widget.reachParticipation : widget.participation;
    if (!(reach ? _reachParticipationLoading : _participationLoading) ||
        repo == null) {
      return;
    }
    final version =
        reach ? ++_reachParticipationVersion : ++_participationVersion;
    MiniGameParticipation? result;
    try {
      final response = await repo.overview();
      if (response.scope == repo.scope &&
          (widget.reader == null || repo.scope == widget.reader!.scope)) {
        result = response;
      }
    } catch (_) {/* An unavailable overview is never an earning promise. */}
    if (!_accept(generation) ||
        version !=
            (reach ? _reachParticipationVersion : _participationVersion)) {
      return;
    }
    setState(() {
      if (reach) {
        _reachParticipation = result;
        _reachParticipationLoading = false;
      } else {
        _participation = result;
        _participationLoading = false;
      }
    });
  }

  Future<void> _details(MiniGameContent content) async {
    if (_opening || !_current) return;
    _opening = true;
    final reader = widget.reader,
        best = widget.bestScoreStore,
        history = widget.reachTapHistory,
        participation = content.gameId == MiniGameContent.reachTapId
            ? widget.reachParticipation
            : widget.participation;
    final generation = _generation;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => MiniGameDetailsScreen(
              content: content,
              onLeaderboard: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          GameLeaderboardHost(gameId: content.gameId))),
              participation: participation,
              reader: reader,
              bestScoreStore: best,
              reachTapHistory: history,
              rewardStatus: participation != null
                  ? MiniGameParticipationPanel(repository: participation)
                  : const Text('Earning status unavailable'))));
      if (_accept(generation)) {
        await Future.wait([_refreshAfterGame(), widget.onReturn()]);
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _viewAll() async {
    if (_opening || !_current) return;
    _opening = true;
    final generation = _generation;
    final reader = widget.reader,
        best = widget.bestScoreStore,
        history = widget.reachTapHistory,
        participation = widget.participation,
        reachParticipation = widget.reachParticipation;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) {
        final catalog = MiniGamesScreen(
            connected: true,
            participation: participation,
            reachParticipation: reachParticipation,
            reader: reader,
            bestScoreStore: best,
            rewardStatus: participation == null
                ? null
                : MiniGameParticipationPanel(repository: participation));
        return history == null
            ? catalog
            : RepositoryProvider<ReachTapHistoryStore>.value(
                value: history, child: catalog);
      }));
      if (_accept(generation)) {
        await Future.wait([_refreshAfterGame(), widget.onReturn()]);
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _refreshAfterGame() async {
    if (!_current) return;
    final generation = _generation;
    // Gameplay changed these values: refresh them independently of a pending
    // descriptive guide. Per-read versions prevent an older PB/overview reply
    // overwriting the newer return result; the guide retains its own request.
    setState(() {
      _moveLoading = widget.reader != null && widget.bestScoreStore != null;
      _reachLoading = widget.reader != null && widget.reachTapHistory != null;
      _participationLoading = widget.participation != null;
      _reachParticipationLoading = widget.reachParticipation != null;
    });
    await Future.wait([
      _loadMoveBest(generation),
      _loadReachBest(generation),
      _loadParticipation(generation),
      _loadParticipation(generation, reach: true)
    ]);
  }

  String _earningLabel({bool reach = false}) {
    if (reach ? _reachParticipationLoading : _participationLoading) {
      return 'Play for fun';
    }
    final result = reach ? _reachParticipation : _participation;
    final gameId =
        reach ? MiniGameContent.reachTapId : MiniGameContent.supportedId;
    if (!MiniGameLaunchArguments.canEarn(result, gameId)) return 'Play for fun';
    final game = result!.policy.games.singleWhere((g) => g.gameId == gameId);
    return '+${game.points} points';
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
        if (!_current) return const Text('Game session ended.');
        final organization = widget.reader?.scope.organizationId ?? 'built-in';
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                flex: 2,
                child: Text('Play Mini-Games',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800))),
            Flexible(
                child: TextButton(
                    onPressed: _viewAll,
                    child:
                        const Text('View all', textAlign: TextAlign.center))),
          ]),
          if (_guideFailed)
            Semantics(
                label:
                    'Latest game covers unavailable; showing built-in fallback',
                child: const SizedBox.shrink()),
          IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                for (final id in [
                  MiniGameContent.supportedId,
                  MiniGameContent.reachTapId
                ]) ...[
                  if (id == MiniGameContent.reachTapId)
                    const SizedBox(width: 12),
                  Expanded(
                      child: _ArcadeCard(
                          content: _content[id] ??
                              MiniGameContent.defaults(organization,
                                  gameId: id),
                          best: id == MiniGameContent.supportedId
                              ? _moveBest
                              : _reachBest,
                          loading: id == MiniGameContent.supportedId
                              ? _moveLoading
                              : _reachLoading,
                          earning: id == MiniGameContent.supportedId
                              ? _earningLabel()
                              : _earningLabel(reach: true),
                          onTap: () => _details(_content[id] ??
                              MiniGameContent.defaults(organization,
                                  gameId: id)))),
                ],
              ])),
        ]);
      });
}

class _ArcadeCard extends StatelessWidget {
  const _ArcadeCard(
      {required this.content,
      required this.best,
      required this.loading,
      required this.earning,
      required this.onTap});
  final MiniGameContent content;
  final int? best;
  final bool loading;
  final String earning;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          key: Key(content.gameId == MiniGameContent.reachTapId
              ? 'arcade-reach-tap-card'
              : 'arcade-move-catch-card'),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                            aspectRatio: 1.35,
                            child: MiniGameCover(content: content))),
                    const SizedBox(height: 8),
                    Text(content.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: earning.startsWith('+')
                                ? AppColors.successTint
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(earning,
                            style: TextStyle(
                                fontSize: 12,
                                color: earning.startsWith('+')
                                    ? AppColors.ink
                                    : AppColors.inkSoft))),
                    const SizedBox(height: 8),
                    const Spacer(),
                    Semantics(
                        label:
                            'Personal best · ${loading ? 'Loading' : best ?? 'Unavailable'} · On this device · Game Score',
                        child: ExcludeSemantics(
                            child: Text(
                                loading ? 'Best: …' : 'Best: ${best ?? '—'}',
                                style: const TextStyle(
                                    color: AppColors.inkSoft, fontSize: 12)))),
                  ]))));
}
