import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gamification.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseMiniGameParticipationRepository
    extends RemoteMiniGameParticipationRepository {
  FirebaseMiniGameParticipationRepository(
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
  static const enabled =
      bool.fromEnvironment('MINI_GAME_PARTICIPATION_ENABLED');
}

bool _current(
        bool Function() current, String? Function()? uid, String expected) =>
    current() &&
    (uid ?? (() => FirebaseAuth.instance.currentUser?.uid))() == expected;
Future<Map<String, dynamic>> _call(Map<String, dynamic> input,
    FirebaseAppCheckReadiness readiness, bool Function() current) async {
  void check() {
    if (!current()) throw const MiniGameParticipationSessionChanged();
  }

  check();
  if (!await readiness.ensureReady(check: check)) {
    throw const MiniGameParticipationUnavailable();
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
            .httpsCallable('miniGameRewardsCommand')
            .call<Map<String, dynamic>>(input))
        .data;
  } on FirebaseFunctionsException catch (e) {
    if (e.code == 'unauthenticated') {
      throw const MiniGameParticipationSessionChanged();
    }
    throw const MiniGameParticipationUnavailable();
  }
}
