import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import '../../application/membership_feature_host.dart';
import '../shared/membership_data_view.dart';
import 'purchase_plan_screen.dart';

class RenewScreen extends StatelessWidget {
  const RenewScreen({super.key, this.connected = false, this.repository});
  final bool connected;
  final MembershipCommerceRepository? repository;
  @override
  Widget build(BuildContext context) => repository != null
      ? MembershipRepositoryGuard(
          repository: repository!, child: _body(repository!))
      : MembershipFeatureHost(connected: connected, builder: _body);
  Widget _body(MembershipCommerceRepository repo) => MembershipDataView(
      repository: repo,
      title: 'Renew membership',
      builder: (context, data, refresh) {
        final entitlement = MembershipEntitlement.fromOverview(data);
        if (!entitlement.isResolved || entitlement.historicalOnly) {
          return [
            const Text(
                'Refresh online to verify your membership before renewal.')
          ];
        }
        if (!entitlement.hasPaidPlan) {
          return [
            const Text(
                'Free membership has no expiry. Choose a paid plan when you are ready to upgrade.')
          ];
        }
        final plans = membershipRows(data['plans'])
            .where((p) => p['planId'] == entitlement.paidPlanId);
        if (plans.isEmpty) {
          return [
            const Text(
                'Your current plan is not available for renewal. Contact your gym administrator.')
          ];
        }
        final p = plans.first;
        return [
          Text(
              '${entitlement.paidPlanName} · Paid expiry: ${membershipDate(entitlement.paidExpiresAtMillis)}'),
          const SizedBox(height: 16),
          Text(
              'Add ${p['durationDays']} days for ${membershipMoney(p['amountMinor'])}. Any paid remaining time is preserved. Final expiry is calculated by the server when payment clears.'),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: () => Navigator.push(
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
                          renewal: true))),
              child: const Text('Review renewal')),
        ];
      });
}
