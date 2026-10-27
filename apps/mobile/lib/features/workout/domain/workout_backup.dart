import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'workout_contracts.dart';
import 'routine_journey.dart';

/// Cross-runtime canonical digest encoding. IEEE-754 bytes avoid differences
/// between JavaScript and Dart's decimal/exponent JSON formatting.
String backupCanonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${backupCanonical(value[k])}').join(',')}}';
  }
  if (value is List) return '[${value.map(backupCanonical).join(',')}]';
  if (value is num) {
    if (!value.isFinite) throw const FormatException('Invalid backup number');
    final bytes = ByteData(8)
      ..setFloat64(0, value == 0 ? 0 : value.toDouble(), Endian.big);
    return 'n${bytes.buffer.asUint8List().map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
  return jsonEncode(value);
}

class WorkoutBackupRecord {
  WorkoutBackupRecord._(this.kind, this.id, this.payload);
  final String kind, id;
  final Map<String, dynamic> payload;
  String get key => '$kind-$id';
  List<String> get linkedSessionKeys => kind == 'routine'
      ? (payload['sessions'] as Map)
          .values
          .expand((value) => (value as List).cast<String>())
          .map((id) => 'session-$id')
          .toList()
      : const [];
  String get digest =>
      sha256.convert(utf8.encode(backupCanonical(payload))).toString();
  factory WorkoutBackupRecord.session(WorkoutSessionSummary s) =>
      WorkoutBackupRecord.parse('session', s.sessionId,
          Map<String, dynamic>.from(s.toJson()), s.scope);
  factory WorkoutBackupRecord.routine(RoutineCheckpoint c) =>
      WorkoutBackupRecord.parse(
          'routine', c.id, Map<String, dynamic>.from(c.toJson()), c.scope);
  factory WorkoutBackupRecord.parse(
      String kind, String id, Map<String, dynamic> raw, SessionScope scope) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw const FormatException('Invalid backup identity');
    }
    Map<String, dynamic> payload;
    if (kind == 'session') {
      final s = WorkoutSessionSummary.fromJson(raw);
      if (s.scope != scope ||
          s.sessionId != id ||
          s.provenance != WorkoutProvenance.realCamera ||
          s.poseMetrics == null) {
        throw const FormatException('Invalid backup summary');
      }
      payload = Map<String, dynamic>.from(s.toJson());
    } else if (kind == 'routine') {
      final c = RoutineCheckpoint.fromJson(raw);
      if (c.scope != scope || c.id != id || c.attempt == null) {
        throw const FormatException('Invalid backup routine');
      }
      payload = Map<String, dynamic>.from(c.toJson());
    } else {
      throw const FormatException('Invalid backup kind');
    }
    if (utf8.encode(backupCanonical(payload)).length > 850000) {
      throw const FormatException('Backup record is too large');
    }
    return WorkoutBackupRecord._(kind, id, Map.unmodifiable(payload));
  }
}

class BackupFailure implements Exception {
  const BackupFailure(this.code);
  final String code;
}

class WorkoutBackupPage {
  const WorkoutBackupPage(this.records, this.nextCursor);
  final List<WorkoutBackupRecord> records;
  final String? nextCursor;
}

abstract interface class WorkoutBackupGateway {
  Future<WorkoutBackupPage> list(String? cursor);
  Future<String> save(WorkoutBackupRecord record, String? baseDigest);
}

abstract interface class WorkoutBackupLocal {
  Future<List<WorkoutBackupRecord>> read();
  Future<bool> restore(WorkoutBackupRecord record, String? expectedDigest);
}

enum BackupRecordStatus { localOnly, syncing, backedUp, retryNeeded, conflict }

class BackupState {
  BackupState(
      {this.enabled = false,
      Map<String, String> baselines = const {},
      Map<String, String> conflicts = const {},
      this.lastError,
      this.lastSuccessMillis})
      : baselines = Map.unmodifiable(baselines),
        conflicts = Map.unmodifiable(conflicts);
  final bool enabled;
  final Map<String, String> baselines, conflicts;
  final String? lastError;
  final int? lastSuccessMillis;
  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'enabled': enabled,
        'baselines': baselines,
        'conflicts': conflicts,
        'lastError': lastError,
        'lastSuccessMillis': lastSuccessMillis
      };
  factory BackupState.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 || json['enabled'] is! bool) {
      throw const FormatException('Invalid backup state');
    }
    Map<String, String> hashes(String key) {
      final raw = json[key];
      if (raw is! Map || raw.length > 20000) {
        throw const FormatException('Invalid backup metadata');
      }
      final values = Map<String, String>.from(raw);
      if (values.entries.any((e) =>
          !RegExp(r'^(session|routine)-[A-Za-z0-9_-]{1,128}$')
              .hasMatch(e.key) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(e.value))) {
        throw const FormatException('Invalid backup digest');
      }
      return values;
    }

    final time = json['lastSuccessMillis'], error = json['lastError'];
    if ((time != null && (time is! int || time < 0)) ||
        (error != null && (error is! String || error.length > 80))) {
      throw const FormatException('Invalid backup status');
    }
    return BackupState(
        enabled: json['enabled'] as bool,
        baselines: hashes('baselines'),
        conflicts: hashes('conflicts'),
        lastError: error as String?,
        lastSuccessMillis: time as int?);
  }
}

abstract interface class WorkoutBackupStore {
  SessionScope get scope;
  Future<BackupState> read();
  Future<void> write(BackupState state);
}
