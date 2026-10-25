import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
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
        final entitlement = MembershipEntitlement.fromOverview(data);
        final plans = membershipRows(data['plans'])
            .where((p) => ['basic', 'premium'].contains(p['planId']))
            .toList();
        return [
          const Text(
              'Membership applies across GainPath branches. Paid prices and benefits come from the plan catalogue.'),
          const SizedBox(height: 20),
          const Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Free',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('No membership charge · No expiry'),
                SizedBox(height: 8),
                Text(
                    'Digital fitness access follows your existing account permissions. No purchase is needed.'),
              ])),
          const SizedBox(height: 16),
          if (!entitlement.isResolved)
            const Text(
                'Membership status unavailable. Refresh online before choosing a paid plan.'),
          if (entitlement.historicalOnly)
            const Text(
                'Refresh online to verify your current membership before checkout.'),
          if (entitlement.paidStatus == PaidMembershipStatus.active)
            const Text(
                'You can renew your current plan. Switching paid tiers is available after expiry.'),
          if (plans.isEmpty)
            const Text(
                'No membership plans are configured. Contact your gym administrator.'),
          ...plans.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PlanCard(
                plan: MembershipPlan(
                    p['planId'] as String,
                    p['name'] as String,
                    (p['amountMinor'] as num) / 100,
                    '${p['durationDays']} days',
                    List<String>.from(p['benefits'] as List)),
                periodLabel: '/ ${p['durationDays']} days',
                isCurrent: false,
                onSelect: !entitlement.canStartCheckout ||
                        (entitlement.paidStatus ==
                                PaidMembershipStatus.active &&
                            p['planId'] != entitlement.paidPlanId)
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => PurchasePlanScreen(
                                plan: MembershipPlan(
                                    p['planId'] as String,
                                    p['name'] as String,
                                    (p['amountMinor'] as num) / 100,
                                    '${p['durationDays']} days',
                                    List<String>.from(p['benefits'] as List)),
                                repository: repo,
                                renewal:
                                    entitlement.paidPlanId == p['planId']))),
              ))),
        ];
      });
}
