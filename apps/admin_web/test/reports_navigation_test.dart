import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/app/shells/admin_shell.dart';
import 'support/admin_shell_repositories.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';
import 'content_removal_ui_test.dart' show Catalog;
import 'package:gainpath_admin_web/app/routing/admin_console_navigation.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'admin_original_reporting_layout_test.dart' as original;
import 'admin_workout_reporting_ui_test.dart' show WorkoutUiGateway;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'returning to same category retains fresh workouts and refreshes expired data',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = WorkoutUiGateway();
    var now = DateTime.now();
    Future<void> show(bool active) async {
      await tester.pumpWidget(original.originalLayoutApp(
          ReportsScreen(live: true, active: active, now: () => now), gateway));
      await tester.pumpAndSettle();
    }

    await show(true);
    final retained = tester.state(find.byType(ReportsScreen));
    expect(gateway.calls, 1);
    await show(false);
    await show(true);
    expect(gateway.calls, 1);
    await show(false);
    now = now.add(const Duration(seconds: 31));
    await show(true);
    expect(gateway.calls, 2);
    expect(
        identical(retained, tester.state(find.byType(ReportsScreen))), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'URL changes retain one Reports instance through direct entry and history',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestAdminShellRepositories(
        child: RepositoryProvider<TutorialRepository>.value(
            value: Catalog(),
            child: AdminConsoleApp(
                theme: ThemeData(),
                title: 'Reports test',
                home: const AdminShell()))));
    await tester.pumpAndSettle();
    final navigation = Router.of(tester.element(find.byType(AdminShell)))
        .routerDelegate as AdminConsoleNavigation;
    await navigation.setNewRoutePath(Uri.parse('/reports/fitness'));
    await tester.pumpAndSettle();
    expect(find.text('Fitness Analytics'), findsOneWidget);
    final retained = tester.state(find.byType(ReportsScreen));
    await navigation.setNewRoutePath(Uri.parse('/reports/financial'));
    await tester.pumpAndSettle();
    expect(find.text('Financial Analytics'), findsOneWidget);
    expect(
        identical(retained, tester.state(find.byType(ReportsScreen))), isTrue);
    await navigation.setNewRoutePath(Uri.parse('/reports/fitness'));
    await tester.pumpAndSettle();
    expect(find.text('Fitness Analytics'), findsOneWidget);
    expect(
        identical(retained, tester.state(find.byType(ReportsScreen))), isTrue);
    await navigation.setNewRoutePath(Uri.parse('/console/system-settings'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ReportsScreen>(
                find.byType(ReportsScreen, skipOffstage: false))
            .active,
        isFalse);
    await navigation.setNewRoutePath(Uri.parse('/reports/fitness'));
    await tester.pumpAndSettle();
    expect(
        identical(retained, tester.state(find.byType(ReportsScreen))), isTrue);
    await navigation.setNewRoutePath(Uri.parse('/console/system-settings'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ReportsScreen>(
                find.byType(ReportsScreen, skipOffstage: false))
            .active,
        isFalse);
    expect(tester.takeException(), isNull);
  });
  for (final width in [1440.0, 1024.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Reports fits $width pixels at $scale text scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(original.originalLayoutApp(
            Builder(
                builder: (context) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: const ReportsScreen(live: true))),
            original.OriginalLayoutGateway()));
        await tester.pumpAndSettle();
        expect(find.text('Overview Analytics'), findsOneWidget);
        expect(find.text('Reports & analytics'), findsNothing);
        for (final category in ReportsCategory.values) {
          tester
              .state<ReportsScreenState>(find.byType(ReportsScreen))
              .selectCategory(category);
          await tester.pumpAndSettle();
          expect(find.text('${category.label} Analytics'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: category.name);
        }
      });
    }
  }
  testWidgets(
      'Reports sidebar opens Overview and selects Fitness without hero tabs',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TestAdminShellRepositories(
        child: RepositoryProvider<TutorialRepository>.value(
            value: Catalog(), child: const MaterialApp(home: AdminShell()))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reports').first);
    await tester.tap(find.text('Reports').first);
    await tester.pumpAndSettle();
    expect(find.text('Overview Analytics'), findsOneWidget);
    expect(find.text('Reports & analytics'), findsNothing);
    await tester.ensureVisible(find.text('Fitness').first);
    await tester.tap(find.text('Fitness').first);
    await tester.pumpAndSettle();
    expect(find.text('Fitness Analytics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
