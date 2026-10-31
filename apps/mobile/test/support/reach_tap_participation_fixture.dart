import 'package:gainpath_domain/gamification.dart';
import 'mini_game_participation_fixture.dart';

Map<String, dynamic> reachParticipationFixture(
    {String status = 'overview',
    bool active = true,
    String? attemptId,
    int balance = 0,
    int earned = 0,
    int claims = 0}) {
  final value = participationFixture(
      status: status,
      active: active,
      attemptId: attemptId,
      balance: balance,
      earned: earned);
  value['schemaVersion'] = 3;
  value['gameId'] = MiniGameContent.reachTapId;
  final policy = MiniGameRewardPolicy(
          version: 'reach-tap-participation-v1',
          games: const [MiniGameRewardGame(gameId: MiniGameContent.reachTapId)])
      .toJson();
  (value['overview'] as Map)['policy'] = policy;
  (value['overview'] as Map)['claimsToday'] = claims;
  if (value['award'] != null) {
    final award = value['award'] as Map;
    award['gameId'] = MiniGameContent.reachTapId;
    award['policyVersion'] = 'reach-tap-participation-v1';
    award['policySnapshot'] = policy;
  }
  return value;
}
