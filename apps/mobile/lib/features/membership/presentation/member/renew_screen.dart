import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_feature_host.dart';
import '../../domain/membership_renewal_preview.dart';
import '../shared/membership_data_view.dart';
import 'purchase_plan_screen.dart';
import 'widgets/membership_components.dart';

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
      title: 'Renewal Review',
      builder: (context, data, refresh) {
        final entitlement = MembershipEntitlement.fromOverview(data);
        if (!entitlement.isResolved || entitlement.historicalOnly) {
          return [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Panel(
                child: Text(
                    'Refresh online to verify your membership before renewal.'),
              ),
            ),
          ];
        }
        if (!entitlement.hasPaidPlan) {
          return [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Panel(
                child: Text(
                    'Free membership has no expiry. Choose a paid plan when you are ready to upgrade.'),
              ),
            ),
          ];
        }
        final scheduled = membershipUpgradeSchedule(data);
        if (scheduled != null) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Panel(
                child: Text(
                    'Premium is already scheduled for ${membershipDate(scheduled['startsAtMillis'])}.'),
              ),
            ),
          ];
        }
        final plans = membershipRows(data['plans'])
            .where((p) => p['planId'] == entitlement.paidPlanId);
        if (plans.isEmpty) {
          return [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Panel(
                child: Text(
                    'Your current plan is not available for renewal. Contact your gym administrator.'),
              ),
            ),
          ];
        }
        final p = plans.first;
        final preview = MembershipRenewalPreview.fromOverview(
            entitlement, p['planId'] as String);
        return [
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primarySoft.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A190F2E),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Renew ${entitlement.paidTier!.label}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                    ),
                    const PaymentStatusIndicator(
                        status: 'cleared', label: 'Active'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Current expiry: ${membershipDate(entitlement.paidExpiresAtMillis)}',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated new expiry: ${membershipDate(preview?.estimatedExpiry(p['durationDays']))}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => PurchasePlanScreen(
                                  plan: MembershipPlan(
                                      p['planId'] as String,
                                      p['name'] as String,
                                      (p['amountMinor'] as num) / 100,
                                      '${p['durationDays']} days',
                                      List<String>.from(
                                          p['benefits'] as List)),
                                  repository: repo,
                                  renewalPreview: preview,
                                  renewal: true)));
                      if (context.mounted) refresh();
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Review renewal'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'One-time payment · No automatic renewal or recurring charges.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ];
      });
}
