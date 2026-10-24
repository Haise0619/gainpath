import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../app/di/membership_factory.dart';
import '../member/browse_plans_screen.dart';
import '../member/billing_history_screen.dart';
import '../member/refund_request_screen.dart';
import '../member/renew_screen.dart';
import 'membership_data_view.dart';

class MembershipDashboardScreen extends StatelessWidget {
  const MembershipDashboardScreen(
      {super.key,
      this.connected = false,
      this.planName,
      this.status,
      this.repository});
  final bool connected;
  final String? planName, status;
  final MembershipCommerceRepository? repository;
  @override
  Widget build(BuildContext context) => repository != null
      ? MembershipRepositoryGuard(
          repository: repository!, child: _body(repository!))
      : MembershipFeatureHost(connected: connected, builder: _body);
  Widget _body(MembershipCommerceRepository repo) => MembershipDataView(
      repository: repo,
      title: 'Membership',
      builder: (context, data, refresh) {
        final entitlement = MembershipEntitlement.fromOverview(data);
        final tierName = entitlement.effectiveTier?.label;
        final canAct = entitlement.canStartCheckout;
        final isFree = entitlement.effectiveTier == MembershipTier.free;
        final transactions = membershipRows(data['transactions']);
        Future<void> open(Widget page) async {
          await Navigator.push(
              context, MaterialPageRoute<void>(builder: (_) => page));
          if (context.mounted) refresh();
        }

        return [
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CURRENT PLAN · ALL BRANCHES',
                        style: TextStyle(
                            color: Colors.white70,
                            letterSpacing: 1.2,
                            fontSize: 11)),
                    const SizedBox(height: 8),
                    Text(
                        tierName == null
                            ? 'Membership status unavailable'
                            : entitlement.historicalOnly
                                ? 'Last verified tier · $tierName'
                                : tierName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                        !entitlement.isResolved
                            ? 'Refresh online to verify your membership.'
                            : isFree
                                ? 'No expiry · No membership charge'
                                : '${entitlement.historicalOnly ? 'Last recorded paid status' : 'Paid membership active'} · Expires ${membershipDate(entitlement.paidExpiresAtMillis)}',
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                    const Text(
                        'Auto-renew unavailable. Renew manually; no recurring charge is scheduled.',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    Wrap(spacing: 12, runSpacing: 8, children: [
                      FilledButton(
                          onPressed: canAct
                              ? () => open(BrowsePlansScreen(repository: repo))
                              : null,
                          child: Text(isFree ? 'Upgrade' : 'Browse plans')),
                      if (entitlement.isResolved && entitlement.hasPaidPlan)
                        OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white),
                            onPressed: canAct
                                ? () => open(RenewScreen(repository: repo))
                                : null,
                            child: Text(entitlement.paidStatus ==
                                    PaidMembershipStatus.expired
                                ? 'Renew ${entitlement.paidTier!.label}'
                                : 'Renew now')),
                    ])
                  ])),
          const SizedBox(height: 16),
          if (entitlement.paidStatus == PaidMembershipStatus.expired)
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Eyebrow('Previous paid membership'),
                  Text(
                      '${entitlement.paidTier!.label} · Expired ${membershipDate(entitlement.paidExpiresAtMillis)}'),
                  const Text(
                      'Your previous paid period and billing history are retained.'),
                ])),
          if (isFree)
            const Panel(
                child: Text(
                    'Digital fitness access follows your existing account permissions.')),
          if (entitlement.benefits.isNotEmpty)
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Eyebrow(entitlement.historicalOnly
                      ? 'Last recorded benefits'
                      : 'Your benefits'),
                  ...((entitlement.benefits).map((p) => ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(p))))
                ])),
          const SizedBox(height: 16),
          const Eyebrow('Recent membership billing'),
          Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                if (transactions.isEmpty)
                  const ListTile(title: Text('No membership payments yet.')),
                ...transactions.take(2).map((p) => ListTile(
                    title: Text('${p['planName']}'),
                    subtitle: Text(membershipPaymentLabel(p)),
                    trailing: Text(membershipMoney(p['amountMinor'])))),
                ListTile(
                    title: const Text('View all billing history'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(BillingHistoryScreen(repository: repo))),
              ])),
          TextButton.icon(
              onPressed: () => open(RefundRequestScreen(repository: repo)),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Refund requests and status')),
        ];
      });
}
