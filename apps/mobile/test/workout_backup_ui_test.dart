import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/workout_backup_coordinator.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_backup_screen.dart';
import 'workout_backup_test.dart' as support;

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
    expect(find.text('Saved locally'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('No video'), findsOneWidget);
    expect(meta.state.enabled, false);
    await tester.tap(find.text('Enable backup'));
    await tester.pumpAndSettle();
    expect(meta.state.enabled, true);
    expect(find.text('Backed up'), findsOneWidget);
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
