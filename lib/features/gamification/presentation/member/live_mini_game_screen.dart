import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/shared/shared.dart';
import 'package:gainpath/features/gamification/domain/entities/mini_game.dart';
import 'package:gainpath/features/gamification/presentation/member/mini_game_result_screen.dart';

class LiveMiniGameScreen extends StatefulWidget {
  final MiniGame game;
  const LiveMiniGameScreen({super.key, required this.game});

  @override
  State<LiveMiniGameScreen> createState() => _LiveMiniGameScreenState();
}

class _LiveMiniGameScreenState extends State<LiveMiniGameScreen> with TickerProviderStateMixin {
  static const _gameSeconds = 20;

  late final AnimationController _reticleController;
  Timer? _timer;
  final _rng = math.Random();

  int _secondsLeft = _gameSeconds;
  int _score = 0;
  int _hits = 0;
  int _combo = 0;
  String? _flashText;
  Alignment _target = Alignment.center;

  @override
  void initState() {
    super.initState();
    _reticleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _moveTarget();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _moveTarget() {
    _target = Alignment(_rng.nextDouble() * 1.4 - 0.7, _rng.nextDouble() * 1.1 - 0.6);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _secondsLeft--;
      // Simulate a hit roughly every tick with a chance of a combo streak,
      // standing in for the real pose-tracking hit-detection pipeline.
      final hit = _rng.nextDouble() < 0.82;
      if (hit) {
        _hits++;
        _combo++;
        final base = 40 + _rng.nextInt(40);
        final comboBonus = _combo >= 3 ? 30 : 0;
        _score += base + comboBonus;
        _flashText = comboBonus > 0 ? '+${base + comboBonus} COMBO x$_combo' : '+$base';
      } else {
        _combo = 0;
        _flashText = null;
      }
      _moveTarget();
      if (_secondsLeft <= 0) {
        _finish();
      }
    });
  }

  void _finish() {
    _timer?.cancel();
    final accuracy = ((_hits / _gameSeconds) * 100).clamp(0, 100).round();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MiniGameResultScreen(
          game: widget.game,
          score: _score,
          hits: _hits,
          accuracy: accuracy,
        ),
      ),
    );
  }

  Future<void> _quit() async {
    _timer?.cancel();
    final ok = await confirmSheet(
      context,
      title: 'Quit this game?',
      message: 'Your score so far will not be saved.',
      confirmLabel: 'Quit',
      destructive: true,
    );
    if (ok && mounted) {
      Navigator.pop(context);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reticleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryDark, AppColors.ink],
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeInOut,
                    alignment: _target,
                    child: AnimatedBuilder(
                      animation: _reticleController,
                      builder: (context, child) {
                        final scale = 1.0 + (_reticleController.value * 0.18);
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.overlay, width: 3),
                          color: AppColors.overlay.withValues(alpha: 0.12),
                        ),
                        child: const Icon(Icons.adjust_rounded, color: AppColors.overlay, size: 30),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        _pill(Icons.timer_outlined, '0:${_secondsLeft.toString().padLeft(2, '0')}'),
                        const Spacer(),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: Colors.black38),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          onPressed: _quit,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 60,
                    child: Column(
                      children: [
                        Text('$_score',
                            style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -2)),
                        const Text('SCORE',
                            style: TextStyle(
                                fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w700, color: Colors.white54)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                      child: _flashText == null
                          ? const SizedBox(key: ValueKey('empty'), height: 34)
                          : Container(
                              key: ValueKey(_flashText),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(_flashText!,
                                  style: const TextStyle(
                                      color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w800)),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: AppColors.ink,
              child: Text(widget.game.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// UC-3.3 — View Mini-Game Result, driven by the real score the member
/// just earned in LiveMiniGameScreen rather than fixed sample numbers.
