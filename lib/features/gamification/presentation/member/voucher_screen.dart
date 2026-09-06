import 'package:flutter/material.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/shared/shared.dart';
import 'package:gainpath/features/gamification/domain/entities/reward_item.dart';
import 'package:gainpath/features/gamification/presentation/member/widgets/game_media.dart';

class VoucherScreen extends StatefulWidget {
  final RewardItem item;
  const VoucherScreen({super.key, required this.item});

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.05), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 45),
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
      appBar: AppBar(title: const Text('Your voucher')),
      body: PageBody(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Panel(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(height: 110, width: double.infinity, child: gameHero(widget.item.imageUrl)),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.item.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: const Text('GP-4K7M-92XA',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded,
                        size: 90, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('Show this at the front desk to claim your reward.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// UC-3.9 — View Leaderboard Standings, with a top-3 podium above the
/// ranked list.
