import 'package:test/test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
Map<String, dynamic> preference() => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'memberId': 'member',
      'enabled': false,
      'policyVersion': miniGameCompetitionPolicyVersion,
      'revision': 0,
      'changedAtMillis': 0
    };
Map<String, dynamic> receipt() => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'memberId': 'member',
      'gameId': 'reach-tap-v1',
      'attemptId': 'a' * 32,
      'score': 10,
      'acceptedAtMillis': 1000,
      'physicalVerified': false,
      'pointsAwarded': 0
    };
Map<String, dynamic> standings() => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'memberId': 'member',
      'gameId': 'reach-tap-v1',
      'period': 'week',
      'periodKey': '1000',
      'scoringVersion': 1,
      'entries': [
        {'rank': 1, 'displayName': 'You', 'score': 10, 'isYou': true}
      ],
      'you': {'rank': 1, 'displayName': 'You', 'score': 10, 'isYou': true},
      'totalParticipants': 1,
      'resolvedAtMillis': 1000,
      'trustLabel': miniGameCompetitionTrustLabel
    };
void main() {
  test('preference defaults disabled and requires matching account and policy',
      () {
    expect(MiniGameCompetitionPreference.fromJson(preference(), scope).enabled,
        false);
    for (final c in [
      {'memberId': 'other'},
      {'policyVersion': 'unknown'},
      {'enabled': 1},
      {'revision': -1}
    ]) {
      expect(
          () => MiniGameCompetitionPreference.fromJson(
              {...preference(), ...c}, scope),
          throwsFormatException);
    }
  });
  test('accepted score cannot represent points or physical verification', () {
    expect(MiniGameAcceptedScore.fromJson(receipt(), scope).score, 10);
    for (final c in [
      {'memberId': 'other'},
      {'pointsAwarded': 20},
      {'physicalVerified': true},
      {'gameId': 'fake'},
      {'score': -1},
      {'score': 4001}
    ]) {
      expect(() => MiniGameAcceptedScore.fromJson({...receipt(), ...c}, scope),
          throwsFormatException);
    }
  });
  test('standings require scoped game period and honest trust label', () {
    expect(MiniGameScoreLeaderboard.fromJson(standings(), scope).you.score, 10);
    for (final c in [
      {'organizationId': 'foreign'},
      {'memberId': 'other'},
      {'gameId': 'fake'},
      {'period': 'month'},
      {'scoringVersion': 2},
      {'trustLabel': 'Physically verified'}
    ]) {
      expect(
          () =>
              MiniGameScoreLeaderboard.fromJson({...standings(), ...c}, scope),
          throwsFormatException);
    }
  });
  test('unranked means null not rank zero and reversed scores reject', () {
    final d = standings();
    d['entries'] = [];
    d['totalParticipants'] = 0;
    d['you'] = {
      'rank': null,
      'displayName': 'You',
      'score': null,
      'isYou': true
    };
    expect(MiniGameScoreLeaderboard.fromJson(d, scope).you.rank, isNull);
    d['you'] = {'rank': 0, 'displayName': 'You', 'score': 0, 'isYou': true};
    expect(() => MiniGameScoreLeaderboard.fromJson(d, scope),
        throwsFormatException);
    final x = standings();
    x['entries'] = [
      {'rank': 1, 'displayName': 'Member', 'score': 10, 'isYou': false},
      {'rank': 2, 'displayName': 'You', 'score': 20, 'isYou': true}
    ];
    x['totalParticipants'] = 2;
    expect(() => MiniGameScoreLeaderboard.fromJson(x, scope),
        throwsFormatException);
  });
}
