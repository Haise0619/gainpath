import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../data/mock_data.dart';
import '../../../../widgets/shared.dart';

/// Defensive online-image loader: a broken/slow link never breaks the
/// layout — the same pattern already used across onboarding, profile
/// setup, the workout module, and gamification.
Widget networkAvatar(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// A coach summary card for the Browse Coaches list: online avatar,
/// verified badge, top specialization tags, rating, and fee — enough to
/// compare coaches at a glance without opening every profile.
class CoachCard extends StatelessWidget {
  final Coach coach;
  final VoidCallback onTap;
  const CoachCard({super.key, required this.coach, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(width: 58, height: 58, child: networkAvatar(coach.imageUrl)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(coach.name, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (coach.verified) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded, size: 15, color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(coach.specialty,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: coach.specializationTags.take(2).map((t) => _Tag(t)).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 15, color: AppColors.accent),
                    const SizedBox(width: 3),
                    Text('${coach.rating}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('  (${coach.reviews})', style: Theme.of(context).textTheme.bodyMedium),
                    const Spacer(),
                    Text('RM ${coach.fee.toStringAsFixed(0)}/session',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
    );
  }
}
