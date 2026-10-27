import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

bool _verified(SessionScope scope) {
  try {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid == scope.userId && user?.emailVerified == true;
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
            .httpsCallable('miniGameContentCommand',
                options:
                    HttpsCallableOptions(timeout: const Duration(seconds: 90)))
            .call<Map<String, dynamic>>(input))
        .data;
  } on FirebaseFunctionsException catch (error) {
    if (error.code == 'aborted') throw const MiniGameContentConflict();
    if (error.code == 'unauthenticated') {
      throw const MiniGameContentSessionChanged();
    }
    if (input['action'] == 'uploadMedia') {
      throw MiniGameContentUploadFailed(code: error.code);
    }
    if (error.code == 'invalid-argument') {
      throw const FormatException('Invalid mini-game content.');
    }
    throw const MiniGameContentUnavailable();
  }
}

class FirebaseMiniGameContentRepository
    extends RemoteMiniGameContentRepository {
  FirebaseMiniGameContentRepository(
      {required super.scope,
      required bool Function() isCurrent,
      bool Function()? verifiedSession,
      MiniGameContentCall? call})
      : super(
            isCurrent: () =>
                isCurrent() && (verifiedSession?.call() ?? _verified(scope)),
            call: call ?? _call);
}
