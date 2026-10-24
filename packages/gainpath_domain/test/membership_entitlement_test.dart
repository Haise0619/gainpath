import 'package:test/test.dart';
import 'package:gainpath_domain/membership.dart';

Map<String, dynamic> snapshot(
        {String effective = 'free', String paid = 'none', int? expiry}) =>
    {
      'schemaVersion': 1,
      'policyVersion': 'gainpath-effective-membership-v1',
      'organizationId': 'gainpath',
      'memberId': 'member',
      'resolvedAtMillis': 1800000000000,
      'status': 'resolved',
      'effectiveTier': effective,
      'paidTier': paid == 'none' ? null : 'premium',
      'paidPlanId': paid == 'none' ? null : 'premium',
      'paidPlanName': paid == 'none' ? null : 'Premium',
      'paidStatus': paid,
      'paidExpiresAtMillis': expiry,
      'benefits': paid == 'active' ? ['Configured benefit'] : [],
      'reason': 'test',
    };
void main() {
  test('Free is a non-expiring derived entitlement, not a paid plan', () {
    final e = MembershipEntitlement.fromJson(snapshot());
    expect(e.effectiveTier, MembershipTier.free);
    expect(e.paidPlanId, isNull);
    expect(e.paidExpiresAtMillis, isNull);
    expect(e.canStartCheckout, isTrue);
  });
  test(
      'paid-to-Free projection retains the previous expiry and is server-resolved',
      () {
    final e = MembershipEntitlement.fromJson(
        snapshot(paid: 'expired', expiry: 1800000000000));
    expect(e.effectiveTier, MembershipTier.free);
    expect(e.paidTier, MembershipTier.premium);
    expect(e.paidStatus, PaidMembershipStatus.expired);
    expect(e.paidExpiresAtMillis, 1800000000000);
  });
  test('cached paid projection is display only and cannot start checkout', () {
    final e = MembershipEntitlement.fromOverview({
      'cached': true,
      'entitlement':
          snapshot(effective: 'premium', paid: 'active', expiry: 1800000000001)
    });
    expect(e.effectiveTier, MembershipTier.premium);
    expect(e.historicalOnly, isTrue);
    expect(e.canStartCheckout, isFalse);
  });
  test('legacy or malformed response cannot become Free', () {
    for (final data in [
      {
        'account': {'status': 'none'}
      },
      {
        'entitlement': {...snapshot(), 'effectiveTier': 'elite'}
      },
      {
        'entitlement': {...snapshot(), 'paidStatus': 'active'}
      }
    ]) {
      final e = MembershipEntitlement.fromOverview(data);
      expect(e.effectiveTier, isNull);
      expect(e.isResolved, isFalse);
      expect(e.canStartCheckout, isFalse);
    }
  });
  test(
      'validates identity, policy, server boundary and active/expired consistency',
      () {
    expect(
        () => MembershipEntitlement.fromJson({...snapshot(), 'memberId': ''}),
        throwsFormatException);
    expect(
        () => MembershipEntitlement.fromJson(
            {...snapshot(), 'policyVersion': 'other'}),
        throwsFormatException);
    expect(
        () => MembershipEntitlement.fromJson(snapshot(
            effective: 'premium', paid: 'active', expiry: 1800000000000)),
        throwsFormatException);
    expect(
        () => MembershipEntitlement.fromJson(
            snapshot(paid: 'expired', expiry: 1800000000001)),
        throwsFormatException);
    expect(
        () => MembershipEntitlement.fromJson(snapshot(),
            expectedMemberId: 'other'),
        throwsFormatException);
  });
  test('unknown remains distinct from Free and retains limited paid facts', () {
    final e = MembershipEntitlement.fromJson({
      ...snapshot(paid: 'expired', expiry: 1799999999999),
      'status': 'unknown',
      'effectiveTier': null,
      'paidStatus': 'unknown',
      'reason': 'payment_evidence_unavailable'
    });
    expect(e.isResolved, isFalse);
    expect(e.paidTier, MembershipTier.premium);
    expect(e.effectiveTier, isNull);
  });
}
