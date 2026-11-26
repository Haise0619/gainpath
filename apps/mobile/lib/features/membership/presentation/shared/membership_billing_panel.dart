import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/membership_billing_repository.dart';
import '../member/purchase_plan_screen.dart';
import 'membership_data_view.dart';

class MembershipBillingPanel extends StatefulWidget {
  const MembershipBillingPanel({
    super.key,
    required this.repository,
    required this.billingRepository,
    required this.data,
    required this.refresh,
  });
  final MembershipCommerceRepository repository;
  final MembershipBillingRepository billingRepository;
  final Map<String, dynamic> data;
  final VoidCallback refresh;

  @override
  State<MembershipBillingPanel> createState() => _MembershipBillingPanelState();
}

class _MembershipBillingPanelState extends State<MembershipBillingPanel> {
  bool _busy = false;
  String? _requestId;
  String? _requestBillId;
  String? _error;

  Future<void> _pay(String id, String plan) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_requestBillId != id) {
        _requestBillId = id;
        _requestId = 'billing-${DateTime.now().microsecondsSinceEpoch}';
      }
      final payment =
          await widget.billingRepository.payRenewalBill(id, plan, _requestId!);
      if (!mounted || !widget.repository.current) return;
      if (payment['billingId'] != id) {
        setState(() => _error =
            'Another membership checkout is open. Check Billing History before paying again.');
        return;
      }
      await Navigator.push<void>(
          context,
          MaterialPageRoute(
              builder: (_) => MembershipPaymentScreen(
                  repository: widget.repository,
                  initial: payment,
                  openOnStart: true)));
      if (mounted) widget.refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Checkout could not be confirmed. Refresh or retry this bill.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel renewal?'),
        content: const Text(
            'Future renewal billing will stop. Paid access stays available until your current expiry.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep renewal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel renewal')),
        ],
      ),
    );
    if (agreed != true || !mounted || _busy || !widget.repository.current) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.billingRepository.cancelRenewal();
      if (mounted) widget.refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Cancellation could not be confirmed. Refresh and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billing = widget.data['billing'];
    if (billing is! Map) return const SizedBox.shrink();
    final state = billing['status'];
    final due = state == 'payment_due' || state == 'past_due';
    final cancelled = state == 'cancelled';
    final id = billing['id'];
    final plan = billing['planId'];
    final disabled = _busy || widget.data['cached'] == true;
    final label = switch (state) {
      'payment_due' => 'Payment Due',
      'past_due' => 'Past Due',
      'paid' => 'Paid',
      'cancelled' => 'Renewal cancelled',
      _ => 'Active',
    };
    final (Color badgeBg, Color badgeFg, IconData badgeIcon) = switch (state) {
      'payment_due' => (
          const Color(0xFFFFF7ED),
          const Color(0xFFC2410C),
          Icons.schedule_rounded,
        ),
      'past_due' => (
          const Color(0xFFFEF2F2),
          const Color(0xFFDC2626),
          Icons.warning_amber_rounded,
        ),
      'paid' => (
          const Color(0xFFF0FDF4),
          const Color(0xFF16A34A),
          Icons.check_circle_rounded,
        ),
      'cancelled' => (
          AppColors.membershipFreeTint,
          AppColors.membershipFreeInk,
          Icons.cancel_outlined,
        ),
      _ => (
          AppColors.primaryTint,
          AppColors.primary,
          Icons.verified_rounded,
        ),
    };

    final amountMinor = billing['amountMinor'];
    final dueAtMillis = billing['dueAtMillis'];
    final graceEndsAtMillis = billing['graceEndsAtMillis'];
    final hasGrace = state == 'payment_due' && graceEndsAtMillis is int;
    final helperNote = cancelled
        ? 'Future billing stopped · Access remains until expiry'
        : due
            ? 'Manual renewal · Pay to activate next 30 days'
            : 'Manual 30-day billing · No automatic charge';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: due
              ? AppColors.primarySoft.withValues(alpha: 0.45)
              : AppColors.hairline,
          width: due ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: due
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Section Icon + Title + Semantic Status Badge
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Membership billing',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.ink,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: badgeFg.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 13, color: badgeFg),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: badgeFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Hero Amount
          if (amountMinor is int) ...[
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: due ? 'Amount due: ' : 'Next renewal: ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  TextSpan(
                    text: membershipMoney(amountMinor),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const TextSpan(
                    text: ' · 30 days',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Structured Date & Grace Period Card (Eliminating text heaviness)
          if (dueAtMillis is int || hasGrace) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F8FD),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.hairline.withValues(alpha: 0.8),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 320;
                  final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                  final stack = isNarrow || textScale > 1.15 || !hasGrace || dueAtMillis is! int;

                  if (stack) {
                    return Column(
                      children: [
                        if (dueAtMillis is int)
                          _FactRow(
                            icon: Icons.event_outlined,
                            label: 'Due date',
                            value: membershipDate(dueAtMillis),
                          ),
                        if (dueAtMillis is int && hasGrace)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Divider(height: 1, color: AppColors.hairline),
                          ),
                        if (hasGrace)
                          _FactRow(
                            icon: Icons.hourglass_bottom_rounded,
                            label: 'Grace ends',
                            value: membershipDate(graceEndsAtMillis),
                            valueColor: const Color(0xFFC2410C),
                          ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.event_outlined,
                                    size: 13, color: AppColors.inkSoft),
                                SizedBox(width: 4),
                                Text(
                                  'DUE DATE',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              membershipDate(dueAtMillis),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 34,
                        color: AppColors.hairline,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.hourglass_bottom_rounded,
                                    size: 13, color: Color(0xFFEA580C)),
                                SizedBox(width: 4),
                                Text(
                                  'GRACE PERIOD',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: Color(0xFFC2410C),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              membershipDate(graceEndsAtMillis),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFC2410C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          // Concise 1-line helper note
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  helperNote,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),

          // Primary Pay Now Action
          if (due && id is String && plan is String) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 1,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
                onPressed: disabled ? null : () => _pay(id, plan),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pay Now',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],

          // Secondary Cancel Renewal Action
          if (billing['nextRenewal'] == true) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  foregroundColor: AppColors.inkSoft,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: disabled ? null : _cancel,
                child: const Text('Cancel Renewal'),
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13.5, color: valueColor ?? AppColors.inkSoft),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
