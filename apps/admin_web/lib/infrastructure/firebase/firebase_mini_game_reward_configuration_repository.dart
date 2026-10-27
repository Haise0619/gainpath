import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

bool _verified(SessionScope scope) {
  try {
    final u = FirebaseAuth.instance.currentUser;
    return u?.uid == scope.userId && u?.emailVerified == true;
  } catch (_) {
    return false;
  }
}

Future<Map<String, dynamic>> _call(Map<String, dynamic> input) async {
  try {
    final client = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      client.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '127.0.0.1'),
          5001);
    }
    return (await client
            .httpsCallable('miniGameRewardsCommand')
            .call<Map<String, dynamic>>(input))
        .data;
  } on FirebaseFunctionsException catch (e) {
    if (e.code == 'aborted') throw const MiniGameRewardConflict();
    if (e.code == 'unauthenticated') throw const MiniGameRewardSessionChanged();
    throw const MiniGameRewardUnavailable();
  }
}

class FirebaseMiniGameRewardConfigurationRepository
    extends RemoteMiniGameRewardConfigurationRepository {
  FirebaseMiniGameRewardConfigurationRepository(
      {required super.scope,
      required bool Function() isCurrent,
      bool Function()? verifiedSession,
      MiniGameContentCall? call})
      : super(
            isCurrent: () =>
                isCurrent() && (verifiedSession?.call() ?? _verified(scope)),
            call: call ?? _call);
}
