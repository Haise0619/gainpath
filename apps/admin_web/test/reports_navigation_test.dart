import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  testWidgets('branch scope belongs only to Branch Analytics', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <Map<String, Object?>>[];
    final captureKey = GlobalKey();
    final render =
        Platform.environment['GAINPATH_RENDER_BRANCH_REPORT'] == 'true';
    if (render) {
      await tester.runAsync(() async {
        final font = await File('../mobile/assets/fonts/Barlow-Regular.ttf')
            .readAsBytes();
        await (FontLoader('BranchFixture')
              ..addFont(Future.value(ByteData.sublistView(font))))
            .load();
        final icons = await File(
                'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
            .readAsBytes();
        await (FontLoader('MaterialIcons')
              ..addFont(Future.value(ByteData.sublistView(icons))))
            .load();
      });
    }
    final gateway = original.OriginalLayoutGateway();
    Future<void> show(ReportsCategory category) async {
      await tester.pumpWidget(original.originalLayoutApp(
        RepaintBoundary(
            key: captureKey,
            child: ColoredBox(
                color: const Color(0xFFF6F3FC),
                child: Theme(
                    data:
                        ThemeData(fontFamily: render ? 'BranchFixture' : null),
                    child: ReportsScreen(
                      live: true,
                      category: category,
                      branchRequest: (input) async {
                        requests.add(input);
                        if (input['action'] == 'list') {
                          return {
                            'records': [
                              {
                                'branchId': 'old',
                                'displayName': 'Old Gym',
                                'status': 'inactive'
                              },
                            ]
                          };
                        }
                        if (input['scope'] == 'all') {
                          return {
                            'branchName': 'All branches',
                            'activeBranches': 1,
                            'branches': [
                              {
                                'branchId': 'old',
                                'branchName': 'Old Gym',
                                'status': 'inactive',
                                'homeMembers': 3,
                                'assignedCoaches': 2,
                                'gymVisits': 4,
                                'bookingsCreated': 3,
                                'completedSessions': 2,
                                'coachingMinor': 20000
                              },
                            ]
                          };
                        }
                        return {
                          'branchName': 'Old Gym',
                          'homeMembers': 3,
                          'assignedCoaches': 2,
                          'equipmentUnits': 12,
                          'usableUnits': 10,
                          'maintenanceUnits': 2,
                          'acceptedWorkouts': 14,
                          'daily': [
                            {
                              'date': '2026-11-16',
                              'visits': 3,
                              'bookings': 1,
                              'completed': 1,
                              'cancelled': 0,
                              'coachingMinor': 10000
                            },
                            {
                              'date': '2026-11-18',
                              'visits': 1,
                              'bookings': 2,
                              'completed': 1,
                              'cancelled': 0,
                              'coachingMinor': 10000
                            },
                          ],
                        };
                      },
                    )))),
        gateway,
      ));
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      if (!render) return;
      await tester.runAsync(() async {
        final boundary = captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '../../build/multi-branch-release/phase6-fixture-$name.png')
              .writeAsBytes(png!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }

    await show(ReportsCategory.overview);
    expect(find.text('All branches'), findsNothing);
    expect(requests, isEmpty);
    await capture('overview');
    await show(ReportsCategory.branches);
    expect(requests.any((r) => r['scope'] == 'all'), isTrue);
    expect(find.text('View details'), findsOneWidget);
    await capture('all-branches');
    await tester.ensureVisible(find.text('View details'));
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(requests.last, containsPair('branchId', 'old'));
    expect(find.text('Export branch CSV'), findsOneWidget);
    await tester.ensureVisible(find.text('7 days'));
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(requests.last, containsPair('branchId', 'old'));
    await capture('specific-branch');
    for (final category
        in ReportsCategory.values.where((c) => c != ReportsCategory.branches)) {
      await show(category);
      expect(find.text('Old Gym (inactive)'), findsNothing);
      expect(find.text('All branches'), findsNothing);
    }
    expect(requests.where((r) => r['action'] == 'list'), hasLength(1));
  });
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
          expect(
              find.text(category == ReportsCategory.branches
                  ? 'Branch Analytics'
                  : '${category.label} Analytics'),
              findsOneWidget);
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
