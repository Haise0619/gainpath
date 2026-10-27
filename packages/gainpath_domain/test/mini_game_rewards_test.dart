import 'package:test/test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  test(
      'draft defaults preserve independent score and disabled20/60/once-per-type policy',
      () {
    final p = MiniGameRewardPolicy();
    expect(p.enabled, isFalse);
    expect(p.dailyPointsCap, 60);
    expect(p.games.single.points, 20);
    expect(p.games.single.dailyClaimLimit, 1);
    expect(p.timezone, 'Asia/Kuala_Lumpur');
    expect(MiniGameRewardPolicy.fromJson(p.toJson()).toFields(), p.toFields());
    expect(p.toFields().containsKey('enabled'), isFalse);
  });
  test(
      'draft cannot enable multipliers, unsupported games or repeated per-game awards',
      () {
    final p = MiniGameRewardPolicy();
    expect(
        () => MiniGameRewardPolicy.fromJson({...p.toJson(), 'enabled': true}),
        throwsFormatException);
    expect(
        () => MiniGameRewardPolicy.fromJson(
            {...p.toJson(), 'premiumMultiplier': 1.5}),
        throwsFormatException);
    expect(
        () => p.copyWith(
            games: [const MiniGameRewardGame(dailyClaimLimit: 2)]).toFields(),
        throwsFormatException);
  });
  test(
      'owned daily overview preserves server-earned/remaining totals and ineligibility',
      () {
    final raw = {
      'schemaVersion': 1,
      'organizationId': 'gym',
      'memberId': 'member',
      'timezone': 'Asia/Kuala_Lumpur',
      'today': '2026-10-27',
      'policy': MiniGameRewardPolicy().toJson(),
      'earnedPoints': 20,
      'remainingPoints': 40,
      'issuanceActive': false,
      'games': [
        {
          'gameId': MiniGameContent.supportedId,
          'claimsToday': 1,
          'eligible': false,
          'reason': 'not-active'
        }
      ]
    };
    final s = MiniGameRewardStatus.fromJson(raw, scope);
    expect(s.earnedPoints, 20);
    expect(s.remainingPoints, 40);
    expect(s.games.single.eligible, isFalse);
    expect(
        () =>
            MiniGameRewardStatus.fromJson({...raw, 'memberId': 'other'}, scope),
        throwsFormatException);
    expect(
        () => MiniGameRewardStatus.fromJson(
            {...raw, 'remainingPoints': 60}, scope),
        throwsFormatException);
  });
}
