import 'package:test/test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'support/mini_game_participation_fixture.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
void main() {
  test(
      'Reach receipt and immutable policy reject altered amount cap or wrong game',
      () {
    final d = participationFixture(
        status: 'awarded',
        active: true,
        attemptId: 'a' * 32,
        balance: 20,
        earned: 20);
    d['schemaVersion'] = 3;
    d['gameId'] = 'reach-tap-v1';
    final policy = Map<String, dynamic>.from((d['overview'] as Map)['policy']);
    policy['version'] = 'reach-tap-participation-v1';
    policy['games'] = [
      {'gameId': 'reach-tap-v1', 'points': 20, 'dailyClaimLimit': 1}
    ];
    (d['overview'] as Map)['policy'] = policy;
    (d['award'] as Map)['gameId'] = 'reach-tap-v1';
    (d['award'] as Map)['policySnapshot'] = policy;
    (d['award'] as Map)['policyVersion'] = 'reach-tap-participation-v1';
    expect(
        MiniGameParticipation.fromJson(d, scope).award!.gameId, 'reach-tap-v1');
    for (final fields in [
      {'version': 'mini-game-rewards-draft-v1'},
      {'dailyPointsCap': 61},
      {
        'games': [
          {'gameId': 'reach-tap-v1', 'points': 30, 'dailyClaimLimit': 1}
        ]
      }
    ]) {
      expect(() => MiniGameRewardPolicy.fromJson({...policy, ...fields}),
          throwsFormatException);
    }
  });
  test(
      'schema3 Reach uses explicit game and dedicated policy with independent counter',
      () {
    final d = participationFixture(active: true);
    d['schemaVersion'] = 3;
    d['gameId'] = 'reach-tap-v1';
    final policy = Map<String, dynamic>.from((d['overview'] as Map)['policy']);
    policy['version'] = 'reach-tap-participation-v1';
    policy['games'] = [
      {'gameId': 'reach-tap-v1', 'points': 20, 'dailyClaimLimit': 1}
    ];
    (d['overview'] as Map)['policy'] = policy;
    final result = MiniGameParticipation.fromJson(d, scope);
    expect(result.gameId, 'reach-tap-v1');
    expect(result.policy.games.single.gameId, 'reach-tap-v1');
    d['gameId'] = 'move-catch-v1';
    expect(
        () => MiniGameParticipation.fromJson(d, scope), throwsFormatException);
  });
  test('a receipt remains valid after its points have been spent', () {
    final d = participationFixture(
        status: 'already-awarded',
        active: true,
        attemptId: 'a' * 32,
        balance: 0,
        earned: 20);
    expect(MiniGameParticipation.fromJson(d, scope).award!.points, 20);
  });
  test('participation response keeps demo balance and fixed award separate',
      () {
    final r = MiniGameParticipation.fromJson(
        participationFixture(
            status: 'awarded',
            active: true,
            attemptId: 'a' * 32,
            balance: 20,
            earned: 20),
        scope);
    expect(r.award!.points, 20);
    expect(r.balance, 20);
    expect(r.remainingToday, 40);
  });
  test('foreign physical or redeemable claims reject', () {
    for (final delta in [
      {'memberId': 'other'},
      {'mode': 'verified'},
      {'physicalVerified': true},
      {'redeemable': false}
    ]) {
      expect(
          () => MiniGameParticipation.fromJson(
              {...participationFixture(), ...delta}, scope),
          throwsFormatException);
    }
  });
  test('unknown counters and award inconsistency reject', () {
    final d = participationFixture(
        status: 'awarded',
        active: true,
        attemptId: 'a' * 32,
        balance: 20,
        earned: 20);
    expect(() => MiniGameParticipation.fromJson({...d, 'award': null}, scope),
        throwsFormatException);
    (d['overview'] as Map)['remainingToday'] = 60;
    expect(
        () => MiniGameParticipation.fromJson(d, scope), throwsFormatException);
  });
  test('historical award uses its own preserved policy', () {
    final d = participationFixture(
        status: 'already-awarded',
        active: true,
        attemptId: 'a' * 32,
        balance: 20,
        earned: 20);
    (d['overview'] as Map)['policy'] = MiniGameRewardPolicy(
        revision: 1,
        version: 'mini-game-rewards-v1',
        updatedAtMillis: 1,
        games: [const MiniGameRewardGame(points: 30)]).toJson();
    expect(MiniGameParticipation.fromJson(d, scope).award!.points, 20);
  });
}
