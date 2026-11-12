import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
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
        final e = MembershipEntitlement.fromOverview(data);
        final paid = e.paidStatus == PaidMembershipStatus.active;
        final expired = e.paidStatus == PaidMembershipStatus.expired;
        final verified = e.canStartCheckout;
        Future<void> open(Widget page) async {
          await Navigator.push(
              context, MaterialPageRoute<void>(builder: (_) => page));
          if (context.mounted) refresh();
        }

        final tier = e.effectiveTier?.label;
        final title = !e.isResolved
            ? 'Verification required'
            : e.historicalOnly
                ? 'Last verified tier · $tier'
                : tier!;
        final action = !verified
            ? 'Verify Membership'
            : expired
                ? 'Renew Membership'
                : paid
                    ? 'Renew ${e.paidTier!.label}'
                    : 'Explore Plans';
        return [
          const SizedBox(height: 8),
          Panel(
              background: AppColors.primaryTint,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.card_membership_rounded,
                          color: AppColors.primary, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              paid
                                  ? 'GYM MEMBERSHIP · ALL BRANCHES'
                                  : 'YOUR MEMBERSHIP',
                              style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8))),
                    ]),
                    const SizedBox(height: 16),
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                        !e.isResolved
                            ? 'Connect to verify your paid membership. Your saved fitness records remain available.'
                            : expired
                                ? 'Your paid membership has expired. Digital fitness and saved points remain yours.'
                                : e.historicalOnly
                                    ? 'Historical record · Refresh online before using paid benefits.'
                                    : paid
                                        ? 'Paid membership active'
                                        : 'Full digital fitness, always available.',
                        style: const TextStyle(
                            color: AppColors.inkSoft, height: 1.5)),
                    if (e.paidExpiresAtMillis != null) ...[
                      const SizedBox(height: 12),
                      Text(
                          '${expired ? 'Expired' : e.historicalOnly ? 'Last recorded expiry' : 'Expires'} ${membershipDate(e.paidExpiresAtMillis)}',
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600)),
                    ],
                    if (!paid && !expired && e.isResolved)
                      const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text('No expiry · No membership charge')),
                    const SizedBox(height: 18),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: !verified
                                ? refresh
                                : () => open(expired || paid
                                    ? RenewScreen(repository: repo)
                                    : BrowsePlansScreen(repository: repo)),
                            child: Text(action))),
                    const SizedBox(height: 10),
                    const Text('No automatic renewal or recurring charge.',
                        style:
                            TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                  ])),
          const SizedBox(height: 22),
          Text(
              paid && !e.historicalOnly
                  ? 'Included with ${e.effectiveTier!.label}'
                  : 'Your digital fitness',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(paid && !e.historicalOnly
              ? 'Gym entry, coach booking, Mini Games and eligible regular physical rewards.'
              : 'AI workouts, tutorials, training programs, history, reports and PDF export remain available under your account permissions.'),
          const SizedBox(height: 10),
          const Text(
              'Daily check-in points stay in your wallet. Physical reward redemption requires active Basic or Premium membership.'),
          if (paid && e.effectiveTier == MembershipTier.premium)
            const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                    'Premium-exclusive rewards are available only where configured in the rewards catalogue. Additional check-in bonuses and coach offers are shown only when enabled.')),
          if (expired) ...[
            const SizedBox(height: 18),
            Text('Previous paid membership',
                style: Theme.of(context).textTheme.titleMedium),
            Text(
                '${e.paidTier!.label} · Expired ${membershipDate(e.paidExpiresAtMillis)}'),
            const Text(
                'Your previous paid period, bookings and billing history are retained.'),
          ],
          const SizedBox(height: 14),
          TextButton.icon(
              onPressed: () => open(BrowsePlansScreen(repository: repo)),
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Text('Compare membership plans')),
          const SizedBox(height: 18),
          Text('Billing & support',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (membershipRows(data['transactions']).isEmpty)
            const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('No membership payments yet.')),
          Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Billing history'),
                    subtitle:
                        const Text('Payments, invoices and payment recovery'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(BillingHistoryScreen(repository: repo))),
                const Divider(height: 1),
                ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: const Text('Refund requests and status'),
                    subtitle:
                        const Text('Review a payment or request assistance'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => open(RefundRequestScreen(repository: repo))),
              ])),
          const SizedBox(height: 12),
        ];
      });
}
