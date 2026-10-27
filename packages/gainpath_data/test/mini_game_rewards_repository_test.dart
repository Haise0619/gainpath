import 'package:test/test.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  Map<String, dynamic> overview() => {
        'schemaVersion': 1,
        'organizationId': 'gym',
        'memberId': 'member',
        'timezone': 'Asia/Kuala_Lumpur',
        'today': '2026-10-27',
        'policy': MiniGameRewardPolicy().toJson(),
        'earnedPoints': 0,
        'remainingPoints': 60,
        'issuanceActive': false,
        'games': [
          {
            'gameId': MiniGameContent.supportedId,
            'claimsToday': 0,
            'eligible': false,
            'reason': 'not-active'
          }
        ]
      };
  test('Member reader exposes only owned server totals and no claim call',
      () async {
    final reader = RemoteMiniGameRewardStatusReader(
        scope: scope,
        isCurrent: () => true,
        call: (input) async {
          expect(input, {
            'schemaVersion': 1,
            'organizationId': 'gym',
            'action': 'overview'
          });
          return overview();
        });
    expect((await reader.overview()).remainingPoints, 60);
  });
  test('stale or forged overview cannot become an earned points display',
      () async {
    var current = true;
    final reader = RemoteMiniGameRewardStatusReader(
        scope: scope,
        isCurrent: () => current,
        call: (_) async {
          current = false;
          return overview();
        });
    await expectLater(
        reader.overview(), throwsA(isA<MiniGameRewardSessionChanged>()));
  });
  test('Admin saves disabled configuration only and verifies revision/readback',
      () async {
    final policy = MiniGameRewardPolicy().copyWith(dailyPointsCap: 80);
    final repo = RemoteMiniGameRewardConfigurationRepository(
        scope: scope,
        isCurrent: () => true,
        call: (input) async {
          expect(input['action'], 'savePolicy');
          expect(input.containsKey('enabled'), isFalse);
          return {
            'schemaVersion': 1,
            'organizationId': 'gym',
            'issuanceActive': false,
            'policy': {
              ...policy.toJson(),
              'revision': 1,
              'version': 'mini-game-rewards-v1',
              'updatedAtMillis': 1000
            }
          };
        });
    expect(
        (await repo.savePolicy(
                requestId: 'a' * 32, baseRevision: 0, policy: policy))
            .dailyPointsCap,
        80);
  });
}
