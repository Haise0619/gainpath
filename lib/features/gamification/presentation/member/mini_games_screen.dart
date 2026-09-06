import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/shared/shared.dart';
import 'package:gainpath/features/gamification/domain/entities/mini_game.dart';
import 'package:gainpath/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:gainpath/features/gamification/presentation/member/live_mini_game_screen.dart';
import 'package:gainpath/features/gamification/presentation/member/widgets/game_media.dart';

class MiniGamesScreen extends StatelessWidget {
  const MiniGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final games = context.read<GamificationRepository>().miniGames;
    final featured = games.first;
    final rest = games.skip(1).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mini-games')),
      body: PageBody(
        children: [
          Text('Camera-tracked challenges that score your movement.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          const Eyebrow('Challenge of the day'),
          _FeaturedGameCard(game: featured),
          const SizedBox(height: 20),
          const Eyebrow('All challenges'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
            children: rest.map((g) => _MiniGameCard(game: g)).toList(),
          ),
        ],
      ),
    );
  }
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
  final MiniGame game;
  const _FeaturedGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => LiveMiniGameScreen(game: game))),
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.accent.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                gameHero(game.imageUrl),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.ink.withValues(alpha: 0.35), AppColors.ink.withValues(alpha: 0.82)],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded, size: 13, color: AppColors.ink),
                        SizedBox(width: 4),
                        Text('FEATURED TODAY',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: AppColors.ink)),
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
                                    ?.copyWith(color: Colors.white, fontSize: 21)),
                            const SizedBox(height: 4),
                            Text(game.tagline,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 28),
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
  final MiniGame game;
  const _MiniGameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final color = _difficultyColor(game.difficulty);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => LiveMiniGameScreen(game: game))),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      gameHero(game.imageUrl),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppColors.ink.withValues(alpha: 0.6)],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
                          child: Text(game.difficulty,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
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
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                          child: Icon(game.icon, size: 14, color: Colors.white),
                        ),
                      ),
                      const Center(
                        child: Icon(Icons.play_circle_fill_rounded, size: 34, color: Colors.white),
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, size: 12, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text('${game.bestScore}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                          const SizedBox(width: 8),
                          const Icon(Icons.groups_rounded, size: 12, color: AppColors.inkSoft),
                          const SizedBox(width: 3),
                          Text(_formatPlays(game.plays),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
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

  String _formatPlays(int plays) => plays >= 1000 ? '${(plays / 1000).toStringAsFixed(1)}k' : '$plays';
}

/// UC-3.1 — Play Mini-Game Journey. A motion-based gameplay simulation:
/// a moving target reticle the member "hits" in real time, a countdown,
/// live score, and combo streak — the camera-tracking equivalent of
/// LiveWorkoutScreen but tuned to feel like a game rather than a serious
/// tracker (different palette, faster pace, celebratory combo flashes).
