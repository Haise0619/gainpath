import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gamification.dart';

class FirebaseAdminMiniGameCompetitionRepository
    extends RemoteMiniGameCompetitionRepository {
  FirebaseAdminMiniGameCompetitionRepository(
      {required super.scope,
      required bool Function() isCurrent,
      MiniGameContentCall? call})
      : super(
            isCurrent: () =>
                isCurrent() &&
                FirebaseAuth.instance.currentUser?.uid == scope.userId,
            call: call ?? _call);
  static Future<Map<String, dynamic>> _call(Map<String, dynamic> input) async {
    final client = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      client.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '127.0.0.1'),
          5001);
    }
    return (await client
            .httpsCallable('miniGameRoundCommand',
                options:
                    HttpsCallableOptions(timeout: const Duration(seconds: 60)))
            .call<Map<String, dynamic>>(input))
        .data;
  }
}
