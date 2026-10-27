import 'package:test/test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_data/gamification.dart';
import 'support/mini_game_participation_fixture.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
void main() {
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
