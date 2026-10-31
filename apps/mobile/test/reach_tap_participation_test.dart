import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap_participation.dart';

void main() {
  test(
      'historical proposal is not live issuance authority; current contract supports Reach',
      () {
    const proposal = ReachTapParticipationProposal();
    final existing = MiniGameRewardPolicy.draft();
    expect(proposal.gameId, 'reach-tap-v1');
    expect(proposal.pointsPerCompletedRound, existing.games.single.points);
    expect(proposal.claimsPerGamePerDay, existing.games.single.dailyClaimLimit);
    expect(proposal.sharedDailyPointsCap, existing.dailyPointsCap);
    expect(proposal.timezone, existing.timezone);
    expect(proposal.issuanceEnabled, isFalse);
    expect(existing.games.map((game) => game.gameId), ['move-catch-v1']);
    expect(MiniGameRewardGame(gameId: proposal.gameId).toJson()['gameId'],
        'reach-tap-v1');
  });
}
