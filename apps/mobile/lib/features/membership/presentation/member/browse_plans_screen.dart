import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
import '../../domain/membership_renewal_preview.dart';
import '../shared/membership_data_view.dart';
import 'purchase_plan_screen.dart';
import 'premium_upgrade_screen.dart';
import 'widgets/plan_card.dart';

class BrowsePlansScreen extends StatelessWidget {
  const BrowsePlansScreen(
      {super.key, this.connected = false, this.repository});
  final bool connected;
  final MembershipCommerceRepository? repository;
  @override
  Widget build(BuildContext context) => repository != null
      ? MembershipRepositoryGuard(
          repository: repository!, child: _body(repository!))
      : MembershipFeatureHost(connected: connected, builder: _body);
  Widget _body(MembershipCommerceRepository repo) => MembershipDataView(
      repository: repo,
      title: 'Membership plans',
      builder: (context, data, refresh) {
        final e = MembershipEntitlement.fromOverview(data);
        final upgrade = availablePremiumUpgrade(data, e);
        final scheduled =
            e.canStartCheckout ? membershipUpgradeSchedule(data) : null;
        final plans = membershipRows(data['plans'])
            .where((p) => ['basic', 'premium'].contains(p['planId']));
        final active = e.paidStatus == PaidMembershipStatus.active;
        return [
          const SizedBox(height: 8),
          Text(
            'Membership Plans',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose the plan that fits your fitness journey. Digital fitness is always free.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.inkSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // 1. Compact Free Plan Summary Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: e.effectiveTier == MembershipTier.free &&
                        !e.historicalOnly
                    ? AppColors.primarySoft.withValues(alpha: 0.5)
                    : AppColors.hairline,
                width: 1.0,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06190F2E),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Free',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (e.effectiveTier == MembershipTier.free &&
                        !e.historicalOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(14),
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
                ),
                const SizedBox(height: 2),
                const Text(
                  'Digital Fitness · RM0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 10),
                ...membershipProductBenefits('free').map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 15, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              b,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.ink,
                                  height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 6),
                const Text(
                  'Your points are saved. Active Basic or Premium membership is needed to redeem physical rewards.',
                  style: TextStyle(
                      color: AppColors.inkSoft, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!e.isResolved || e.historicalOnly)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Refresh online to verify your membership before checkout.',
                style: TextStyle(color: AppColors.warning, fontSize: 13),
              ),
            ),
          if (scheduled != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Premium is scheduled for ${membershipDate(scheduled['startsAtMillis'])}.',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
          if (active && scheduled == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Renew your current plan to keep all remaining time.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
              ),
            ),
          if (plans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No membership plans are configured. Contact your gym administrator.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13.5),
              ),
            ),
          ...plans.map((p) {
            final tier = p['planId'] as String;
            final current = active && e.paidPlanId == tier;
            final canUpgrade = tier == 'premium' && upgrade != null;
            final switching = active && !current && !canUpgrade;
            final plan = MembershipPlan(
                tier,
                p['name'] as String,
                (p['amountMinor'] as num) / 100,
                membershipPlanPositioning(tier),
                membershipProductBenefits(tier));
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PlanCard(
                plan: plan,
                periodLabel: '/ ${p['durationDays']} days',
                isCurrent: current,
                actionLabel: scheduled != null
                    ? 'Premium already scheduled'
                    : canUpgrade
                        ? 'Upgrade to Premium'
                        : current || e.paidPlanId == tier
                            ? 'Renew ${plan.name}'
                            : switching
                                ? 'Available after current plan expires'
                                : 'Choose ${plan.name}',
                note: tier == 'premium'
                    ? 'Premium-exclusive rewards depend on catalogue. Extra check-in points and coach discounts require active policy.'
                    : 'All Free digital fitness features are included.',
                onSelect: !e.canStartCheckout || switching || scheduled != null
                    ? null
                    : () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => canUpgrade
                                    ? PremiumUpgradeScreen(
                                        repository: repo, plan: plan)
                                    : PurchasePlanScreen(
                                        plan: plan,
                                        repository: repo,
                                        renewalPreview:
                                            MembershipRenewalPreview
                                                .fromOverview(e, tier),
                                        renewal: e.paidPlanId == tier)));
                        if (context.mounted) refresh();
                      },
              ),
            );
          }),

          // 2. Compact Compare All Features Section
          if (plans.isNotEmpty) ...[
            const SizedBox(height: 6),
            const PlanFeatureComparisonTable(),
          ],

          const SizedBox(height: 12),
          const Text(
            'Paid terms are exactly 30 × 24 hours. No automatic renewal. Gym membership is organization-wide; individual services retain their branch requirements.',
            style: TextStyle(
                color: AppColors.inkSoft, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
        ];
      });
}

/// Compact feature comparison table allowing side-by-side entitlement comparison.
class PlanFeatureComparisonTable extends StatelessWidget {
  const PlanFeatureComparisonTable({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('AI Rep Tracker', '✓', '✓', '✓'),
      ('Video Tutorials', '✓', '✓', '✓'),
      ('Training Programs', '✓', '✓', '✓'),
      ('Gym Entry', '—', 'All Branches', 'All Branches'),
      ('Coach Booking', '—', '✓', '✓ Priority'),
      ('Mini-Games', '✓', '✓', '✓'),
      ('Rewards', 'Points', 'Physical', 'Exclusive'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Compare All Features',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        fontSize: 15,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3.8),
              1: FlexColumnWidth(2.0),
              2: FlexColumnWidth(2.6),
              3: FlexColumnWidth(2.6),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Text('Feature',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                    child: Text('Free Tier',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                    child: Text('Basic Tier',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                    child: Text('Premium Tier',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark)),
                  ),
                ],
              ),
              ...rows.map((r) => TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Text(r.$1,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                        child: Text(r.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                color: r.$2 == '—'
                                    ? AppColors.inkSoft
                                    : AppColors.ink)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                        child: Text(r.$3,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                        child: Text(r.$4,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark)),
                      ),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
