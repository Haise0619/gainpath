import 'package:gainpath_domain/membership.dart';

/// Display-only projection from the verified overview. Settlement determines
/// the actual expiry using its own authoritative time and account state.
class MembershipRenewalPreview {
  const MembershipRenewalPreview._(this.tier, this.expiryMillis, this.asOfMillis);

  final MembershipTier tier;
  final int expiryMillis;
  final int asOfMillis;

  static MembershipRenewalPreview? fromOverview(
      MembershipEntitlement entitlement, String selectedPlanId) {
    final tier = entitlement.paidTier;
    final expiry = entitlement.paidExpiresAtMillis;
    final now = entitlement.resolvedAtMillis;
    if (!entitlement.canStartCheckout || tier == null || expiry == null ||
        now == null || entitlement.paidPlanId != selectedPlanId) {
      return null;
    }
    return MembershipRenewalPreview._(tier, expiry, now);
  }

  bool get active => expiryMillis > asOfMillis;

  int? estimatedExpiry(Object? durationDays) {
    if (durationDays != 30) return null;
    final baseline = active ? expiryMillis : asOfMillis;
    final estimate = baseline + const Duration(days: 30).inMilliseconds;
    return estimate <= 8640000000000000 ? estimate : null;
  }
}
