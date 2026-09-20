import 'package:test/test.dart';
import 'package:gainpath_domain/src/membership/policies/promo_policy.dart';

void main() {
  const policy = PromoPolicy();
  test('known code gives its discount, case-insensitively', () {
    expect(policy.discountFor('gainpath10'), 0.10);
    expect(policy.discountFor(' GAINPATH10 '), 0.10);
  });
  test('unknown code gives no discount', () => expect(policy.discountFor('NOPE'), isNull));
}
