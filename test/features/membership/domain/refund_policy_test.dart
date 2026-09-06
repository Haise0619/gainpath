import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/membership/domain/policies/refund_policy.dart';

void main() {
  final now = DateTime(2026, 9, 6);
  const policy = RefundPolicy();

  test('a charge inside the window is eligible', () {
    expect(policy.isEligible(now.subtract(const Duration(days: 7)), now: now), isTrue);
  });

  test('a charge outside the window is not eligible', () {
    expect(policy.isEligible(now.subtract(const Duration(days: 8)), now: now), isFalse);
  });
}
