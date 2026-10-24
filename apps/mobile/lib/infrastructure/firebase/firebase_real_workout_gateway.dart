import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/real_workout_contract.dart';
import '../../features/workout/domain/real_workout_sync.dart';
import 'firebase_function_transport.dart';

/// Callable transport; local parsing never grants server acceptance.
class FirebaseRealWorkoutGateway implements RealWorkoutGateway {
  FirebaseRealWorkoutGateway(
      {required this.scope,
      Future<Object?> Function(String, Map<String, Object?>)? invoke,
      bool Function()? activeAccount,
      FirebaseFunctions? functions,
      FirebaseAuth? auth}) {
    if (invoke != null) {
      _invoke = invoke;
    } else {
      _invoke = (name, payload) async => (await firebaseCallable(name,
                  functions: functions,
                  options: HttpsCallableOptions(
                      timeout: const Duration(seconds: 20)))
              .call<Object?>(payload))
          .data;
    }
    if (activeAccount != null) {
      _activeAccount = activeAccount;
    } else {
      final identity = auth ?? FirebaseAuth.instance;
      _activeAccount = () =>
          identity.currentUser?.uid == scope.userId &&
          identity.currentUser?.emailVerified == true;
    }
  }
  final SessionScope scope;
  late final Future<Object?> Function(String, Map<String, Object?>) _invoke;
  late final bool Function() _activeAccount;
  void _check(SessionScope requested) {
    if (requested != scope || !_activeAccount()) {
      throw const WorkoutGatewayFailure('permission-denied');
    }
  }

  Future<Map<String, Object?>> _call(
      String name, Map<String, Object?> payload) async {
    _check(scope);
    try {
      final result =
          await _invoke(name, payload).timeout(const Duration(seconds: 20));
      _check(scope);
      if (result is! Map) {
        throw const FormatException('Invalid workout response.');
      }
      return Map<String, Object?>.from(result);
    } on FirebaseFunctionsException catch (e) {
      throw WorkoutGatewayFailure(e.code);
    } on TimeoutException {
      throw const WorkoutGatewayFailure('deadline-exceeded');
    }
  }

  @override
  Future<WorkoutConsentAcknowledgement> acknowledge(
      SessionScope requested, String requestId) async {
    _check(requested);
    final result = WorkoutConsentAcknowledgement.fromJson(
        await _call('acknowledgeWorkoutConsentCommand', {
      'schemaVersion': 1,
      'requestId': requestId,
      'organizationId': scope.organizationId,
      'memberId': scope.userId,
      'consentVersion': workoutConsentVersion,
      'consented': true
    }));
    if (result.scope != scope || result.requestId != requestId) {
      throw const FormatException('Consent identity mismatch.');
    }
    return result;
  }

  @override
  Future<void> revoke(
      WorkoutConsentAcknowledgement ack, String requestId) async {
    _check(ack.scope);
    final payload = <String, Object?>{
      'schemaVersion': 1,
      'requestId': requestId,
      'organizationId': scope.organizationId,
      'memberId': scope.userId,
      'consentVersion': workoutConsentVersion,
      'acknowledgementId': ack.acknowledgementId
    };
    final result = await _call('revokeWorkoutConsentCommand', payload);
    final time = result['revokedAtMillis'];
    if (result.length != payload.length + 1 ||
        !payload.entries.every((e) => result[e.key] == e.value) ||
        time is! int ||
        time < ack.acknowledgedAtMillis ||
        time > 8639999996400000) {
      throw const FormatException('Invalid consent revocation receipt.');
    }
  }

  @override
  Future<WorkoutAcceptance> submit(RealWorkoutSubmission submission) async {
    _check(submission.scope);
    final acceptance = WorkoutAcceptance.fromJson(
        await _call('submitWorkoutSessionCommand', submission.toJson()));
    if (!acceptance.matches(submission)) {
      throw const FormatException('Workout acceptance identity mismatch.');
    }
    return acceptance;
  }
}
