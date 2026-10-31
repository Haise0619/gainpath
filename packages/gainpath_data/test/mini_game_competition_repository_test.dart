import 'dart:async';
import 'package:test/test.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
Map<String, dynamic> pref(bool enabled) => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'memberId': 'member',
      'enabled': enabled,
      'policyVersion': miniGameCompetitionPolicyVersion,
      'revision': 1,
      'changedAtMillis': 1000
    };
void main() {
  test('preference sends explicit choice and fixed policy without media',
      () async {
    Map<String, dynamic>? sent;
    final repo = RemoteMiniGameCompetitionRepository(
        scope: scope,
        isCurrent: () => true,
        call: (d) async {
          sent = d;
          return pref(true);
        });
    expect((await repo.setPreference(enabled: true)).enabled, true);
    expect(sent, {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'action': 'competition',
      'command': {
        'action': 'setPreference',
        'enabled': true,
        'policyVersion': miniGameCompetitionPolicyVersion
      }
    });
  });
  test('late results reject account changes', () async {
    var current = true;
    final gate = Completer<Map<String, dynamic>>();
    final repo = RemoteMiniGameCompetitionRepository(
        scope: scope, isCurrent: () => current, call: (_) => gate.future);
    final future = repo.preference();
    current = false;
    gate.complete(pref(false));
    await expectLater(
        future, throwsA(isA<MiniGameCompetitionSessionChanged>()));
  });
  test('submissions send events instead of unrestricted score', () async {
    Map<String, dynamic>? sent;
    final repo = RemoteMiniGameCompetitionRepository(
        scope: scope,
        isCurrent: () => true,
        call: (d) async {
          sent = d;
          return {
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
        });
    final r = await repo.submit(
        gameId: 'reach-tap-v1',
        attemptId: 'a' * 32,
        challengeToken: 'b' * 32,
        events: const [
          MiniGameScoreEvent(sequence: 1, activeMillis: 1000, type: 'hit')
        ]);
    expect(r.score, 10);
    expect((sent!['command'] as Map).containsKey('score'), false);
    expect((sent!['command'] as Map)['events'], [
      {'sequence': 1, 'activeMillis': 1000, 'type': 'hit'}
    ]);
  });
  test('unmatched confirmation cannot change preference silently', () async {
    final repo = RemoteMiniGameCompetitionRepository(
        scope: scope, isCurrent: () => true, call: (_) async => pref(false));
    await expectLater(repo.setPreference(enabled: true), throwsFormatException);
  });
  test('Reach timing negotiation sends game and validates matching response',
      () async {
    Map<String, dynamic>? sent;
    final repo = RemoteMiniGameRoundRepository(
        scope: scope,
        gameId: 'reach-tap-v1',
        isCurrent: () => true,
        call: (d) async {
          sent = d;
          return {
            'schemaVersion': 1,
            'organizationId': 'gainpath',
            'memberId': 'member',
            'gameId': 'reach-tap-v1',
            'attemptId': 'a' * 32,
            'challengeToken': 'b' * 32,
            'status': 'open',
            'sequence': 0,
            'activeMillis': 0,
            'startedAtMillis': 1000,
            'leaseUntilMillis': 91000,
            'expiresAtMillis': 901000,
            'physicalVerified': false,
            'pointsAwarded': 0
          };
        });
    expect((await repo.begin(requestId: 'c' * 32)).gameId, 'reach-tap-v1');
    expect(sent!['gameId'], 'reach-tap-v1');
  });
}
