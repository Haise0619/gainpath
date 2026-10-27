import 'package:test/test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';

final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
Map<String, dynamic> fields() => {
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
  test('owned timing response never implies physical verification or rewards',
      () {
    final r = MiniGameRound.fromJson(fields(), scope);
    expect(r.status, 'open');
    expect(r.activeMillis, 0);
    expect(r.attemptId, 'a' * 32);
  });
  test('foreign, invented evidence and malformed timing fields fail closed',
      () {
    for (final change in [
      {'memberId': 'other'},
      {'physicalVerified': true},
      {'pointsAwarded': 20},
      {'status': 'verified'},
      {'activeMillis': 40001},
      {'sequence': -1},
      {'expiresAtMillis': 1000001},
      {'challengeToken': 'bad'},
      {'extra': 1}
    ]) {
      expect(() => MiniGameRound.fromJson({...fields(), ...change}, scope),
          throwsFormatException);
    }
  });
  test('pending completion requires a full round and stable sequence', () {
    expect(
        () => MiniGameRound.fromJson(
            {...fields(), 'status': 'awaiting_verification'}, scope),
        throwsFormatException);
    final r = MiniGameRound.fromJson({
      ...fields(),
      'status': 'awaiting_verification',
      'activeMillis': 40000,
      'sequence': 21
    }, scope);
    expect(r.status, 'awaiting_verification');
  });
}
