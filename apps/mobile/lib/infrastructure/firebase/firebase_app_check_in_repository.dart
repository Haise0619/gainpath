import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/gamification/domain/app_check_in.dart';

class FirebaseAppCheckInRepository implements AppCheckInRepository {
  FirebaseAppCheckInRepository(
      {required this.scope,
      required this.activeScope,
      Future<Object?> Function(Map<String, Object?>)? invoke}) {
    _invoke = invoke ??
        (data) async {
          final functions =
              FirebaseFunctions.instanceFor(region: 'asia-southeast1');
          if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
            functions.useFunctionsEmulator(
                const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
                    defaultValue: '10.0.2.2'),
                5001);
          }
          if (FirebaseAuth.instance.currentUser?.uid != scope.userId) {
            throw StateError('Check-in identity changed');
          }
          return (await functions
                  .httpsCallable('appCheckInCommand',
                      options: HttpsCallableOptions(
                          timeout: const Duration(seconds: 20)))
                  .call<Object?>(data))
              .data;
        };
  }
  @override
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  late final Future<Object?> Function(Map<String, Object?>) _invoke;
  Future<AppCheckInResult> _call(String action) async {
    if (activeScope() != scope) throw StateError('Check-in account changed');
    final raw = await _invoke({
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'action': action
    }).timeout(const Duration(seconds: 25));
    if (activeScope() != scope) throw StateError('Check-in account changed');
    if (raw is! Map ||
        raw.length != 2 ||
        raw['awarded'] is! bool ||
        raw['snapshot'] is! Map ||
        (action == 'overview' && raw['awarded'] != false)) {
      throw const FormatException('Invalid check-in response');
    }
    return AppCheckInResult(
        AppCheckInSnapshot.fromJson(
            Map<String, dynamic>.from(raw['snapshot'] as Map), scope),
        awarded: raw['awarded'] as bool);
  }

  @override
  Future<AppCheckInResult> overview() => _call('overview');
  @override
  Future<AppCheckInResult> claim() => _call('claim');
}
