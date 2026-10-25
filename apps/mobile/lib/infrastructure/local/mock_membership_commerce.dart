import 'package:gainpath_domain/membership.dart';
import '../../features/membership/domain/membership_payment_preview.dart';

/// Existing mock catalogue only. Never instantiated for a Firebase session.
class MockMembershipCommerce
    implements MembershipCommerceRepository, MembershipPaymentPreview {
  MockMembershipCommerce._(this.source);
  static final _instances = Expando<MockMembershipCommerce>();
  static MockMembershipCommerce forRepository(MembershipRepository source) =>
      _instances[source] ??= MockMembershipCommerce._(source);
  final MembershipRepository source;
  final List<Map<String, dynamic>> _payments = [];
  int _expiry = 0;
  @override
  bool get sandbox => false;
  @override
  bool get current => true;
  @override
  Future<Map<String, dynamic>> load() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final paid = _expiry > 0;
    final active = _expiry > now;
    final current = source.membershipPlans
        .where((p) => p.id == source.currentPlanId)
        .firstOrNull;
    return {
      'organizationId': 'mock-gainpath',
      'memberId': 'mock-member',
      'serverNowMillis': now,
      'entitlement': {
        'schemaVersion': 1,
        'policyVersion': 'gainpath-effective-membership-v1',
        'organizationId': 'mock-gainpath',
        'memberId': 'mock-member',
        'resolvedAtMillis': now,
        'status': 'resolved',
        'effectiveTier': active ? source.currentPlanId : 'free',
        'paidTier': paid ? source.currentPlanId : null,
        'paidPlanId': paid ? source.currentPlanId : null,
        'paidPlanName': paid ? current?.name : null,
        'paidStatus': paid
            ? active
                ? 'active'
                : 'expired'
            : 'none',
        'paidExpiresAtMillis': paid ? _expiry : null,
        'benefits': active ? current?.perks ?? <String>[] : <String>[],
        'reason': paid
            ? active
                ? 'active_paid_membership'
                : 'paid_membership_expired'
            : 'no_paid_membership',
      },
      'account': {
        'planId': source.currentPlanId,
        'planName': source.membershipPlans
                .where((p) => p.id == source.currentPlanId)
                .firstOrNull
                ?.name ??
            '',
        'expiresAtMillis': _expiry,
        'status':
            _expiry > DateTime.now().millisecondsSinceEpoch ? 'active' : 'none'
      },
      'plans': source.membershipPlans
          .where((p) => ['basic', 'premium'].contains(p.id))
          .map((p) => {
                'planId': p.id,
                'name': p.name,
                'amountMinor': (p.price * 100).round(),
                'durationDays': 30,
                'benefits': p.perks,
                'currency': 'MYR'
              })
          .toList(),
      'transactions': List.of(_payments),
      'autoRenewSupported': false
    };
  }

  @override
  Future<Map<String, dynamic>> quote(String planId, String promoCode) async {
    if (!['basic', 'premium'].contains(planId)) {
      throw StateError('Choose a configured paid plan.');
    }
    final p = source.membershipPlans.firstWhere((p) => p.id == planId);
    final discount =
        promoCode.isEmpty ? 0.0 : const PromoPolicy().discountFor(promoCode);
    if (discount == null) throw StateError('Invalid mock promo code.');
    return {
      'planId': p.id,
      'amountMinor': (p.price * 100 * (1 - discount)).round(),
      'durationDays': 30
    };
  }

  @override
  Future<Map<String, dynamic>> checkout(
      String planId, String promoCode, String requestId,
      {required bool renewal, String? quoteId}) async {
    final old =
        _payments.where((p) => p['transactionId'] == requestId).firstOrNull;
    if (old != null) return old;
    final q = await quote(planId, promoCode);
    final p = {
      'transactionId': requestId,
      'planId': planId,
      'planName': source.membershipPlans.firstWhere((p) => p.id == planId).name,
      'amountMinor': q['amountMinor'],
      'kind': renewal ? 'MembershipRenewal' : 'MembershipPurchase',
      'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
      'paymentStatus': 'pending',
      'fulfilmentStatus': 'awaiting_payment'
    };
    _payments.insert(0, p);
    return p;
  }

  @override
  Future<Map<String, dynamic>> payment(String transactionId) async =>
      _payments.firstWhere((p) => p['transactionId'] == transactionId);
  @override
  Future<void> simulate(String transactionId) async {
    final p = await payment(transactionId);
    if (p['paymentStatus'] == 'cleared') return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _expiry = (_expiry > now ? _expiry : now) + 30 * 86400000;
    source.currentPlanId = p['planId'] as String;
    p.addAll({
      'paymentStatus': 'cleared',
      'fulfilmentStatus': 'confirmed',
      'expiresAtMillis': _expiry,
      'clearedAtMillis': now
    });
  }

  @override
  Future<Map<String, dynamic>> refund(
      String transactionId, String reason, String notes) async {
    final p = await payment(transactionId);
    if (p['paymentStatus'] != 'cleared') {
      throw StateError('Cleared payment required.');
    }
    p['refundStatus'] = 'pending_review';
    return p;
  }
}
