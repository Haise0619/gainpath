import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import 'book_session_screen.dart';
import 'widgets/coach_card.dart';

/// AD-M7.1 (detail) — Coach Profile. Every figure here is read from the
/// specific [coach] passed in — years of experience, sessions completed,
/// response time, fee, and branch all used to be the same hardcoded
/// numbers for every coach; now each profile reflects that coach alone.
class CoachProfileScreen extends StatelessWidget {
  final Coach coach;
  const CoachProfileScreen({super.key, required this.coach});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(coach.name)),
      body: PageBody(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(width: 84, height: 84, child: networkAvatar(coach.imageUrl)),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(coach.name,
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                    if (coach.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded, size: 19, color: Colors.white),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(coach.specialty, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 17, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text('${coach.rating}',
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('  ·  ${coach.reviews} reviews  ·  ${coach.branch}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: StatTile('${coach.yearsExperience}y', 'Experience')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile('${coach.sessionsCompleted}', 'Sessions run')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile('${coach.reviews}', 'Reviews')),
            ],
          ),
          const SizedBox(height: 18),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(coach.responseTime, style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Specializes in'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: coach.specializationTags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(t,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
          const Eyebrow('About'),
          Panel(
            child: Text(coach.bio, style: const TextStyle(fontSize: 14.5, height: 1.5)),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Session'),
          Panel(
            child: Column(
              children: [
                const DetailRow('Duration', '60 minutes'),
                const Divider(height: 20),
                DetailRow('Fee', 'RM ${coach.fee.toStringAsFixed(0)}'),
                const Divider(height: 20),
                DetailRow('Location', coach.branch),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('What members say'),
          ...coach.topReviews.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.memberName, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < r.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 15,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(r.reviewText, style: const TextStyle(fontSize: 13.5, height: 1.45)),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => BookSessionScreen(coach: coach))),
            child: const Text('Book a session'),
          ),
        ],
      ),
    );
  }
}
