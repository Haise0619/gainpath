import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../data/mock_data.dart';
import '../../../../widgets/shared.dart';

/// Full-detail plan card used on the Browse Plans screen: name, price,
/// perks checklist, and a call to action that adapts to whether this is
/// the member's current plan. Kept as a single shared widget so the plan
/// comparison always reads consistently no matter where it's shown.
class PlanCard extends StatelessWidget {
  final MembershipPlan plan;
  final bool isCurrent;
  final VoidCallback onSelect;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isCurrent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.popular ? AppColors.primary : AppColors.hairline,
          width: plan.popular ? 1.8 : 1,
        ),
        boxShadow: plan.popular
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 8))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.popular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: const Text('MOST POPULAR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(plan.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      statusPill('Current'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(plan.tagline, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('RM ${plan.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
                    const SizedBox(width: 4),
                    Text('/ month', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 16),
                ...plan.perks.map((perk) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 17, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(child: Text(perk, style: const TextStyle(fontSize: 13.5, height: 1.3))),
                        ],
                      ),
                    )),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: isCurrent
                      ? OutlinedButton(onPressed: null, child: const Text('Your current plan'))
                      : FilledButton(
                          onPressed: onSelect,
                          child: Text('Choose ${plan.name}'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
