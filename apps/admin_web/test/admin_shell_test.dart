import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/app/shells/admin_shell.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_tutorials_screen.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/routine_templates_screen.dart';
import 'support/admin_shell_repositories.dart';
import 'content_removal_ui_test.dart' show Catalog;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'normal launch enables catalog lifecycle and retains routine hold',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestAdminShellRepositories(
        child: RepositoryProvider<TutorialRepository>.value(
            value: Catalog(), child: const MaterialApp(home: AdminShell()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Content').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercise Catalog').first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ExerciseTutorialsScreen>(
                find.byType(ExerciseTutorialsScreen))
            .allowRemoval,
        isTrue);
    await tester.tap(find.text('Routine Templates').first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<RoutineTemplatesScreen>(find.byType(RoutineTemplatesScreen))
            .allowRemoval,
        isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('constrained browser keeps every grouped destination reachable',
      (tester) async {
    tester.view.physicalSize = const Size(680, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestAdminShellRepositories(
        child: RepositoryProvider<TutorialRepository>.value(
            value: Catalog(),
            child: MaterialApp(
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.6)),
                    child: child!),
                home: const AdminShell()))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Content').first);
    await tester.tap(find.text('Content').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mini-games').first);
    await tester.tap(find.text('Mini-games').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mini-game-search')), findsOneWidget);
    expect(find.byKey(const Key('edit-reach-tap-v1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin shell renders full navigation', (tester) async {
    tester.view.physicalSize = const Size(2880, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestAdminShellRepositories(
        child: RepositoryProvider<TutorialRepository>.value(
            value: Catalog(), child: const MaterialApp(home: AdminShell()))));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Members'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Content opens the edit-only supported Mini-games page',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestAdminShellRepositories(
        child: RepositoryProvider<TutorialRepository>.value(
            value: Catalog(), child: const MaterialApp(home: AdminShell()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Content').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mini-games').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit content'), findsNWidgets(2));
    expect(find.text('Add game'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Payments navigation switches between modes and stays synchronized across sidebar and page sub-tabs',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestAdminShellRepositories(
        child: RepositoryProvider<TutorialRepository>.value(
            value: Catalog(), child: const MaterialApp(home: AdminShell()))));
    await tester.pumpAndSettle();

    // 1. Navigate to Transactions from sidebar
    await tester.tap(find.text('Transactions').first);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Track membership and coaching payments across facilities.'),
        findsOneWidget);

    // 2. Click Refund Requests from inside the page sub-tab (.last)
    await tester.tap(find.widgetWithText(InkWell, 'Refund Requests').last);
    await tester.pumpAndSettle();

    // Verify page header switched to Refund Requests immediately without needing another click
    expect(
        find.text(
            'Review, approve, and manage member refund requests with audit evidence.'),
        findsOneWidget);
    expect(find.text('Refund Requests'), findsWidgets);

    // 3. Click Reconciliation from sub-tab (.last)
    await tester.tap(find.widgetWithText(InkWell, 'Reconciliation').last);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Investigate uncertain bills and resolve payment exceptions safely.'),
        findsOneWidget);

    // 4. Click Transactions from sidebar (.first)
    await tester.tap(find.widgetWithText(InkWell, 'Transactions').first);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Track membership and coaching payments across facilities.'),
        findsOneWidget);

    // 5. Click Refund Requests from sidebar (.first)
    await tester.tap(find.widgetWithText(InkWell, 'Refund Requests').first);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Review, approve, and manage member refund requests with audit evidence.'),
        findsOneWidget);

    // 6. Click Transactions from sub-tab (.last)
    await tester.tap(find.widgetWithText(InkWell, 'Transactions').last);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Track membership and coaching payments across facilities.'),
        findsOneWidget);
  });
}
