import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/workout_rewards.dart';

/// Completion is independent of the physical validation release hold.
/// This widget uses a local status operation only, never a callable or claim.
class RoutineWorkoutRewardPanel extends StatelessWidget {
  const RoutineWorkoutRewardPanel(
      {super.key,
      required this.reference,
      required this.isCurrent,
      this.videoWorkoutPointsEnabled = false,
      this.difficulty});
  final WorkoutRewardAttemptReference reference;
  final bool Function() isCurrent;
  final String? difficulty;
  final bool videoWorkoutPointsEnabled;
  @override
  Widget build(BuildContext context) {
    if (!isCurrent()) return const SizedBox.shrink();
    return FutureBuilder<WorkoutRewardStatus>(
        future: DisabledWorkoutRewardsRepository(
                scope: reference.scope, isCurrent: isCurrent)
            .status(reference),
        initialData: workoutRewardsPhysicalHold,
        builder: (context, result) {
          if (!isCurrent() ||
              result.hasError ||
              result.data?.status != 'disabled') {
            return const SizedBox.shrink();
          }
          return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.accentTint,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: .25))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color:
                                      AppColors.surface.withValues(alpha: .8),
                                  borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.card_giftcard_rounded,
                                  color: AppColors.accentDark, size: 25)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Workout points',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            color: AppColors.ink,
                                            fontWeight: FontWeight.w700)),
                              ])),
                        ]),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFEED9AE), height: 1),
                    const SizedBox(height: 14),
                    Text(
                        videoWorkoutPointsEnabled
                            ? 'AI Tracked · 10 points  /  Video Guided · 5 points'
                            : 'Workout rewards · Not active',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: AppColors.accentDark)),
                    const SizedBox(height: 8),
                    Text(videoWorkoutPointsEnabled
                        ? 'Complete an eligible exercise to earn points once per day. Confirmed points appear in Points History.'
                        : 'This workout does not add redeemable points. You can still progress toward training badges.'),
                  ]));
        });
  }
}
