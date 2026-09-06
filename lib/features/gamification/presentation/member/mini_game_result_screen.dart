import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gainpath/features/gamification/application/gamification_bloc.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/shared/shared.dart';
import 'package:gainpath/features/gamification/domain/entities/mini_game.dart';
import 'package:gainpath/features/gamification/presentation/member/live_mini_game_screen.dart';

class MiniGameResultScreen extends StatefulWidget {
  final MiniGame game;
  final int score;
  final int hits;
  final int accuracy;

  const MiniGameResultScreen({
    super.key,
    required this.game,
    required this.score,
    required this.hits,
    required this.accuracy,
  });

  @override
  State<MiniGameResultScreen> createState() => _MiniGameResultScreenState();
}

class _MiniGameResultScreenState extends State<MiniGameResultScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _scale;

  bool get _personalBest => widget.score > widget.game.bestScore;
  int get _pointsEarned => (widget.score / 10).round();

  @override
  void initState() {
    super.initState();
    context.read<GamificationBloc>().add(MiniGameCompleted(widget.score));
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.08), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOut));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: PageBody(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emoji_events_rounded, size: 44, color: Colors.white),
                      const SizedBox(height: 10),
                      Text(widget.game.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: widget.score),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Text('$value',
                            style: const TextStyle(
                                fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: Colors.white)),
                      ),
                      Text(_personalBest ? 'New personal best!' : 'Best: ${widget.game.bestScore}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                    ],
                  ),
                ),
              ),
              _sparkle(top: -10, left: 24, size: 20, delayMs: 0),
              _sparkle(top: 6, right: 20, size: 16, delayMs: 180),
              _sparkle(top: -18, right: 90, size: 14, delayMs: 340),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatTile('${widget.hits}', 'Hits')),
              const SizedBox(width: 10),
              Expanded(child: StatTile('${widget.accuracy}%', 'Accuracy')),
              const SizedBox(width: 10),
              Expanded(child: StatTile('+$_pointsEarned', 'Points')),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => showToast(context, 'Opening your device share sheet.'),
            icon: const Icon(Icons.ios_share_rounded, size: 19),
            label: const Text('Share result'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => LiveMiniGameScreen(game: widget.game))),
            child: const Text('Play again'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  /// A single sparkle particle: fades and drifts upward, staggered by
  /// [delayMs] so the three of them don't all pop at once.
  Widget _sparkle({double? top, double? left, double? right, required double size, required int delayMs}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 700 + delayMs),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          final fadeIn = (value * 5).clamp(0.0, 1.0);
          final fadeOut = (1 - value).clamp(0.0, 1.0);
          return Opacity(
            opacity: math.min(fadeIn, fadeOut),
            child: Transform.translate(offset: Offset(0, -24 * value), child: child),
          );
        },
        child: Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: size),
      ),
    );
  }
}

/// UC-3.6 — View Unlocked Achievement.
