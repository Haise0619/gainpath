import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../widgets/shared.dart';

/// Terminal state of the purchase/plan-switch flow.
class PaymentConfirmationScreen extends StatefulWidget {
  final String planName;
  final double amountPaid;
  const PaymentConfirmationScreen({super.key, required this.planName, required this.amountPaid});

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.05), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOut));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment confirmed'), automaticallyImplyLeading: false),
      body: PageBody(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text('You are on ${widget.planName} now',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Your new tier is active immediately.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              children: [
                DetailRow('Plan', widget.planName),
                const Divider(height: 20),
                DetailRow('Amount paid', 'RM ${widget.amountPaid.toStringAsFixed(2)}'),
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
