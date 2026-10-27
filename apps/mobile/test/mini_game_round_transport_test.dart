import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_mini_game_round_repository.dart';
import 'support/mini_game_round_fixture.dart' show response;

class SwitchingReadiness extends FirebaseAppCheckReadiness {
  SwitchingReadiness(this.switchUser);
  final void Function() switchUser;
  bool afterGuard = false;
  @override
  Future<bool> ensureReady({void Function()? check}) async {
    switchUser();
    check?.call();
    afterGuard = true;
    return true;
  }
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  test(
      'Firebase round adapter refuses other or signed-out subjects before calls',
      () async {
    for (final uid in ['other', null]) {
      var calls = 0;
      final r = FirebaseMiniGameRoundRepository(
          scope: scope,
          isCurrent: () => true,
          currentUid: () => uid,
          call: (_) async {
            calls++;
            return response();
          });
      await expectLater(r.begin(requestId: 'c' * 32),
          throwsA(isA<MiniGameRoundSessionChanged>()));
      expect(calls, 0);
    }
  });
  test('subject change during App Check must stop before Firebase call',
      () async {
    String? uid = 'member';
    final readiness = SwitchingReadiness(() => uid = 'other');
    final r = FirebaseMiniGameRoundRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => uid,
        readiness: readiness);
    await expectLater(r.begin(requestId: 'c' * 32),
        throwsA(isA<MiniGameRoundSessionChanged>()));
    expect(readiness.afterGuard, false);
  });
  test('session loss during injected transport hides returned owned data',
      () async {
    var current = true;
    final r = FirebaseMiniGameRoundRepository(
        scope: scope,
        isCurrent: () => current,
        currentUid: () => 'member',
        call: (_) async {
          current = false;
          return response();
        });
    await expectLater(r.begin(requestId: 'c' * 32),
        throwsA(isA<MiniGameRoundSessionChanged>()));
  });
}
