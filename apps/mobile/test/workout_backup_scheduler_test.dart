import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/workout_backup_coordinator.dart';
import 'package:gainpath_mobile/features/workout/application/workout_backup_scheduler.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'workout_backup_test.dart' as support;
import 'routine_journey_controller_test.dart' as fixture;

class DelayedRemote extends support.Remote {
  Completer<void>? gate;
  Completer<void>? saveGate;
  int lists = 0;
  bool rejectSave = false;
  int saveAttempts = 0;
  @override
  Future<WorkoutBackupPage> list(String? cursor) async {
    lists++;
    await gate?.future;
    return super.list(cursor);
  }

  @override
  Future<String> save(WorkoutBackupRecord record, String? base) async {
    saveAttempts++;
    await saveGate?.future;
    if (rejectSave) throw const BackupFailure('already-exists');
    return super.save(record, base);
  }
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  late support.Local local;
  late DelayedRemote remote;
  late support.Metadata metadata;
  late WorkoutBackupCoordinator coordinator;
  late WorkoutBackupScheduler scheduler;
  SessionScope? active;
  WorkoutBackupRecord record(String id) =>
      WorkoutBackupRecord.session(fixture.measured(scope, id));
  setUp(() {
    active = scope;
    local = support.Local();
    remote = DelayedRemote();
    metadata = support.Metadata(scope)..state = BackupState(enabled: true);
    coordinator = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => active,
        local: local,
        gateway: remote,
        store: metadata);
    scheduler = WorkoutBackupScheduler(
        coordinator: coordinator,
        debounce: const Duration(milliseconds: 10),
        retryDelays: const [
          Duration(milliseconds: 20),
          Duration(milliseconds: 40)
        ]);
  });
  tearDown(() {
    scheduler.dispose();
    coordinator.dispose();
  });

  testWidgets(
      'startup discovers durable opted-in rows without screen navigation',
      (tester) async {
    local.rows['session-one'] = record('one');
    scheduler.opportunity();
    await tester.pump(const Duration(milliseconds: 10));
    expect(remote.saves, 1);
    expect(coordinator.statusFor(record('one')), BackupRecordStatus.backedUp);
  });
  testWidgets('disabled consent remains local across automatic opportunities',
      (tester) async {
    metadata.state = BackupState();
    local.rows['session-one'] = record('one');
    scheduler.localChanged();
    scheduler.opportunity();
    await tester.pump(const Duration(seconds: 1));
    expect(remote.lists, 0);
    expect(metadata.state.enabled, false);
  });
  testWidgets(
      'offline retries are bounded and foreground rediscoveries resume queue',
      (tester) async {
    local.rows['session-one'] = record('one');
    remote.offline = true;
    scheduler.opportunity();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump(const Duration(seconds: 2));
    expect(remote.lists, 3);
    expect(
        coordinator.statusFor(record('one')), BackupRecordStatus.retryNeeded);
    scheduler.setForeground(false);
    remote.offline = false;
    scheduler.setForeground(true);
    await tester.pump(const Duration(milliseconds: 10));
    expect(remote.saves, 1);
  });
  testWidgets(
      'rapid duplicate opportunities coalesce without duplicate uploads',
      (tester) async {
    local.rows['session-one'] = record('one');
    for (var i = 0; i < 20; i++) {
      scheduler.localChanged();
      scheduler.opportunity();
    }
    await tester.pump(const Duration(milliseconds: 10));
    expect(remote.lists, 1);
    expect(remote.saves, 1);
  });
  testWidgets('local save during in-flight sync is drained after completion',
      (tester) async {
    local.rows['session-one'] = record('one');
    remote.gate = Completer<void>();
    scheduler.opportunity();
    await tester.pump(const Duration(milliseconds: 10));
    expect(coordinator.busy, true);
    local.rows['session-two'] = record('two');
    scheduler.localChanged();
    remote.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(remote.records.keys, containsAll(['session-one', 'session-two']));
    expect(remote.saves, 2);
    expect(remote.lists, 2);
  });
  testWidgets('account switch during remote read never restores or uploads',
      (tester) async {
    local.rows['session-one'] = record('one');
    remote.gate = Completer<void>();
    scheduler.opportunity();
    await tester.pump(const Duration(milliseconds: 10));
    active = null;
    coordinator.accountChanged();
    remote.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(remote.saves, 0);
    expect(coordinator.records, isEmpty);
    expect(remote.lists, 1);
  });
  testWidgets('conflicts remain explicit and never trigger retry storms',
      (tester) async {
    remote.records['session-one'] = record('one');
    local.rows['session-one'] =
        WorkoutBackupRecord.session(fixture.measured(scope, 'one', reps: 1));
    scheduler.opportunity();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(coordinator.statusFor(local.rows['session-one']!),
        BackupRecordStatus.conflict);
    expect(remote.saves, 0);
    expect(remote.lists, 1);
  });
  testWidgets('background cancels scheduled network work until foreground',
      (tester) async {
    local.rows['session-one'] = record('one');
    scheduler.opportunity();
    scheduler.setForeground(false);
    await tester.pump(const Duration(seconds: 1));
    expect(remote.lists, 0);
    scheduler.setForeground(true);
    await tester.pump(const Duration(milliseconds: 10));
    expect(remote.saves, 1);
  });
  testWidgets('turning backup off during flight stops remaining uploads',
      (tester) async {
    local.rows['session-one'] = record('one');
    local.rows['session-two'] = record('two');
    remote.saveGate = Completer<void>();
    scheduler.opportunity();
    await tester.pump(const Duration(milliseconds: 10));
    expect(coordinator.busy, true);
    await coordinator.setEnabled(false);
    remote.saveGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(metadata.state.enabled, false);
    expect(remote.saves, 1); // The issued request may complete; no next upload.
    expect(local.rows.length, 2);
  });
  testWidgets('new save after upload snapshot triggers a second pass',
      (tester) async {
    local.rows['session-one'] = record('one');
    remote.saveGate = Completer<void>();
    scheduler.opportunity();
    await tester.pump(const Duration(milliseconds: 10));
    local.rows['session-two'] = record('two');
    scheduler.localChanged();
    remote.saveGate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(remote.records.keys, containsAll(['session-one', 'session-two']));
    expect(remote.saves, 2);
  });
  testWidgets('account change during conflicting upload blocks next row',
      (tester) async {
    local.rows['session-one'] = record('one');
    local.rows['session-two'] = record('two');
    remote.saveGate = Completer<void>();
    remote.rejectSave = true;
    scheduler.opportunity();
    await tester.pump(const Duration(milliseconds: 10));
    active = null;
    coordinator.accountChanged();
    remote.saveGate!.complete();
    await tester.pump();
    expect(remote.saveAttempts, 1);
  });
}
