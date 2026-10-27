import 'package:test/test.dart';
import 'package:gainpath_domain/gamification.dart';

Map<String, dynamic> voucher() => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'memberId': 'member',
      'redemptionId': 'voucher',
      'itemId': 'item',
      'title': 'Bottle',
      'points': 500,
      'status': 'issued',
      'issuedAtMillis': 1000,
      'policyVersion': 'v1',
      'exchangeRateVersion': 'r1',
      'rewardDetailsVersion': 1,
      'description': 'Bottle information',
      'imageUrl': '',
      'conditions': 'Collect in person',
      'collectionInstructions': 'Show at reception',
      'expiresAtMillis': 86401000,
      'expiredPointsPolicy': 'remain_spent'
    };
void main() {
  test('voucher retains conditions and encodes only scoped reference in QR',
      () {
    final r = VerifiedRewardRedemption.fromJson(voucher(),
        organizationId: 'gainpath', memberId: 'member');
    expect(r.conditions, 'Collect in person');
    expect(r.expiresAtMillis, 86401000);
    expect(RewardVoucherCode.reference(r.qrPayload, organizationId: 'gainpath'),
        'voucher');
    expect(r.qrPayload, isNot(contains('member')));
    expect(
        () => RewardVoucherCode.reference(r.qrPayload, organizationId: 'other'),
        throwsFormatException);
    expect(RewardVoucherCode.reference('voucher', organizationId: 'gainpath'),
        'voucher');
  });
  test('invalid new details cannot fall back to a legacy unexpired voucher',
      () {
    for (final change in [
      {'expiresAtMillis': 999},
      {'expiredPointsPolicy': 'refund'},
      {'imageUrl': 'http://bad'},
      {'conditions': ''},
      {'rewardDetailsVersion': null},
      {'redemptionId': 'bad/ref'}
    ]) {
      expect(
          () => VerifiedRewardRedemption.fromJson({...voucher(), ...change},
              organizationId: 'gainpath', memberId: 'member'),
          throwsFormatException);
    }
  });
  test(
      'new expiry fields cannot be downgraded by removing their detail version',
      () {
    final raw = voucher()..remove('rewardDetailsVersion');
    expect(
        () => VerifiedRewardRedemption.fromJson(raw,
            organizationId: 'gainpath', memberId: 'member'),
        throwsFormatException);
  });
  test('legacy issued vouchers retain unknown expiry and remain readable', () {
    final raw = voucher()
      ..removeWhere((k, _) => [
            'rewardDetailsVersion',
            'description',
            'imageUrl',
            'conditions',
            'collectionInstructions',
            'expiresAtMillis',
            'expiredPointsPolicy'
          ].contains(k));
    final r = VerifiedRewardRedemption.fromJson(raw,
        organizationId: 'gainpath', memberId: 'member');
    expect(r.expiresAtMillis, isNull);
  });
}
