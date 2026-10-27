import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'live_mini_game_screen.dart';
import 'widgets/game_media.dart';
import '../../domain/move_catch_ports.dart';
import 'mini_game_details_screen.dart';

class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen(
      {super.key,
      this.connected = false,
      this.reader,
      this.bestScoreStore,
      this.rewardStatus});
  final bool connected;
  final MiniGameContentReader? reader;
  final MoveCatchBestScoreStore? bestScoreStore;
  final Widget? rewardStatus;

  @override
  Widget build(BuildContext context) {
    if (connected) {
      return _MotionGames(
          reader: reader,
          bestScoreStore: bestScoreStore,
          rewardStatus: rewardStatus);
    }
    final games = connected
        ? List.generate(4,
            (_) => const MiniGame('-', '-', '', '-', 0, MiniGameIcon.bolt, 0))
        : context.read<GamificationRepository>().miniGames;
    final featured = games.first;
    final rest = games.skip(1).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mini-games')),
      body: PageBody(
        children: [
          Text(
              connected
                  ? 'Challenges unavailable. -'
                  : 'Camera-tracked challenges that score your movement.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          const Eyebrow('Challenge of the day'),
          _FeaturedGameCard(game: featured, connected: connected),
          const SizedBox(height: 20),
          const Eyebrow('All challenges'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
            children: rest
                .map((g) => _MiniGameCard(game: g, connected: connected))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MotionGames extends StatefulWidget {
  const _MotionGames({this.reader, this.bestScoreStore, this.rewardStatus});
  final MiniGameContentReader? reader;
  final MoveCatchBestScoreStore? bestScoreStore;
  final Widget? rewardStatus;
  @override
  State<_MotionGames> createState() => _MotionGamesState();
}

class _MotionGamesState extends State<_MotionGames> {
  MiniGameContent? _content;
  bool _loading = false, _unavailable = false;
  int _generation = 0, _bestRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MotionGames oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.reader, widget.reader)) _load();
  }

  Future<void> _load() async {
    final reader = widget.reader, generation = ++_generation;
    _content = null;
    _unavailable = false;
    _loading = reader != null && reader.current;
    if (reader == null || !reader.current) return;
    try {
      final rows = await reader.load();
      if (!mounted || generation != _generation) return;
      MiniGameContent? content;
      if (reader.current) {
        for (final row in rows) {
          if (row.gameId == MiniGameContent.supportedId &&
              row.organizationId == reader.scope.organizationId) {
            content = row;
            break;
          }
        }
      }
      setState(() {
        _content = content;
        _unavailable = content == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _unavailable = true;
        _loading = false;
      });
    }
  }

  void _refresh() {
    setState(() => _bestRevision++);
    _load();
  }

  Future<void> _details(MiniGameContent content) async {
    if (widget.reader != null && !widget.reader!.current) {
      setState(() {});
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MiniGameDetailsScreen(
            content: content,
            reader: widget.reader,
            bestScoreStore: widget.bestScoreStore,
            rewardStatus: widget.rewardStatus)));
    if (mounted && (widget.reader?.current ?? true)) {
      setState(() => _bestRevision++);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
      stream: context.read<AuthBloc?>()?.stream,
      builder: (context, _) => _buildCatalog(context));

  Widget _buildCatalog(BuildContext context) {
    final reader = widget.reader;
    if (reader != null && !reader.current) {
      return Scaffold(
          appBar: AppBar(title: const Text('Mini-games')),
          body:
              const Center(child: Text('This game guide session has ended.')));
    }
    final content = _content ??
        MiniGameContent.defaults(reader?.scope.organizationId ?? 'built-in');
    return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Mini-games'), actions: [
          if (reader != null)
            IconButton(
                tooltip: 'Refresh game guide',
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh)),
        ]),
        body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Camera-tracked challenges that score your movement.',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              if (_loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Loading latest game guide…'),
              ] else if (_unavailable) ...[
                const Text('Built-in game guide · latest content unavailable'),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ] else if (content.revision == 0)
                const Text('Built-in game guide'),
              const SizedBox(height: 16),
              Text('Featured challenge',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              _MotionFeaturedCard(
                  content: content, onTap: () => _details(content)),
              const SizedBox(height: 16),
              MiniGamePersonalBest(
                  reader: reader,
                  store: widget.bestScoreStore,
                  revision: _bestRevision),
              const SizedBox(height: 24),
              Text('All challenges',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              LayoutBuilder(
                  builder: (context, constraints) =>
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        SizedBox(
                            width: (constraints.maxWidth - 12) / 2,
                            child: _MotionChallengeCard(
                                content: content,
                                onTap: () => _details(content)))
                      ])),
            ])));
  }
}

class _MotionFeaturedCard extends StatelessWidget {
  const _MotionFeaturedCard({required this.content, required this.onTap});
  final MiniGameContent content;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      color: AppColors.primary,
      child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            Positioned.fill(child: MiniGameCover(content: content)),
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                  Colors.black.withValues(alpha: .08),
                  const Color(0xFF251344).withValues(alpha: .96)
                ])))),
            Container(
                constraints: const BoxConstraints(minHeight: 310),
                padding: const EdgeInsets.all(22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Wrap(spacing: 8, runSpacing: 8, children: [
                        _GameLabel('Camera'),
                        _GameLabel('All levels')
                      ]),
                      const SizedBox(height: 88),
                      Text(content.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(content.introduction,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 16),
                      Align(
                          alignment: Alignment.centerRight,
                          child: IconButton.filled(
                              tooltip: 'View Move & Catch details',
                              onPressed: onTap,
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                  minimumSize: const Size(56, 56)),
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 32))),
                    ])),
          ])));
}

class _GameLabel extends StatelessWidget {
  const _GameLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)));
}

class _MotionChallengeCard extends StatelessWidget {
  const _MotionChallengeCard({required this.content, required this.onTap});
  final MiniGameContent content;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          key: const Key('move-catch-challenge-card'),
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(
                aspectRatio: 1.2,
                child: Stack(fit: StackFit.expand, children: [
                  MiniGameCover(content: content),
                  const Center(
                      child: Icon(Icons.play_circle_fill_rounded,
                          size: 42, color: Colors.white)),
                ])),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(content.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('40 seconds · Camera',
                          style: TextStyle(color: AppColors.inkSoft)),
                      const SizedBox(height: 4),
                      const Text('All levels',
                          style: TextStyle(color: AppColors.primary)),
                    ])),
          ])));
}

Color _difficultyColor(String difficulty) {
  switch (difficulty) {
    case 'Easy':
      return AppColors.success;
    case 'Hard':
      return AppColors.danger;
    default:
      return AppColors.warning;
  }
}

/// A bigger, banner-style card for the day's spotlighted challenge — the
/// kind of "featured" slot mobile game hubs use to make one item feel like
/// an event rather than just first in a list.
class _FeaturedGameCard extends StatelessWidget {
  final bool connected;
  final MiniGame game;
  const _FeaturedGameCard({required this.game, this.connected = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: connected
            ? () => showUnavailable(context)
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LiveMiniGameScreen(game: game))),
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                connected
                    ? const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppColors.heroGradient))
                    : gameHero(game.imageUrl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.ink.withValues(alpha: 0.35),
                        AppColors.ink.withValues(alpha: 0.82)
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded,
                            size: 13, color: AppColors.ink),
                        SizedBox(width: 4),
                        Text(connected ? '-' : 'FEATURED TODAY',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: AppColors.ink)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(game.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                        color: Colors.white, fontSize: 21)),
                            const SizedBox(height: 4),
                            Text(game.tagline,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: AppColors.primary, size: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniGameCard extends StatelessWidget {
  final bool connected;
  final MiniGame game;
  const _MiniGameCard({required this.game, this.connected = false});

  @override
  Widget build(BuildContext context) {
    final color = _difficultyColor(game.difficulty);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: connected
            ? () => showUnavailable(context)
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LiveMiniGameScreen(game: game))),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      connected
                          ? const DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: AppColors.heroGradient))
                          : gameHero(game.imageUrl),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.ink.withValues(alpha: 0.6)
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(7)),
                          child: Text(game.difficulty,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: Icon(
                              switch (game.icon) {
                                MiniGameIcon.bolt => Icons.bolt_rounded,
                                MiniGameIcon.shield => Icons.shield_rounded,
                                MiniGameIcon.flash => Icons.flash_on_rounded,
                                MiniGameIcon.boxing => Icons.sports_mma_rounded,
                              },
                              size: 14,
                              color: Colors.white),
                        ),
                      ),
                      const Center(
                        child: Icon(Icons.play_circle_fill_rounded,
                            size: 34, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded,
                              size: 12, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text(connected ? '-' : '${game.bestScore}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkSoft)),
                          const SizedBox(width: 8),
                          const Icon(Icons.groups_rounded,
                              size: 12, color: AppColors.inkSoft),
                          const SizedBox(width: 3),
                          Text(connected ? '-' : _formatPlays(game.plays),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkSoft)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPlays(int plays) =>
      plays >= 1000 ? '${(plays / 1000).toStringAsFixed(1)}k' : '$plays';
}

/// UC-3.1 — Play Mini-Game Journey. A motion-based gameplay simulation:
/// a moving target reticle the member "hits" in real time, a countdown,
/// live score, and combo streak — the camera-tracking equivalent of
/// LiveWorkoutScreen but tuned to feel like a game rather than a serious
/// tracker (different palette, faster pace, celebratory combo flashes).
