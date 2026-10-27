import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gamification.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseMiniGameRoundRepository extends RemoteMiniGameRoundRepository {
  FirebaseMiniGameRoundRepository(
      {required super.scope,
      required bool Function() isCurrent,
      String? Function()? currentUid,
      MiniGameContentCall? call,
      FirebaseAppCheckReadiness? readiness})
      : super(
            isCurrent: () => _current(isCurrent, currentUid, scope.userId),
            call: call ??
                ((input) => _call(
                    input,
                    readiness ?? FirebaseAppCheckReadiness.instance,
                    () => _current(isCurrent, currentUid, scope.userId))));
  static const enabled = bool.fromEnvironment('MINI_GAME_ROUND_SYNC_ENABLED');
}

bool _current(bool Function() isCurrent, String? Function()? currentUid,
        String uid) =>
    isCurrent() &&
    (currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid))() == uid;

Future<Map<String, dynamic>> _call(Map<String, dynamic> input,
    FirebaseAppCheckReadiness readiness, bool Function() current) async {
  void check() {
    if (!current()) throw const MiniGameRoundSessionChanged();
  }

  check();
  if (!await readiness.ensureReady(check: check)) {
    throw const MiniGameRoundUnavailable();
  }
  check();
  try {
    final client = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      client.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '10.0.2.2'),
          5001);
    }
    return (await client
            .httpsCallable('miniGameRoundCommand',
                options:
                    HttpsCallableOptions(timeout: const Duration(seconds: 10)))
            .call<Map<String, dynamic>>(input))
        .data;
  } on FirebaseFunctionsException catch (e) {
    if (e.code == 'unauthenticated') throw const MiniGameRoundSessionChanged();
    if (e.code == 'resource-exhausted') throw const MiniGameRoundBusy();
    throw const MiniGameRoundUnavailable();
  }
}
