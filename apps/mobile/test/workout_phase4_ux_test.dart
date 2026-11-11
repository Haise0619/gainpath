import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/presentation/member/routine_history_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_backup_screen.dart';
import 'package:gainpath_mobile/features/workout/application/workout_backup_coordinator.dart';
import 'package:gainpath_mobile/features/analytics/presentation/member/widgets/workout_measurement_scope.dart';
import 'routine_history_ui_test.dart' as history;
import 'routine_journey_controller_test.dart' as journey;
import 'workout_backup_test.dart' as backup;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('attempt exposes only available saved session identities',
      (tester) async {
    final opened = <String>[];
    Widget screen(Set<String> ids) => MaterialApp(
        home: RoutineAttemptDetailScreen(
            attempt: history.attempt(),
            availableSessionIds: ids,
            onOpenSession: opened.add));
    await tester.pumpWidget(screen({}));
    expect(find.text('View saved exercise session'), findsNothing);
    await tester.pumpWidget(screen({'camera', 'unrelated'}));
    await tester.scrollUntilVisible(
        find.text('View saved exercise session'), 180);
    await tester.tap(find.text('View saved exercise session'));
    expect(opened, ['camera']);
    expect(
        find.text('Saved on this device'), findsOneWidget);
  });
  testWidgets(
      'measured summary keeps primary action reachable at 320px and 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var returned = false;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24)),
            child: child!),
        home: WorkoutResultScreen.measured(
            summary: journey.measured(
                SessionScope(userId: 'member', organizationId: 'gainpath'),
                'saved'),
            continueLabel: 'Return to routine',
            onContinue: () => returned = true)));
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.text('Return to routine')).bottom,
        lessThanOrEqualTo(616));
    await tester.tap(find.text('Return to routine'));
    expect(returned, isTrue);
  });
  testWidgets(
      'backup reports an unknown last success without claiming cloud success',
      (tester) async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => scope,
        local: backup.Local(),
        gateway: backup.Remote(),
        store: backup.Metadata(scope));
    await c.load();
    await tester
        .pumpWidget(MaterialApp(home: WorkoutBackupScreen(coordinator: c)));
    expect(find.text('Backup off'), findsOneWidget);
    expect(find.text('No successful backup recorded on this device'),
        findsOneWidget);
    expect(find.textContaining('0 backed up'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('form explanation separates unassessed, timed and manual data',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: WorkoutMeasurementScope(formOnly: true)))));
    await tester.tap(find.text('What these numbers include'));
    await tester.pumpAndSettle();
    expect(find.textContaining('never counted as 0%'), findsOneWidget);
    expect(find.textContaining('Timed and manual activity has no form score'),
        findsOneWidget);
  });
}
