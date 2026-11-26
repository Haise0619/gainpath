import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../shared/membership_data_view.dart';

/// Status badge displaying payment or membership status with semantic colors.
class PaymentStatusIndicator extends StatelessWidget {
  const PaymentStatusIndicator({
    super.key,
    required this.status,
    this.refundStatus,
    this.label,
  });

  final String? status;
  final String? refundStatus;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon, String text) = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label ?? text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData, String) _resolve() {
    if (refundStatus != null) {
      return switch (refundStatus) {
        'approved' => (AppColors.infoTint, AppColors.info, Icons.check_circle_outline_rounded, 'Refund Approved'),
        'completed' => (AppColors.successTint, AppColors.success, Icons.task_alt_rounded, 'Refunded'),
        'rejected' => (AppColors.dangerTint, AppColors.danger, Icons.cancel_outlined, 'Declined'),
        'processing' => (AppColors.warning.withValues(alpha: 0.15), AppColors.warning, Icons.sync_rounded, 'Processing'),
        _ => (AppColors.warning.withValues(alpha: 0.15), AppColors.warning, Icons.pending_outlined, 'Under Review'),
      };
    }
    return switch (status) {
      'cleared' || 'confirmed' => (AppColors.successTint, AppColors.success, Icons.check_circle_rounded, 'Active'),
      'awaiting_payment' || 'creating' => (AppColors.warning.withValues(alpha: 0.15), AppColors.warning, Icons.schedule_rounded, 'Awaiting Payment'),
      'reconciliation_required' => (AppColors.infoTint, AppColors.info, Icons.help_outline_rounded, 'Needs Review'),
      'check_payment_status' => (AppColors.infoTint, AppColors.info, Icons.refresh_rounded, 'Check status'),
      'expired' => (AppColors.inkSoft.withValues(alpha: 0.12), AppColors.inkSoft, Icons.timer_off_outlined, 'Expired'),
      'failed' => (AppColors.dangerTint, AppColors.danger, Icons.error_outline_rounded, 'Failed'),
      _ => (AppColors.primaryTint, AppColors.primary, Icons.info_outline_rounded, 'Pending'),
    };
  }
}

/// Compact benefit item with icon and descriptive text.
class MembershipBenefitItem extends StatelessWidget {
  const MembershipBenefitItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.included = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool included;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: included ? AppColors.primaryTint : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 15,
              color: included ? AppColors.primary : AppColors.inkSoft,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkSoft,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact, premium card displaying current membership status, expiry, and key actions.
/// Designed for a height between ~220–280dp at ~393px width.
class MembershipStatusCard extends StatelessWidget {
  const MembershipStatusCard({
    super.key,
    required this.entitlement,
    required this.onPrimaryAction,
    this.onUpgradeAction,
    this.scheduledUpgrade,
    this.badgeText,
  });

  final MembershipEntitlement entitlement;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onUpgradeAction;
  final Map<String, dynamic>? scheduledUpgrade;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final paid = entitlement.paidStatus == PaidMembershipStatus.active;
    final expired = entitlement.paidStatus == PaidMembershipStatus.expired;
    final verified = entitlement.canStartCheckout;
    final tier = entitlement.effectiveTier?.label;

    final title = !entitlement.isResolved
        ? 'Verification required'
        : entitlement.historicalOnly
            ? 'Last verified tier · $tier'
            : expired
                ? 'Membership Expired'
                : '$tier Membership';

    final primaryActionLabel = !verified
        ? 'Verify Membership'
        : expired
            ? 'Renew Membership'
            : paid
                ? 'Renew ${entitlement.paidTier!.label}'
                : 'Explore Membership Plans';

    final statusText = !entitlement.isResolved
        ? 'Connect to verify your paid membership.'
        : expired
            ? 'Your paid membership has expired. Digital fitness remains yours.'
            : entitlement.historicalOnly
                ? 'Historical record · Refresh online before using paid benefits.'
                : paid
                    ? 'Paid membership active'
                    : 'Full digital fitness, always free.';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: paid ? AppColors.primarySoft.withValues(alpha: 0.35) : AppColors.hairline,
          width: paid ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: paid
                ? AppColors.primary.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top row: GainPath identifier + Compact status indicator
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: 5),
                        child: Icon(Icons.workspace_premium_rounded,
                            size: 15, color: AppColors.primary),
                      ),
                    ),
                    TextSpan(
                      text: paid ? 'GYM MEMBERSHIP' : 'GAINPATH',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              PaymentStatusIndicator(
                status: paid ? 'cleared' : (expired ? 'expired' : 'active'),
                label: paid ? 'Active' : (expired ? 'Expired' : 'Free Tier'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Title: Basic Membership
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(height: 4),

          // 3. Compact Status & Expiry lines
          Text(
            statusText,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
          ),
          if (entitlement.paidExpiresAtMillis != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  expired ? Icons.error_outline_rounded : Icons.schedule_rounded,
                  size: 15,
                  color: expired ? AppColors.danger : AppColors.inkSoft,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${expired ? 'Expired' : entitlement.historicalOnly ? 'Last recorded expiry' : 'Valid until'} ${membershipDate(entitlement.paidExpiresAtMillis)}',
                    style: TextStyle(
                      color: expired ? AppColors.danger : AppColors.inkSoft,
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!paid && !expired && entitlement.isResolved) ...[
            const SizedBox(height: 4),
            const Text(
              'No expiry · No membership charge',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5),
            ),
          ],

          // 4. Scheduled upgrade banner if applicable
          if (scheduledUpgrade != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primarySoft.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium scheduled',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Starts ${membershipDate(scheduledUpgrade!['startsAtMillis'])}',
                          style: const TextStyle(fontSize: 12, color: AppColors.ink, height: 1.25),
                        ),
                        Text(
                          'Expires ${membershipDate(scheduledUpgrade!['expiresAtMillis'])}',
                          style: const TextStyle(fontSize: 12, color: AppColors.ink, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 5. Actions (Primary Renew + Secondary Upgrade)
          if (scheduledUpgrade == null) ...[
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              // Phones in portrait (320px–430px) have constraints.maxWidth < 460.
              // Stacking full-width buttons guarantees "Renew Basic" and "Upgrade to Premium"
              // are 100% visible, fully readable, accessible (>=48dp touch targets),
              // and free of ellipsis truncation on all devices and text scales.
              final isNarrow = constraints.maxWidth < 460;
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final stack = isNarrow || textScale > 1.15 || onUpgradeAction == null;

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton(
                        onPressed: onPrimaryAction,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        child: Text(
                          primaryActionLabel,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    if (onUpgradeAction != null) ...[
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: OutlinedButton.icon(
                          onPressed: onUpgradeAction,
                          icon: const Icon(Icons.bolt_rounded, size: 18),
                          label: const Text(
                            'Upgrade to Premium',
                            textAlign: TextAlign.center,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }

              // Horizontal action layout for wide viewports (landscape, tablet: maxWidth >= 460)
              return Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton(
                        onPressed: onPrimaryAction,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                        child: Text(primaryActionLabel, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: OutlinedButton.icon(
                        onPressed: onUpgradeAction,
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text('Upgrade to Premium', textAlign: TextAlign.center),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'No automatic renewal or recurring charge.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Concise 2-column icon grid showing membership entitlements.
class MembershipBenefitsGrid extends StatelessWidget {
  const MembershipBenefitsGrid({
    super.key,
    required this.entitlement,
  });

  final MembershipEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final paid = entitlement.paidStatus == PaidMembershipStatus.active;
    final isPremium = paid && entitlement.effectiveTier == MembershipTier.premium;

    final List<({IconData icon, String title})> items = (paid && !entitlement.historicalOnly)
        ? [
            (
              icon: Icons.fitness_center_rounded,
              title: 'Gym Entry',
            ),
            (
              icon: Icons.sports_rounded,
              title: isPremium ? 'VIP Coaching' : 'Coach Booking',
            ),
            (
              icon: Icons.sports_esports_rounded,
              title: 'Mini-Games',
            ),
            (
              icon: Icons.card_giftcard_rounded,
              title: isPremium ? 'Exclusive Rewards' : 'Physical Rewards',
            ),
          ]
        : [
            (
              icon: Icons.fitness_center_rounded,
              title: 'AI Workouts',
            ),
            (
              icon: Icons.menu_book_rounded,
              title: 'Video Tutorials',
            ),
            (
              icon: Icons.assignment_rounded,
              title: 'Training Plans',
            ),
            (
              icon: Icons.analytics_rounded,
              title: 'Workout History',
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                paid && !entitlement.historicalOnly
                    ? Icons.verified_rounded
                    : Icons.fitness_center_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  paid && !entitlement.historicalOnly
                      ? 'Included with ${entitlement.effectiveTier!.label}'
                      : 'Included with Digital Fitness',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            paid && !entitlement.historicalOnly
                ? 'Gym entry, coach booking & rewards included.'
                : 'AI workouts, tutorials, plans & history stay free.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.35),
          ),
          const SizedBox(height: 14),
          // Responsive 2x2 benefits grid
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 280;
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final singleColumn = isNarrow || textScale > 1.35;

            if (singleColumn) {
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _BenefitGridTile(icon: items[i].icon, title: items[i].title),
                  ],
                ],
              );
            }

            return Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _BenefitGridTile(
                          icon: items[0].icon,
                          title: items[0].title,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BenefitGridTile(
                          icon: items[1].icon,
                          title: items[1].title,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _BenefitGridTile(
                          icon: items[2].icon,
                          title: items[2].title,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BenefitGridTile(
                          icon: items[3].icon,
                          title: items[3].title,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 10),
          const Text(
            'Wallet points stay safe · Physical rewards require Basic or Premium.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.inkSoft,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitGridTile extends StatelessWidget {
  const _BenefitGridTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Structured order pricing summary with coupon and total breakdown.
class PricingSummaryCard extends StatelessWidget {
  const PricingSummaryCard({
    super.key,
    required this.durationDays,
    required this.totalAmountMinor,
    this.baseAmountMinor,
    this.promoCode,
    this.discountMinor,
    this.proratedChargeMinor,
  });

  final int durationDays;
  final num totalAmountMinor;
  final num? baseAmountMinor;
  final String? promoCode;
  final num? discountMinor;
  final num? proratedChargeMinor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 10),
          DetailRow('Duration', '$durationDays days'),
          if (baseAmountMinor != null)
            DetailRow('Original price', membershipMoney(baseAmountMinor)),
          if (promoCode != null && promoCode!.isNotEmpty)
            DetailRow('Promo code', promoCode!),
          if (discountMinor != null && discountMinor! > 0)
            DetailRow('Discount', '- ${membershipMoney(discountMinor)}'),
          if (proratedChargeMinor != null)
            DetailRow('Prorated adjustment', membershipMoney(proratedChargeMinor)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.hairline, height: 1),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                'Total to pay',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                membershipMoney(totalAmountMinor),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Transaction card with inline actions for payment details, receipts, and refunds.
class BillingTransactionTile extends StatelessWidget {
  const BillingTransactionTile({
    super.key,
    Map<String, dynamic>? row,
    Map<String, dynamic>? payment,
    VoidCallback? onTapDetails,
    VoidCallback? onOpenDetails,
    this.serverNowMillis,
    this.onViewReceipt,
    this.onRequestRefund,
  })  : row = row ?? payment ?? const {},
        onTapDetails = onTapDetails ?? onOpenDetails;

  final Map<String, dynamic> row;
  final int? serverNowMillis;
  final VoidCallback? onTapDetails;
  final VoidCallback? onViewReceipt;
  final VoidCallback? onRequestRefund;

  @override
  Widget build(BuildContext context) {
    final planName = row['planName'] as String? ?? 'Membership';
    final amount = membershipMoney(row['amountMinor']);
    final date = membershipDate(row['createdAtMillis']);
    final paymentStatus = row['paymentStatus'] as String?;
    final fulfilment = row['fulfilmentStatus'] as String?;
    final deadline = row['checkoutExpiresAtMillis'];
    final now = serverNowMillis;
    final needsCheck = paymentStatus == 'pending' &&
        (fulfilment == 'awaiting_payment' || fulfilment == 'creating') &&
        deadline is int && now != null && deadline <= now;
    final status = needsCheck ? 'check_payment_status' : fulfilment ?? paymentStatus;
    final refund = row['refundStatus'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  planName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              PaymentStatusIndicator(status: status, refundStatus: refund),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: onTapDetails,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.inkSoft,
                ),
                child: const Text('Details'),
              ),
              if (onViewReceipt != null) ...[
                TextButton.icon(
                  onPressed: onViewReceipt,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Receipt'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
              if (onRequestRefund != null) ...[
                TextButton(
                  onPressed: onRequestRefund,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text('Refund'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
