import 'package:test/test.dart';
import 'package:gainpath_domain/src/gamification/policies/reward_policy.dart';

void main() {
  test('daily check-in awards 50 points', () => expect(RewardPolicy.dailyCheckIn, 50));
  test('mini-game score converts at one point per ten', () {
    expect(RewardPolicy.pointsForMiniGameScore(1234), 123);
    expect(RewardPolicy.pointsForMiniGameScore(0), 0);
  });
}
