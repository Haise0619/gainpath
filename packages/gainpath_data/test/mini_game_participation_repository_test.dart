import 'package:test/test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_data/gamification.dart';
import 'support/mini_game_participation_fixture.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
void main() {
  test('Reach overview and claim use selected game without score or amount',
      () async {
    final inputs = <Map<String, dynamic>>[];
    final repo = RemoteMiniGameParticipationRepository(
        scope: scope,
        gameId: 'reach-tap-v1',
        isCurrent: () => true,
        call: (input) async {
          inputs.add(input);
          final d = participationFixture(
              active: true,
              status: input['action'] == 'participationOverview'
                  ? 'overview'
                  : 'game-limit',
              attemptId: input['attemptId'] as String?);
          d['schemaVersion'] = 3;
          d['gameId'] = 'reach-tap-v1';
          final policy =
              Map<String, dynamic>.from((d['overview'] as Map)['policy']);
          policy['version'] = 'reach-tap-participation-v1';
          policy['games'] = [
            {'gameId': 'reach-tap-v1', 'points': 20, 'dailyClaimLimit': 1}
          ];
          (d['overview'] as Map)['policy'] = policy;
          return d;
        });
    expect((await repo.overview()).gameId, 'reach-tap-v1');
    expect((await repo.claim('a' * 32)).status, 'game-limit');
    expect(inputs.last, {
      'schemaVersion': 3,
      'organizationId': 'gainpath',
      'gameId': 'reach-tap-v1',
      'action': 'claimParticipation',
      'attemptId': 'a' * 32
    });
  });
  test(
      'Reach transport negotiates gameId and rejects a different game response',
      () async {
    final repo = RemoteMiniGameParticipationRepository(
        scope: scope,
        gameId: 'reach-tap-v1',
        isCurrent: () => true,
        call: (d) async {
          expect(d, {
            'schemaVersion': 3,
            'organizationId': 'gainpath',
            'action': 'participationOverview',
            'gameId': 'reach-tap-v1'
          });
          return participationFixture();
        });
    await expectLater(repo.overview(), throwsFormatException);
  });
  test('claim sends only owned attempt ID without scores amounts or dates',
      () async {
    final repo = RemoteMiniGameParticipationRepository(
        scope: scope,
        isCurrent: () => true,
        call: (d) async {
          expect(d, {
            'schemaVersion': 2,
            'organizationId': 'gainpath',
            'action': 'claimParticipation',
            'attemptId': 'a' * 32
          });
          return participationFixture(
              status: 'not-active', attemptId: 'a' * 32);
        });
    expect((await repo.claim('a' * 32)).status, 'not-active');
  });
  test('scope changes before or after transport hide responses', () async {
    var current = false, calls = 0;
    final repo = RemoteMiniGameParticipationRepository(
        scope: scope,
        isCurrent: () => current,
        call: (_) async {
          calls++;
          current = false;
          return participationFixture();
        });
    await expectLater(
        repo.overview(), throwsA(isA<MiniGameParticipationSessionChanged>()));
    expect(calls, 0);
    current = true;
    await expectLater(
        repo.overview(), throwsA(isA<MiniGameParticipationSessionChanged>()));
  });
  test('foreign attempt response cannot become another round receipt',
      () async {
    final repo = RemoteMiniGameParticipationRepository(
        scope: scope,
        isCurrent: () => true,
        call: (_) async =>
            participationFixture(status: 'not-active', attemptId: 'b' * 32));
    await expectLater(repo.claim('a' * 32), throwsFormatException);
  });
}
