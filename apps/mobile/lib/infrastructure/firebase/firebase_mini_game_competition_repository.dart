import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gamification.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseMiniGameCompetitionRepository
    extends RemoteMiniGameCompetitionRepository {
  FirebaseMiniGameCompetitionRepository(
      {required super.scope,
      required bool Function() isCurrent,
      String? Function()? currentUid,
      MiniGameContentCall? call,
      FirebaseAppCheckReadiness? readiness})
      : super(
            isCurrent: () =>
                isCurrent() &&
                (currentUid ??
                        (() => FirebaseAuth.instance.currentUser?.uid))() ==
                    scope.userId,
            call: call ??
                ((input) => _call(
                    input,
                    readiness ?? FirebaseAppCheckReadiness.instance,
                    () =>
                        isCurrent() &&
                        (currentUid ??
                                (() => FirebaseAuth
                                    .instance.currentUser?.uid))() ==
                            scope.userId)));
}

Future<Map<String, dynamic>> _call(Map<String, dynamic> input,
    FirebaseAppCheckReadiness readiness, bool Function() current) async {
  void check() {
    if (!current()) throw const MiniGameCompetitionSessionChanged();
  }

  check();
  if (!await readiness.ensureReady(check: check)) {
    throw StateError('Game rankings unavailable.');
  }
  check();
  final client = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
    client.useFunctionsEmulator(
        const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
            defaultValue: '10.0.2.2'),
        5001);
  }
  final result = await client
      .httpsCallable('miniGameRoundCommand',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 10)))
      .call<Map<String, dynamic>>(input);
  check();
  return result.data;
}
