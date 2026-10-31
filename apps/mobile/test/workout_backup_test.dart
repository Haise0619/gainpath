import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'package:gainpath_mobile/features/workout/application/workout_backup_coordinator.dart';
import 'routine_journey_controller_test.dart' as fixture;

class Remote implements WorkoutBackupGateway {
  final records = <String, WorkoutBackupRecord>{};
  bool offline = false;
  int saves = 0;
  @override
  Future<WorkoutBackupPage> list(String? cursor) async {
    if (offline) throw const BackupFailure('unavailable');
    return WorkoutBackupPage(records.values.toList(), null);
  }

  @override
  Future<String> save(WorkoutBackupRecord r, String? base) async {
    if (offline) throw const BackupFailure('unavailable');
    final old = records[r.key];
    if (old != null &&
        old.digest != r.digest &&
        (r.kind == 'session' || old.digest != base)) {
      throw const BackupFailure('already-exists');
    }
    saves++;
    records[r.key] = r;
    return r.digest;
  }
}

class Local implements WorkoutBackupLocal {
  final rows = <String, WorkoutBackupRecord>{};
  @override
  Future<List<WorkoutBackupRecord>> read() async => rows.values.toList();
  @override
  Future<bool> restore(WorkoutBackupRecord r, String? expected) async {
    if (rows[r.key]?.digest != expected) return false;
    rows[r.key] = r;
    return true;
  }
}

class Metadata implements WorkoutBackupStore {
  @override
  final SessionScope scope;
  Metadata(this.scope);
  BackupState state = BackupState();
  @override
  Future<BackupState> read() async => state;
  @override
  Future<void> write(BackupState value) async {
    state = value;
  }
}

class FailingMetadata extends Metadata {
  FailingMetadata(super.scope);
  bool fail = true;
  @override
  Future<BackupState> read() async {
    if (fail) throw StateError('storage unavailable');
    return super.read();
  }
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  late Local local;
  late Remote remote;
  late Metadata metadata;
  SessionScope? active;
  WorkoutBackupCoordinator controller() => WorkoutBackupCoordinator(
      scope: scope,
      activeScope: () => active,
      local: local,
      gateway: remote,
      store: metadata);
  WorkoutBackupRecord record() =>
      WorkoutBackupRecord.session(fixture.measured(scope, 's1'));
  setUp(() {
    local = Local();
    remote = Remote();
    metadata = Metadata(scope);
    active = scope;
  });
  test('backup is opt-in and offline retry survives controller restart',
      () async {
    local.rows[record().key] = record();
    final c = controller();
    await c.load();
    await c.sync();
    expect(remote.saves, 0);
    remote.offline = true;
    await c.setEnabled(true);
    expect(metadata.state.enabled, true);
    expect(c.statusFor(record()), BackupRecordStatus.retryNeeded);
    c.dispose();
    remote.offline = false;
    final reopened = controller();
    await reopened.load();
    await reopened.sync();
    expect(remote.records.length, 1);
    expect(reopened.statusFor(record()), BackupRecordStatus.backedUp);
    await reopened.sync();
    expect(remote.saves, 1);
    reopened.dispose();
  });
  test(
      'restore missing session keeps identity and does not create a second record',
      () async {
    remote.records[record().key] = record();
    final c = controller();
    await c.load();
    await c.setEnabled(true);
    expect(local.rows[record().key]!.id, 's1');
    expect(c.statusFor(record()), BackupRecordStatus.backedUp);
    await c.sync();
    expect(local.rows.length, 1);
    c.dispose();
  });
  test('divergent local data is preserved and conflict never silently uploads',
      () async {
    final original = record();
    remote.records[original.key] = original;
    local.rows[original.key] =
        WorkoutBackupRecord.session(fixture.measured(scope, 's1', reps: 1));
    final c = controller();
    await c.load();
    await c.setEnabled(true);
    expect(local.rows[original.key]!.payload['repetitions'], 1);
    expect(c.statusFor(local.rows[original.key]!), BackupRecordStatus.conflict);
    expect(remote.saves, 0);
    c.dispose();
  });
  test('account switch blocks restore and clears visible backup state',
      () async {
    final c = controller();
    await c.load();
    active = null;
    await c.sync();
    expect(c.authorized, false);
    expect(c.state.enabled, false);
    expect(local.rows, isEmpty);
    c.dispose();
  });
  test('failed metadata initialization can be retried without losing consent',
      () async {
    final failing = FailingMetadata(scope)..state = BackupState(enabled: true);
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => active,
        local: local,
        gateway: remote,
        store: failing);
    await expectLater(c.load(), throwsStateError);
    failing.fail = false;
    await c.load();
    expect(c.state.enabled, true);
    c.dispose();
  });
  test('opted-in rows waiting for upload report pending backup', () async {
    metadata.state = BackupState(enabled: true);
    local.rows[record().key] = record();
    final c = controller();
    await c.load();
    expect(c.statusFor(record()), BackupRecordStatus.pendingBackup);
    expect(c.label, 'Pending backup');
    c.dispose();
  });
  test('number normalization produces stable digest across int and double JSON',
      () {
    final a = record();
    final data = Map<String, dynamic>.from(a.payload);
    final m = Map<String, dynamic>.from(data['poseMetrics'] as Map);
    m['formScorePercent'] = 90.0;
    data['poseMetrics'] = m;
    final b = WorkoutBackupRecord.parse('session', 's1', data, scope);
    expect(a.digest, b.digest);
  });
  test('cross-runtime digest preserves small finite scores and signed zero',
      () {
    final value = {'small': 0.000001, 'zero': -0.0, 'integer': 90};
    expect(backupCanonical(value),
        '{"integer":n4056800000000000,"small":n3eb0c6f7a0b5ed8d,"zero":n0000000000000000}');
    expect(sha256.convert(utf8.encode(backupCanonical(value))).toString(),
        '429d8008002cd9d4cfef0cf6bfd58828fd43d35034c83fc24748257d93d1907f');
  });
}
