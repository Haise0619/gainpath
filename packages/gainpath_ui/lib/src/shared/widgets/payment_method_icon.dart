import 'package:flutter/material.dart';

/// Branded placeholder slots, not official logos. Body labels remain accessible.
class PaymentMethodIcon extends StatelessWidget {
  const PaymentMethodIcon({super.key, required this.iconKey, this.size = 42});
  final String iconKey;
  final double size;
  @override
  Widget build(BuildContext context) {
    final (mark, color, foreground) = switch (iconKey) {
      'maybank' => ('M', const Color(0xFFFFD539), const Color(0xFF222222)),
      'cimb' => ('C', const Color(0xFFC8172B), Colors.white),
      'public_bank' => ('PB', const Color(0xFFD52938), Colors.white),
      'rhb' => ('RHB', const Color(0xFF0876B9), Colors.white),
      'hong_leong' => ('HL', const Color(0xFF143B7E), Colors.white),
      'bank_islam' => ('BI', const Color(0xFF9D1946), Colors.white),
      'tng' => ('TnG', const Color(0xFF086DCE), Colors.white),
      'grabpay' => ('G', const Color(0xFF078C43), Colors.white),
      'shopeepay' => ('S', const Color(0xFFDF502C), Colors.white),
      'visa_mastercard' => ('VISA\nMC', const Color(0xFF253559), Colors.white),
      _ => ('', const Color(0xFFEDE7FB), const Color(0xFF6D28D9)),
    };
    return ExcludeSemantics(
        child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(12)),
            child: mark.isEmpty
                ? Icon(Icons.account_balance_outlined,
                    size: size * .5, color: foreground)
                : Text(mark,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                        color: foreground,
                        fontFamily: 'Barlow',
                        fontWeight: FontWeight.w700,
                        fontSize: mark.length > 3
                            ? size * .23
                            : mark.length > 2
                                ? size * .29
                                : size * .4,
                        height: 1))));
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
