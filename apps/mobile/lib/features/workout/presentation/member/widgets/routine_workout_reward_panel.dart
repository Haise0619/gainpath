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
      this.difficulty});
  final WorkoutRewardAttemptReference reference;
  final bool Function() isCurrent;
  final String? difficulty;
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
          return Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Icon(Icons.lock_outline_rounded,
                    color: AppColors.primary),
                const SizedBox(height: 8),
                Text('Workout rewards · Not active',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                    'Routine completion is saved separately. Workout rewards stay off pending physical validation and policy activation.'),
                if (difficulty != null) ...[
                  const SizedBox(height: 8),
                  Text('Difficulty: $difficulty')
                ],
                const SizedBox(height: 8),
                const Text(
                    'Mixed and manual routines are excluded from automatic rewards. Provisional measurements do not qualify.'),
                const SizedBox(height: 8),
                const Text(
                    'Premium 1.5×, difficulty multipliers and form-score bonuses are not active.'),
              ]));
        });
  }
}
