import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/membership.dart';

/// Full-detail plan card used on the Browse Plans screen: name, price,
/// perks checklist, and a call to action that adapts to whether this is
/// the member's current plan.
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary
              : AppColors.hairline,
          width: isCurrent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primarySoft.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Current plan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plan.tagline,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      'RM ${plan.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      periodLabel,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...plan.perks.map((perk) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              perk,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.ink,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      note!,
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: onSelect,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(
                      actionLabel ?? 'Choose ${plan.name}',
                      textAlign: TextAlign.center,
                    ),
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
