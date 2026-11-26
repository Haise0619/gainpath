import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
import '../member/browse_plans_screen.dart';
import '../member/billing_history_screen.dart';
import '../member/premium_upgrade_screen.dart';
import '../member/refund_request_screen.dart';
import '../member/renew_screen.dart';
import '../member/widgets/membership_components.dart';
import 'membership_data_view.dart';
import 'membership_billing_panel.dart';
import '../../application/membership_billing_repository.dart';

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
        final premium = availablePremiumUpgrade(data, e);
        final scheduled = verified ? membershipUpgradeSchedule(data) : null;
        Future<void> open(Widget page) async {
          await Navigator.push(
              context, MaterialPageRoute<void>(builder: (_) => page));
          if (context.mounted) refresh();
        }

        final hasBilling = repo is MembershipBillingRepository &&
            data['billing'] is Map &&
            data['billing']['status'] != null;

        return [
          if (repo is MembershipBillingRepository)
            MembershipBillingPanel(
              repository: repo,
              billingRepository: repo as MembershipBillingRepository,
              data: data,
              refresh: refresh,
            ),
          if (hasBilling) const SizedBox(height: 12),

          // 1. Compact Current Plan Card (Target: ~220–280dp height)
          MembershipStatusCard(
            entitlement: e,
            scheduledUpgrade: scheduled,
            onPrimaryAction: !verified
                ? refresh
                : () => open(expired || paid
                    ? RenewScreen(repository: repo)
                    : BrowsePlansScreen(repository: repo)),
            onUpgradeAction: premium != null
                ? () =>
                    open(PremiumUpgradeScreen(repository: repo, plan: premium))
                : null,
          ),
          const SizedBox(height: 16),

          // 2. Compact 2-Column Membership Benefits Grid
          MembershipBenefitsGrid(entitlement: e),

          // 3. Retained previous facts for expired members
          if (expired && e.paidTier != null) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 20, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Previous paid membership',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.paidTier!.label} · Expired ${membershipDate(e.paidExpiresAtMillis)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // 4. Compact Billing, Plans & Support Navigation
          Text(
            'Billing & Plans',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 8),
          if (membershipRows(data['transactions']).isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No membership payments yet.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.compare_arrows_rounded,
                        size: 18, color: AppColors.primary),
                  ),
                  title: const Text('Compare membership plans',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text(
                      'View and compare Free, Basic and Premium',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.inkSoft),
                  onTap: () => open(BrowsePlansScreen(repository: repo)),
                ),
                const Divider(height: 1, color: AppColors.hairline),
                ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        size: 18, color: AppColors.primary),
                  ),
                  title: const Text('Billing history',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text(
                      'Payments, invoices and payment recovery',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.inkSoft),
                  onTap: () => open(BillingHistoryScreen(repository: repo)),
                ),
                const Divider(height: 1, color: AppColors.hairline),
                ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.help_outline_rounded,
                        size: 18, color: AppColors.primary),
                  ),
                  title: const Text('Refund requests and status',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text('Review a payment or request assistance',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.inkSoft),
                  onTap: () => open(RefundRequestScreen(repository: repo)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ];
      });
}
