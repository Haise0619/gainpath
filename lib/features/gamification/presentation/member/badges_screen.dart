import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/shared/shared.dart';
import 'package:gainpath/features/gamification/domain/entities/achievement_badge.dart';
import 'package:gainpath/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:gainpath/features/gamification/presentation/member/widgets/game_media.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unlocked = context.read<GamificationRepository>().badges.where((b) => b.unlocked).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Panel(
              background: AppColors.primaryTint,
              child: Row(
                children: [
                  const Icon(Icons.military_tech_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text('$unlocked of ${context.read<GamificationRepository>().badges.length} badges unlocked',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.92,
              children: context.read<GamificationRepository>().badges.map((b) => _BadgeCard(badge: b)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final AchievementBadge badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: () => badge.unlocked ? _showDetail(context) : showToast(context, 'Keep training to unlock this.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: badge.unlocked ? AppColors.heroGradient : null,
              color: badge.unlocked ? null : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Opacity(
                    opacity: badge.unlocked ? 1 : 0.35,
                    child: gameHero(badge.imageUrl, fit: BoxFit.contain),
                  ),
                ),
                if (!badge.unlocked)
                  const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.inkSoft),
              ],
            ),
          ),
          const Spacer(),
          Text(badge.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: badge.unlocked ? AppColors.ink : AppColors.inkSoft)),
          const SizedBox(height: 3),
          Text(badge.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
          if (!badge.unlocked && badge.progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: badge.progressValue,
                minHeight: 5,
                backgroundColor: AppColors.hairline,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 4),
            Text(badge.progressLabel ?? '',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
          ],
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: gameHero(badge.imageUrl, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 16),
            Text(badge.name, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(badge.description, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyLarge),
            const SizedBox(height: 14),
            statusPill('Unlocked'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showToast(ctx, 'Opening your device share sheet.'),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share badge'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// UC-3.8 — Generate Reward Redemption Voucher.
