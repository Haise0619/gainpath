import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_save_indicator.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/workout_backup_coordinator.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'routine_journey_controller_test.dart' as fixture;
import 'workout_backup_test.dart' as support;

class FailingPreferenceStore extends support.Metadata {
  FailingPreferenceStore(super.scope);
  @override
  Future<void> write(BackupState state) async => throw StateError('disk full');
}

void main() {
  test('failed preference write cannot leave automatic sync enabled in memory',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final metadata = FailingPreferenceStore(scope);
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => scope,
        local: support.Local(),
        gateway: support.Remote(),
        store: metadata);
    await c.load();
    await expectLater(c.setEnabled(true), throwsStateError);
    expect(c.state.enabled, false);
    expect(metadata.state.enabled, false);
    c.dispose();
  });
  testWidgets(
      'save indicator reports each cloud state without verification claims',
      (tester) async {
    for (final item in [
      (BackupRecordStatus.localOnly, 'Saved on this device'),
      (BackupRecordStatus.pendingBackup, 'Saved on this device'),
      (BackupRecordStatus.syncing, 'Syncing'),
      (BackupRecordStatus.backedUp, 'Synced'),
      (BackupRecordStatus.retryNeeded, 'Sync failed — Retry'),
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: WorkoutSaveIndicator(status: item.$1))));
      await tester.pumpAndSettle();
      expect(find.text(item.$2), findsOneWidget);
      expect(find.textContaining('accepted'), findsNothing);
    }
  });
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  final row = WorkoutBackupRecord.session(fixture.measured(scope, 'saved'));
  test('turning sync off retains confirmation for unchanged current content',
      () async {
    final local = support.Local()..rows[row.key] = row;
    final metadata = support.Metadata(scope)
      ..state = BackupState(enabled: true, baselines: {row.key: row.digest});
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => scope,
        local: local,
        gateway: support.Remote(),
        store: metadata);
    await c.load();
    await c.setEnabled(false);
    expect(c.statusFor(row), BackupRecordStatus.backedUp);
    final changed =
        WorkoutBackupRecord.session(fixture.measured(scope, 'saved', reps: 1));
    expect(c.statusFor(changed), BackupRecordStatus.localOnly);
    c.dispose();
  });
  test('new sync setup and existing disabled choice remain distinguishable',
      () {
    expect(BackupState().toJson()['consentChoiceMade'], false);
    final old = Map<String, dynamic>.from(BackupState().toJson())
      ..remove('consentChoiceMade');
    final restored = BackupState.fromJson(old);
    expect(restored.enabled, false);
    expect(restored.toJson()['consentChoiceMade'], true);
  });
  test('confirmed save has a consumer sync label', () async {
    final metadata = support.Metadata(scope)
      ..state = BackupState(enabled: true);
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => scope,
        local: support.Local()..rows[row.key] = row,
        gateway: support.Remote(),
        store: metadata);
    await c.load();
    await c.sync();
    expect(c.label, 'Synced');
    c.dispose();
  });
}
