import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/workout_backup.dart';

class FirebaseWorkoutBackupGateway implements WorkoutBackupGateway {
  FirebaseWorkoutBackupGateway(
      {required this.scope,
      Future<Object?> Function(Map<String, Object?>)? invoke,
      bool Function()? activeAccount}) {
    _active = activeAccount ??
        () =>
            FirebaseAuth.instance.currentUser?.uid == scope.userId &&
            FirebaseAuth.instance.currentUser?.emailVerified == true;
    _invoke = invoke ??
        (payload) async {
          final functions =
              FirebaseFunctions.instanceFor(region: 'asia-southeast1');
          if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
            functions.useFunctionsEmulator(
                const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
                    defaultValue: '10.0.2.2'),
                5001);
          }
          return (await functions
                  .httpsCallable('workoutBackupCommand',
                      options: HttpsCallableOptions(
                          timeout: const Duration(seconds: 30)))
                  .call<Object?>(payload))
              .data;
        };
  }
  final SessionScope scope;
  late final bool Function() _active;
  late final Future<Object?> Function(Map<String, Object?>) _invoke;
  Future<Map<String, dynamic>> _call(
      String action, Map<String, Object?> command) async {
    if (!_active()) throw const BackupFailure('permission-denied');
    try {
      final raw = await _invoke({
        'action': action,
        'command': {
          'schemaVersion': 1,
          'organizationId': scope.organizationId,
          'memberId': scope.userId,
          'consented': true,
          ...command
        }
      }).timeout(const Duration(seconds: 35));
      if (!_active()) throw const BackupFailure('permission-denied');
      if (raw is! Map) throw const FormatException('Invalid backup response');
      final data = Map<String, dynamic>.from(raw);
      if (data['schemaVersion'] != 1) {
        throw const FormatException('Invalid backup version');
      }
      return data;
    } on FirebaseFunctionsException catch (e) {
      throw BackupFailure(e.code);
    } on TimeoutException {
      throw const BackupFailure('deadline-exceeded');
    }
  }

  @override
  Future<String> save(WorkoutBackupRecord record, String? baseDigest) async {
    WorkoutBackupRecord.parse(record.kind, record.id, record.payload, scope);
    final data = await _call('save', {
      'kind': record.kind,
      'id': record.id,
      'baseDigest': baseDigest,
      'payload': record.payload
    });
    if (data.length != 5 ||
        data['status'] != 'backed_up' ||
        data['kind'] != record.kind ||
        data['id'] != record.id ||
        data['digest'] != record.digest) {
      throw const FormatException('Invalid backup receipt');
    }
    return data['digest'] as String;
  }

  @override
  Future<WorkoutBackupPage> list(String? cursor) async {
    final data = await _call('list', {
      'after': cursor,
      'maxPoseMetricsSchemaVersion': 6,
    });
    final raw = data['records'], next = data['nextCursor'];
    if (data.length != 3 ||
        raw is! List ||
        raw.length > 3 ||
        (next != null &&
            next != 'routines' &&
            (next is! String ||
                !RegExp(r'^(session|routine)-[A-Za-z0-9_-]{1,128}$')
                    .hasMatch(next)))) {
      throw const FormatException('Invalid backup page');
    }
    final rows = raw.map((r) {
      final value = Map<String, dynamic>.from(r as Map);
      if (value.length != 4) {
        throw const FormatException('Invalid backup record');
      }
      final record = WorkoutBackupRecord.parse(
          value['kind'] as String,
          value['id'] as String,
          Map<String, dynamic>.from(value['payload'] as Map),
          scope);
      if (record.digest != value['digest']) {
        throw const FormatException('Backup integrity failed');
      }
      return record;
    }).toList();
    return WorkoutBackupPage(rows, next as String?);
  }
}
