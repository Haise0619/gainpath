/// SD-M4.1 — promo code validation for a membership purchase.
class PromoPolicy {
  const PromoPolicy();

  static const codes = <String, double>{'GAINPATH10': 0.10};

  /// Discount fraction for [code] (case-insensitive), or null when invalid.
  double? discountFor(String code) => codes[code.trim().toUpperCase()];
}
