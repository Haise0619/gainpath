import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../application/membership_feature_host.dart';
import '../shared/membership_data_view.dart';
import 'purchase_plan_screen.dart';

MembershipPlan? availablePremiumUpgrade(
    Map<String, dynamic> overview, MembershipEntitlement entitlement) {
  if (overview['upgradeSupported'] != true ||
      !entitlement.canStartCheckout ||
      entitlement.effectiveTier != MembershipTier.basic ||
      membershipUpgradeSchedule(overview) != null) {
    return null;
  }
  final plan = membershipRows(overview['plans'])
      .where((p) => p['planId'] == 'premium')
      .firstOrNull;
  return plan == null
      ? null
      : MembershipPlan(
          'premium',
          plan['name'] as String,
          (plan['amountMinor'] as num) / 100,
          membershipPlanPositioning('premium'),
          membershipProductBenefits('premium'));
}

class PremiumUpgradeScreen extends StatelessWidget {
  const PremiumUpgradeScreen(
      {super.key, required this.repository, required this.plan});

  final MembershipCommerceRepository repository;
  final MembershipPlan plan;

  @override
  Widget build(BuildContext context) {
    Future<void> review(MembershipUpgradeMode mode) => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => PurchasePlanScreen(
                plan: plan, repository: repository, upgradeMode: mode)));

    return MembershipRepositoryGuard(
        repository: repository,
        child: Scaffold(
          appBar: AppBar(title: const Text('Upgrade to Premium')),
          body: PageBody(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 8),
              Text(
                'Choose how you want to upgrade',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select immediate prorated activation or schedule Premium to start after your current term.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.inkSoft,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Immediate Upgrade Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primarySoft.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Use Premium now',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Immediate',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pay the difference for your remaining Basic time and buy another 30 days of Premium in one payment.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.inkSoft,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () =>
                            review(MembershipUpgradeMode.immediate),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Upgrade now and extend 30 days'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Option 2: Next Term Upgrade Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.inkSoft,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Use Premium next term',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Scheduled',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Pay for 30 days of Premium now. Your current Basic access continues until it expires.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.inkSoft,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => review(MembershipUpgradeMode.nextTerm),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        child:
                            const Text('Start Premium after Basic expires'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'One-time payment · Accurate server proration calculated on checkout.',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ));
  }
}
