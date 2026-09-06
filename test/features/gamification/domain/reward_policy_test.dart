import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/gamification/domain/policies/reward_policy.dart';

void main() {
  test('daily check-in awards 50 points', () => expect(RewardPolicy.dailyCheckIn, 50));
}
