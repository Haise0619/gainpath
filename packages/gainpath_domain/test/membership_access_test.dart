import 'package:test/test.dart';
import 'package:gainpath_domain/membership.dart';

Map<String, dynamic> decision({String value = 'allowed'}) => {
      'schemaVersion': 1,
      'policyVersion': 'gainpath-membership-access-v1',
      'organizationId': 'o',
      'memberId': 'm',
      'resolvedAtMillis': 1800000000000,
      'feature': 'advancedReport',
      'resourceId': 'performance_trends',
      'effectiveTier': value == 'unknown' ? null : 'premium',
      'requiredTier': ['unknown', 'legacy'].contains(value) ? null : 'premium',
      'decision': value,
      'reason': 'tier_access'
    };
void main() {
  test('legacy preserves routes while unknown and denied remain locked', () {
    for (final value in ['allowed', 'legacy', 'unknown', 'denied']) {
      final d = MembershipAccessDecision.fromJson(decision(value: value),
          organizationId: 'o',
          memberId: 'm',
          feature: MembershipAccessFeature.advancedReport,
          resourceId: 'performance_trends');
      expect(d.permitsEntry, ['allowed', 'legacy'].contains(value));
    }
  });
  test('rejects cached, foreign account and mismatched resource projections',
      () {
    for (final patch in [
      {'cached': true},
      {'organizationId': 'foreign'},
      {'memberId': 'foreign'},
      {'resourceId': 'other'},
      {'feature': 'exercise'},
      {'decision': 'invented'},
      {'resolvedAtMillis': 0}
    ]) {
      expect(
          () => MembershipAccessDecision.fromJson({...decision(), ...patch},
              organizationId: 'o',
              memberId: 'm',
              feature: MembershipAccessFeature.advancedReport,
              resourceId: 'performance_trends'),
          throwsFormatException);
    }
  });
  test('denied target cannot fabricate Free or allow gym entry', () {
    final json = {
      'schemaVersion': 1,
      'organizationId': 'o',
      'memberId': 'm',
      'verifiedAtMillis': 1800000000000,
      'status': 'denied',
      'gymAdmission': false,
      'identity': null,
      'entitlement': null
    };
    expect(
        MemberMembershipVerification.fromJson(json,
                organizationId: 'o', memberId: 'm')
            .entitlement,
        isNull);
    expect(
        () => MemberMembershipVerification.fromJson(
            {...json, 'gymAdmission': true},
            organizationId: 'o', memberId: 'm'),
        throwsFormatException);
  });
  test('rejects an allowed paid decision without a qualifying effective tier',
      () {
    expect(
        () => MembershipAccessDecision.fromJson(
            {...decision(), 'effectiveTier': 'free'},
            organizationId: 'o',
            memberId: 'm',
            feature: MembershipAccessFeature.advancedReport,
            resourceId: 'performance_trends'),
        throwsFormatException);
  });
}
