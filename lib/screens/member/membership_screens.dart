import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M4.2 — View Membership Dashboard.
class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CURRENT PLAN',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70)),
                const SizedBox(height: 6),
                const Text('Premium',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1)),
                const SizedBox(height: 4),
                const Text('RM 89 per month  ·  renews 12 Oct',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RenewScreen())),
                        child: const Text('Renew now'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        onPressed: () => confirmSheet(context,
                            title: 'Turn off auto-renewal?',
                            message:
                                'You keep full access until 12 Oct. After that your plan will not renew automatically.',
                            confirmLabel: 'Turn off',
                            destructive: true),
                        child: const Text('Auto-renew'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Plans'),
          ...MockData.membershipPlans.map((p) {
            final current = p[0] == 'Premium';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                background: current ? AppColors.primaryTint : null,
                onTap: current
                    ? null
                    : () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => PurchasePlanScreen(plan: p))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(p[0],
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium),
                              if (current) ...[
                                const SizedBox(width: 8),
                                statusPill('Current'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(p[2],
                              style: Theme.of(context).textTheme.bodyMedium),
                          if (!current) ...[
                            const SizedBox(height: 6),
                            Text('Switch to this plan',
                                style: TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(p[1],
                            style: Theme.of(context).textTheme.titleLarge),
                        if (!current)
                          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.inkSoft),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          const Eyebrow('Billing history'),
          ...MockData.transactions.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.type,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text('${t.id}  ·  ${_date(t.date)}',
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('RM ${t.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          statusPill(t.status),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, size: 19),
                        tooltip: 'Download invoice',
                        onPressed: () =>
                            showToast(context, 'Invoice saved to your device.'),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RefundRequestScreen())),
            icon: const Icon(Icons.receipt_long_rounded, size: 19),
            label: const Text('Request a refund'),
          ),
        ],
      ),
    );
  }

  String _date(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

/// AD-M4.1 — Purchase Membership Plan (first-time / plan switch).
class PurchasePlanScreen extends StatefulWidget {
  final List<String> plan;
  const PurchasePlanScreen({super.key, required this.plan});

  @override
  State<PurchasePlanScreen> createState() => _PurchasePlanScreenState();
}

class _PurchasePlanScreenState extends State<PurchasePlanScreen> {
  final _promo = TextEditingController();
  String? _promoError;
  bool _applying = false;
  double? _discountPct;

  double get _basePrice => double.parse(widget.plan[1].replaceAll('RM ', '').trim());
  double get _total => _discountPct == null ? _basePrice : _basePrice * (1 - _discountPct!);

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final code = _promo.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _promoError = 'Enter a code first.');
      return;
    }
    setState(() {
      _applying = true;
      _promoError = null;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _applying = false;
      if (code == 'GAINPATH10') {
        _discountPct = 0.10;
      } else {
        _discountPct = null;
        _promoError = 'Invalid or expired code.';
      }
    });
  }

  Future<void> _pay() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationScreen(planName: widget.plan[0], amountPaid: _total),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discounted = _discountPct != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm your plan')),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.primaryTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.plan[0], style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(widget.plan[2], style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                Text('RM ${_basePrice.toStringAsFixed(0)} / month',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Promo code'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _promo,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) {
                    if (_promoError != null) setState(() => _promoError = null);
                  },
                  decoration: InputDecoration(hintText: 'Have a code?', errorText: _promoError),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _applying ? null : _applyPromo,
                  child: _applying
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                      : const Text('Apply'),
                ),
              ),
            ],
          ),
          if (discounted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('${(_discountPct! * 100).round()}% off applied',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Panel(
            child: Column(
              children: [
                DetailRow('Plan', widget.plan[0]),
                const Divider(height: 20),
                if (discounted) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: Theme.of(context).textTheme.bodyMedium),
                      Text('RM ${_basePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 14, decoration: TextDecoration.lineThrough, color: AppColors.inkSoft)),
                    ],
                  ),
                  const Divider(height: 20),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total due today', style: Theme.of(context).textTheme.titleMedium),
                    Text('RM ${_total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payment is handled on the provider\'s secure page. GainPath never sees or stores your card details.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _pay,
            child: Text('Pay RM ${_total.toStringAsFixed(2)}'),
          ),
        ],
      ),
    );
  }
}

class PaymentConfirmationScreen extends StatelessWidget {
  final String planName;
  final double amountPaid;
  const PaymentConfirmationScreen({super.key, required this.planName, required this.amountPaid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment confirmed'), automaticallyImplyLeading: false),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.primaryTint,
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, size: 44, color: AppColors.primary),
                const SizedBox(height: 12),
                Text('You are on $planName now', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Your new tier is active immediately.', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              children: [
                DetailRow('Plan', planName),
                const Divider(height: 20),
                DetailRow('Amount paid', 'RM ${amountPaid.toStringAsFixed(2)}'),
                const Divider(height: 20),
                const DetailRow('Billing cycle', 'Monthly'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// AD-M4.3 — Renew Membership Subscription.
class RenewScreen extends StatelessWidget {
  const RenewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Renew membership')),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              children: const [
                DetailRow('Plan', 'Premium'),
                Divider(height: 20),
                DetailRow('Period', '1 month'),
                Divider(height: 20),
                DetailRow('New expiry', '12 Nov 2026'),
                Divider(height: 20),
                DetailRow('Total', 'RM 89.00'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payment is handled on the provider\'s secure page. GainPath never '
                    'sees or stores your card details.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
              await Future.delayed(const Duration(milliseconds: 1400));
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
              showToast(context, 'Membership renewed until 12 Nov.');
            },
            child: const Text('Pay RM 89.00'),
          ),
        ],
      ),
    );
  }
}

/// AD-M4.4 — Request Refund.
class RefundRequestScreen extends StatefulWidget {
  const RefundRequestScreen({super.key});

  @override
  State<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends State<RefundRequestScreen> {
  String? _transaction;
  String? _reason;

  final _reasons = const [
    'Coach cancelled the session',
    'Charged twice for the same item',
    'Charged after cancelling',
    'Something else',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request a refund')),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Refunds can be requested within 7 days of a charge. Staff review '
                    'each request before any money is returned.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Which charge?'),
          ...MockData.transactions.take(2).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  onTap: () => setState(() => _transaction = t.id),
                  background:
                      _transaction == t.id ? AppColors.primaryTint : null,
                  child: Row(
                    children: [
                      Icon(
                          _transaction == t.id
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: _transaction == t.id
                              ? AppColors.primary
                              : AppColors.hairline),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.type,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text(t.id,
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      Text('RM ${t.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 14),
          const Eyebrow('Why?'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: _reasons
                  .map((r) => RadioListTile<String>(
                        value: r,
                        groupValue: _reason,
                        onChanged: (v) => setState(() => _reason = v),
                        title: Text(r,
                            style: const TextStyle(fontSize: 14.5)),
                        dense: true,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          const TextField(
            maxLines: 4,
            decoration:
                InputDecoration(hintText: 'Add any details that would help'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: (_transaction == null || _reason == null)
                ? null
                : () {
                    Navigator.pop(context);
                    showToast(context,
                        'Request submitted. We will email you once it is reviewed.');
                  },
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
  }
}
