import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import '../../features/workout/domain/program_enrollment.dart';
import 'firebase_app_check_readiness.dart';

class FirebaseWorkoutProgramCatalog implements WorkoutProgramCatalog {
  FirebaseWorkoutProgramCatalog(
      {required this.scope,
      required this.activeScope,
      FirebaseFunctions? functions,
      FirebaseAuth? auth,
      FirebaseAppCheckReadiness? readiness,
      bool Function()? activeAccount,
      Future<Object?> Function(Map<String, Object?>)? invoke}) {
    _readiness = readiness ??
        (invoke == null ? FirebaseAppCheckReadiness.instance : null);
    _activeAccount = activeAccount ??
        () =>
            (auth ?? FirebaseAuth.instance).currentUser?.uid == scope.userId &&
            (auth ?? FirebaseAuth.instance).currentUser?.emailVerified == true;
    _invoke = invoke ??
        (payload) async {
          final service = functions ??
              FirebaseFunctions.instanceFor(region: 'asia-southeast1');
          if (functions == null &&
              const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
            service.useFunctionsEmulator(
                const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
                    defaultValue: '10.0.2.2'),
                5001);
          }
          return (await service
                  .httpsCallable('workoutProgramCommand',
                      options: HttpsCallableOptions(
                          timeout: const Duration(seconds: 30)))
                  .call<Object?>(payload))
              .data;
        };
  }
  @override
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  late final Future<Object?> Function(Map<String, Object?>) _invoke;
  late final bool Function() _activeAccount;
  late final FirebaseAppCheckReadiness? _readiness;
  void _guard() {
    if (!_activeAccount() || activeScope() != scope) {
      throw StateError('Program account changed');
    }
  }

  @override
  Future<List<WorkoutProgram>> load() async {
    _guard();
    final readiness = _readiness;
    if (readiness != null && !await readiness.ensureReady(check: _guard)) {
      throw StateError('App verification is unavailable. Retry programs.');
    }
    _guard();
    final data = await _invoke({
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'action': 'list'
    });
    _guard();
    if (data is! Map ||
        data['programs'] is! List ||
        (data['programs'] as List).length > 100) {
      throw const FormatException('Invalid program catalog');
    }
    final programs = (data['programs'] as List).map((raw) {
      final program =
          WorkoutProgram.fromJson(Map<String, dynamic>.from(raw as Map));
      program.validate(published: true);
      return program;
    }).toList();
    if (programs.map((p) => p.id).toSet().length != programs.length) {
      throw const FormatException('Duplicate program catalog entries');
    }
    return List.unmodifiable(programs);
  }
}
