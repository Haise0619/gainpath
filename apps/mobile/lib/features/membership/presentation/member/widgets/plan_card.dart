import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/membership.dart';

/// Full-detail plan card used on the Browse Plans screen: name, price,
/// perks checklist, and a call to action that adapts to whether this is
/// the member's current plan. Kept as a single shared widget so the plan
/// comparison always reads consistently no matter where it's shown.
class PlanCard extends StatelessWidget {
  final MembershipPlan plan;
  final bool isCurrent;
  final VoidCallback? onSelect;
  final String periodLabel;
  final String? actionLabel, note;

  const PlanCard({
    super.key,
    required this.plan,
    required this.isCurrent,
    required this.onSelect,
    this.periodLabel = '/ month',
    this.actionLabel,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.hairline,
          width: isCurrent ? 1.8 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8))
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(plan.name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontSize: 22))),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Flexible(child: statusPill('Current plan')),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(plan.tagline,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 14),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text('RM ${plan.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1)),
                    Text(periodLabel,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 16),
                ...plan.perks.map((perk) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 17, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(perk,
                                  style: const TextStyle(
                                      fontSize: 13.5, height: 1.3))),
                        ],
                      ),
                    )),
                const SizedBox(height: 6),
                if (note != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(note!,
                          style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                              height: 1.5))),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onSelect,
                    child: Text(actionLabel ?? 'Choose ${plan.name}',
                        textAlign: TextAlign.center),
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
