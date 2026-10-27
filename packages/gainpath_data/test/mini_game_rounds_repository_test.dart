import 'package:test/test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_data/gamification.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
Map<String, dynamic> response() => {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'memberId': 'member',
      'gameId': 'move-catch-v1',
      'attemptId': 'a' * 32,
      'challengeToken': 'b' * 32,
      'status': 'open',
      'sequence': 0,
      'activeMillis': 0,
      'startedAtMillis': 1000000,
      'leaseUntilMillis': 1090000,
      'expiresAtMillis': 1900000,
      'physicalVerified': false,
      'pointsAwarded': 0
    };
void main() {
  test(
      'round transport binds owner and sends timing, never score or trusted evidence',
      () async {
    final calls = <Map<String, dynamic>>[];
    final repo = RemoteMiniGameRoundRepository(
        scope: scope,
        isCurrent: () => true,
        call: (d) async {
          calls.add(d);
          return {
            ...response(),
            'sequence': d['sequence'] ?? 0,
            'activeMillis': d['activeMillis'] ?? 0
          };
        });
    final r = await repo.begin(requestId: 'c' * 32);
    final next = await repo.checkpoint(
        round: r, sequence: 1, activeMillis: 2000, playing: true);
    expect(next.sequence, 1);
    expect(calls.first, {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'action': 'begin',
      'gameId': 'move-catch-v1',
      'requestId': 'c' * 32
    });
    expect(calls.last['challengeToken'], 'b' * 32);
    expect(calls.last.containsKey('score'), false);
  });
  test('foreign responses and fabricated completion/points reject', () async {
    for (final change in [
      {'memberId': 'other'},
      {'pointsAwarded': 20},
      {'physicalVerified': true},
      {'sequence': 1}
    ]) {
      final repo = RemoteMiniGameRoundRepository(
          scope: scope,
          isCurrent: () => true,
          call: (_) async => {...response(), ...change});
      await expectLater(repo.begin(requestId: 'c' * 32), throwsFormatException);
    }
  });
  test('session change before and during transport prevents disclosure',
      () async {
    var current = false, calls = 0;
    final repo = RemoteMiniGameRoundRepository(
        scope: scope,
        isCurrent: () => current,
        call: (_) async {
          calls++;
          current = false;
          return response();
        });
    await expectLater(repo.begin(requestId: 'c' * 32),
        throwsA(isA<MiniGameRoundSessionChanged>()));
    expect(calls, 0);
    current = true;
    await expectLater(repo.begin(requestId: 'c' * 32),
        throwsA(isA<MiniGameRoundSessionChanged>()));
  });
  test('checkpoint mismatches cannot be used as later authority', () async {
    final repo = RemoteMiniGameRoundRepository(
        scope: scope,
        isCurrent: () => true,
        call: (d) async => {...response(), 'sequence': d['sequence'] ?? 0});
    final r = await repo.begin(requestId: 'c' * 32);
    await expectLater(
        repo.checkpoint(
            round: r, sequence: 1, activeMillis: 2000, playing: true),
        throwsFormatException);
    await expectLater(
        repo.finish(round: r, sequence: 1), throwsFormatException);
  });
}
