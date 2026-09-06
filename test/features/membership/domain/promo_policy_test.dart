import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/membership/domain/policies/promo_policy.dart';

void main() {
  const policy = PromoPolicy();
  test('known code gives its discount, case-insensitively', () {
    expect(policy.discountFor('gainpath10'), 0.10);
    expect(policy.discountFor(' GAINPATH10 '), 0.10);
  });
  test('unknown code gives no discount', () => expect(policy.discountFor('NOPE'), isNull));
}
