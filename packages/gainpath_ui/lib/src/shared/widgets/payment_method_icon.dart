import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../tokens/app_theme.dart';

/// Bundled payment preference marks with a neutral fallback.
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
    final asset = switch (iconKey) {
      'maybank' ||
      'cimb' ||
      'tng' ||
      'grabpay' ||
      'shopeepay' =>
        '$iconKey.svg',
      'public_bank' ||
      'rhb' ||
      'bank_islam' ||
      'affin' ||
      'alliance' ||
      'ambank' ||
      'bsn' =>
        '$iconKey.png',
      _ => null,
    };
    final fallback = Icon(icon, size: size * .62, color: AppColors.inkSoft);
    return ExcludeSemantics(
      child: SizedBox(
        width: size * 1.6,
        height: size,
        child: switch (iconKey) {
          'visa_mastercard' => Row(
              children: [
                Expanded(child: _mark('visa.svg', fallback)),
                const SizedBox(width: 3),
                Expanded(child: _mark('mastercard.svg', fallback)),
              ],
            ),
          _ => asset == null ? fallback : _mark(asset, fallback),
        },
      ),
    );
  }

  Widget _mark(String asset, Widget fallback) {
    const package = 'gainpath_ui';
    final path = 'assets/payment/$asset';
    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(path,
          package: package,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => fallback);
    }
    return Image.asset(
      path,
      package: package,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => fallback,
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
