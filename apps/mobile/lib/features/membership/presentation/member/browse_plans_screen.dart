import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
import '../../domain/membership_renewal_preview.dart';
import '../shared/membership_data_view.dart';
import 'purchase_plan_screen.dart';
import 'widgets/plan_card.dart';

class BrowsePlansScreen extends StatelessWidget {
  const BrowsePlansScreen({super.key, this.connected = false, this.repository});
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
        final plans = membershipRows(data['plans'])
            .where((p) => ['basic', 'premium'].contains(p['planId']));
        final active = e.paidStatus == PaidMembershipStatus.active;
        return [
          const SizedBox(height: 8),
          Text('Fitness for everyone. More with membership.',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.ink)),
          const SizedBox(height: 8),
          const Text(
              'Keep full digital fitness for free. Choose paid membership for the gym, coaching and more.'),
          const SizedBox(height: 16),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Free',
                          style: Theme.of(context).textTheme.titleLarge),
                      if (e.effectiveTier == MembershipTier.free &&
                          !e.historicalOnly)
                        const Chip(
                            label: Text('Current plan'),
                            visualDensity: VisualDensity.compact),
                    ]),
                const Text('Digital Fitness · RM0'),
                const SizedBox(height: 10),
                ...membershipProductBenefits('free').map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $b'))),
                const SizedBox(height: 6),
                const Text(
                    'Your points are saved. Active Basic or Premium membership is needed to redeem physical rewards.'),
              ])),
          const SizedBox(height: 16),
          if (!e.isResolved || e.historicalOnly)
            const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                    'Refresh online to verify your membership before checkout.')),
          if (active)
            const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                    'Renew your current plan to keep all remaining time. Direct paid-tier changes are unavailable while your membership is active.')),
          if (plans.isEmpty)
            const Text(
                'No membership plans are configured. Contact your gym administrator.'),
          ...plans.map((p) {
            final tier = p['planId'] as String;
            final current = active && e.paidPlanId == tier;
            final switching = active && !current;
            final plan = MembershipPlan(
                tier,
                p['name'] as String,
                (p['amountMinor'] as num) / 100,
                membershipPlanPositioning(tier),
                membershipProductBenefits(tier));
            return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PlanCard(
                    plan: plan,
                    periodLabel: '/ ${p['durationDays']} days',
                    isCurrent: current,
                    actionLabel: current || e.paidPlanId == tier
                        ? 'Renew ${plan.name}'
                        : switching
                            ? 'Available after current plan expires'
                            : 'Choose ${plan.name}',
                    note: tier == 'premium'
                        ? 'Premium-exclusive rewards depend on the configured catalogue. Extra check-in points and coach discounts are not included until their policies are enabled.'
                        : 'All Free digital fitness features are included.',
                    onSelect: !e.canStartCheckout || switching
                        ? null
                        : () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => PurchasePlanScreen(
                                        plan: plan,
                                        repository: repo,
                                        renewalPreview: MembershipRenewalPreview.fromOverview(e, tier),
                                        renewal: e.paidPlanId == tier)));
                            if (context.mounted) refresh();
                          }));
          }),
          const Text(
              'Paid terms are exactly 30 × 24 hours. No automatic renewal. Gym membership is organization-wide; individual services retain their branch requirements.'),
          const SizedBox(height: 12),
        ];
      });
}
