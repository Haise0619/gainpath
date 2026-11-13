import 'package:flutter/material.dart';

import '../../tokens/app_theme.dart';

/// Neutral symbols for payment preferences when checkout marks are unavailable.
class PaymentMethodIcon extends StatelessWidget {
  const PaymentMethodIcon({super.key, required this.iconKey, this.size = 42});

  final String iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (iconKey) {
      'tng' ||
      'grabpay' ||
      'shopeepay' =>
        Icons.account_balance_wallet_outlined,
      'visa_mastercard' => Icons.credit_card_outlined,
      'unknown' => Icons.payments_outlined,
      _ => Icons.account_balance_outlined,
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, size: size * .62, color: AppColors.inkSoft),
      ),
    );
  }
}

class PaymentMethodSummary extends StatelessWidget {
  const PaymentMethodSummary(
      {super.key,
      required this.label,
      required this.category,
      required this.iconKey});
  final String label, category, iconKey;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        PaymentMethodIcon(iconKey: iconKey),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(category, style: Theme.of(context).textTheme.bodyMedium)
        ]))
      ]);
}
