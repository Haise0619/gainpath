import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/coaching/domain/policies/booking_policy.dart';

void main() {
  final now = DateTime(2026, 9, 6);
  const policy = BookingPolicy(dailyCap: 4, advanceDays: 30);

  test('a day under the cap and inside the window is bookable', () {
    expect(policy.canBookOn(now.add(const Duration(days: 30)), existingThatDay: 3, now: now), isTrue);
  });
  test('a full day is not bookable', () {
    expect(policy.canBookOn(now.add(const Duration(days: 1)), existingThatDay: 4, now: now), isFalse);
  });
  test('a day beyond the advance window is not bookable', () {
    expect(policy.canBookOn(now.add(const Duration(days: 31)), existingThatDay: 0, now: now), isFalse);
  });
}
