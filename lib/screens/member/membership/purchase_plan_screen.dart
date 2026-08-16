import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/billplz_checkout_screen.dart';
import '../../../widgets/shared.dart';
import 'payment_confirmation_screen.dart';

/// AD-M4.1 — Purchase Membership Plan (checkout step): pricing summary,
/// a promo-code loop, and a simulated Billplz-style checkout — first-time
/// purchase and plan switches both land here.
class PurchasePlanScreen extends StatefulWidget {
  final MembershipPlan plan;
  const PurchasePlanScreen({super.key, required this.plan});

  @override
  State<PurchasePlanScreen> createState() => _PurchasePlanScreenState();
}

class _PurchasePlanScreenState extends State<PurchasePlanScreen> {
  final _promo = TextEditingController();
  String? _promoError;
  bool _applying = false;
  double? _discountPct;

  double get _total => _discountPct == null ? widget.plan.price : widget.plan.price * (1 - _discountPct!);

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
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BillplzCheckoutScreen(amount: _total, description: '${widget.plan.name} membership'),
      ),
    );
    if (success != true || !mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationScreen(planName: widget.plan.name, amountPaid: _total),
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
                Text(widget.plan.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(widget.plan.tagline, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                Text('RM ${widget.plan.price.toStringAsFixed(0)} / month',
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
                DetailRow('Plan', widget.plan.name),
                const Divider(height: 20),
                if (discounted) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal', style: Theme.of(context).textTheme.bodyMedium),
                      Text('RM ${widget.plan.price.toStringAsFixed(2)}',
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
