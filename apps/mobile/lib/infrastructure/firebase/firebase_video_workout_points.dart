import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_app_check_readiness.dart';
import 'firebase_booking_repository.dart';

const workoutExercisePointsEnabled =
    bool.fromEnvironment('WORKOUT_EXERCISE_POINTS_ENABLED');

class FirebaseVideoWorkoutPoints {
  FirebaseVideoWorkoutPoints(
      {required SessionScope scope, required bool Function() isCurrent})
      : _transport =
            BookingTransport(scope: scope, isCurrent: isCurrent, call: _call);

  final BookingTransport _transport;

  static Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> data) async {
    final firebase = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      firebase.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '10.0.2.2'),
          const int.fromEnvironment('FIREBASE_FUNCTIONS_EMULATOR_PORT',
              defaultValue: 5001));
    }
    return (await firebase
            .httpsCallable(name,
                options:
                    HttpsCallableOptions(timeout: const Duration(seconds: 12)))
            .call<Map<String, dynamic>>(data))
        .data;
  }

  Future<({String status, int waitMillis})> send({
    required bool finish,
    required String routineId,
    required String entryId,
    required String runId,
    required int set,
  }) async {
    if (!await FirebaseAppCheckReadiness.instance
        .ensureReady(check: _transport.check)) {
      throw StateError('App verification unavailable');
    }
    final scope = _transport.scope;
    final result = await _transport.call('verifiedRewardsCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'action': finish ? 'finishVideoWorkoutSet' : 'beginVideoWorkoutSet',
      'routineId': routineId,
      'entryId': entryId,
      'runId': runId,
      'set': set,
    });
    final status = result['status'];
    final wait = result['waitMillis'];
    if (result['schemaVersion'] != 1 ||
        result['memberId'] != scope.userId ||
        result['organizationId'] != scope.organizationId ||
        !const {
          'started',
          'set_completed',
          'awarded',
          'already_awarded',
          'too_early'
        }.contains(status) ||
        wait is! int ||
        wait < 0 ||
        result['points'] !=
            (status == 'awarded' || status == 'already_awarded' ? 5 : 0)) {
      throw const FormatException('Invalid workout points confirmation');
    }
    return (status: status as String, waitMillis: wait);
  }
}
