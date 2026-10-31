import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'package:gainpath_mobile/features/workout/application/workout_backup_coordinator.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_backup_screen.dart';
import 'workout_backup_test.dart' as support;

class _BlockedRemote extends support.Remote {
  final pending = Completer<WorkoutBackupPage>();
  @override
  Future<WorkoutBackupPage> list(String? cursor) => pending.future;
}

void main() {
  testWidgets(
      'backup opt-in describes summaries and explicit agreement starts sync',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath'),
        local = support.Local(),
        remote = support.Remote(),
        meta = support.Metadata(
            SessionScope(userId: 'member', organizationId: 'gainpath'));
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => scope,
        local: local,
        gateway: remote,
        store: meta);
    await c.load();
    await tester
        .pumpWidget(MaterialApp(home: WorkoutBackupScreen(coordinator: c)));
    expect(find.text('Saved on device'), findsOneWidget);
    expect(find.text('Sync now'), findsNothing);
    expect(find.text('Retry now'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('No video or raw landmarks'), findsOneWidget);
    expect(find.textContaining('Program enrollment'), findsOneWidget);
    expect(meta.state.enabled, false);
    await tester.tap(find.text('Enable backup'));
    await tester.pumpAndSettle();
    expect(meta.state.enabled, true);
    expect(find.text('Backed up'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('offline backup preserves results and offers optional retry',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final local = support.Local();
    final remote = support.Remote()..offline = true;
    final meta = support.Metadata(scope);
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => scope,
        local: local,
        gateway: remote,
        store: meta);
    await c.load();
    await c.setEnabled(true);
    await tester
        .pumpWidget(MaterialApp(home: WorkoutBackupScreen(coordinator: c)));
    expect(find.text('Retry needed'), findsOneWidget);
    expect(find.text('Retry now'), findsOneWidget);
    expect(find.textContaining('automatically'), findsWidgets);
    expect(find.textContaining('local results are retained'), findsOneWidget);
    remote.offline = false;
    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();
    expect(find.text('Backed up'), findsOneWidget);
    expect(find.text('Retry now'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(meta.state.enabled, false);
    expect(find.text('Saved on device'), findsOneWidget);
    expect(find.text('Retry now'), findsNothing);
    expect(find.textContaining('does not delete'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('turning backup off remains available during automatic sync',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final remote = _BlockedRemote();
    final meta = support.Metadata(scope);
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => scope,
        local: support.Local(),
        gateway: remote,
        store: meta);
    await c.load();
    final sync = c.setEnabled(true);
    await tester
        .pumpWidget(MaterialApp(home: WorkoutBackupScreen(coordinator: c)));
    expect(c.busy, true);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(meta.state.enabled, false);
    remote.pending.complete(const WorkoutBackupPage([], null));
    await sync;
    await tester.pumpAndSettle();
    expect(find.text('Saved on device'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('canceling first consent does not enable automatic backup',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final remote = support.Remote();
    final meta = support.Metadata(scope);
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => scope,
        local: support.Local(),
        gateway: remote,
        store: meta);
    await c.load();
    await tester
        .pumpWidget(MaterialApp(home: WorkoutBackupScreen(coordinator: c)));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(meta.state.enabled, false);
    expect(remote.saves, 0);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('disabled production release never offers an upload control',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkoutBackupScreen()));
    expect(find.text('Cloud backup awaiting activation'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('device'), findsWidgets);
  });
}
