import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, BookingException;
import '../../features/workout/domain/workout_rewards.dart';
import 'firebase_app_check_readiness.dart';
import 'firebase_booking_repository.dart';

/// Prepared status-only adapter. Normal routine completion never composes it;
/// workoutRewardCommand remains unreleased and cannot activate earning.
class FirebaseWorkoutRewardsRepository
    implements WorkoutRewardStatusRepository {
  FirebaseWorkoutRewardsRepository(
      {required SessionScope scope,
      required bool Function() isCurrent,
      String? Function()? currentUid,
      BookingCallable? call,
      FirebaseAppCheckReadiness? readiness})
      : _transport = BookingTransport(
            scope: scope,
            isCurrent: isCurrent,
            currentUid: currentUid,
            call: call ?? _singaporeCall),
        _readiness = readiness ?? FirebaseAppCheckReadiness.instance;
  final BookingTransport _transport;
  final FirebaseAppCheckReadiness _readiness;
  static Future<Map<String, dynamic>> _singaporeCall(
      String name, Map<String, dynamic> input) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      functions.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '10.0.2.2'),
          5001);
    }
    return (await functions
            .httpsCallable(name)
            .call<Map<String, dynamic>>(input))
        .data;
  }

  @override
  bool get current {
    try {
      _transport.check();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<WorkoutRewardStatus> status(
      WorkoutRewardAttemptReference attempt) async {
    _transport.check();
    if (attempt.scope != _transport.scope) {
      throw const BookingException('permission-denied');
    }
    final reference = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    if (attempt.day > 14 ||
        !reference.hasMatch(attempt.attemptId) ||
        !reference.hasMatch(attempt.routineId)) {
      throw const BookingException('invalid-argument');
    }
    if (!await _readiness.ensureReady(check: _transport.check)) {
      throw const BookingException('app-check-unavailable');
    }
    final result =
        await _transport.call('workoutRewardCommand', attempt.toStatusFields());
    try {
      if (result['schemaVersion'] != 1 ||
          result['organizationId'] != _transport.scope.organizationId ||
          result['memberId'] != _transport.scope.userId ||
          result['status'] != 'disabled' ||
          result['reason'] != 'physical_validation_required' ||
          result['policyVersion'] is! String ||
          (result['policyVersion'] as String).trim().isEmpty ||
          (result['policyVersion'] as String).length > 128 ||
          result['draftPoints'] is! int ||
          (result['draftPoints'] as int) > 100000) {
        throw const FormatException('Invalid disabled workout reward status.');
      }
      return WorkoutRewardStatus.fromJson(result);
    } on FormatException {
      throw const BookingException('invalid-response');
    } on TypeError {
      throw const BookingException('invalid-response');
    }
  }
}
