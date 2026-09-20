import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/gamification_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gamification.dart';
import 'voucher_screen.dart';
import 'widgets/game_media.dart';

class RewardShopScreen extends StatelessWidget {
  const RewardShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Redeem points')),
      body: PageBody(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                const SizedBox(width: 12),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: context.watch<GamificationBloc>().state.points),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text('$value points available',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...context.read<GamificationRepository>().rewards.map((r) {
            final affordable = context.watch<GamificationBloc>().state.points >= r.points;
            final needed = r.points - context.watch<GamificationBloc>().state.points;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                      child: SizedBox(
                        width: 74,
                        height: 74,
                        child: Opacity(opacity: affordable ? 1 : 0.45, child: gameHero(r.imageUrl)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('${r.points} points  ·  ${r.stock} left',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                          if (!affordable) ...[
                            const SizedBox(height: 2),
                            Text('$needed more points needed',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.warning)),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: affordable ? () => _redeem(context, r) : null,
                        child: const Text('Redeem'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Show your voucher code at the front desk. Staff will confirm '
                    'the reward and mark the code as used.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _redeem(BuildContext context, RewardItem item) async {
    final ok = await confirmSheet(
      context,
      title: 'Redeem ${item.title}?',
      message:
          'This uses ${item.points} points and creates a voucher code you show at the front desk.',
      confirmLabel: 'Redeem',
    );
    if (ok && context.mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => VoucherScreen(item: item)));
    }
  }
}
