import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/di/admin_presentation_dependencies.dart';
import 'package:gainpath_admin_web/app/di/app_repositories.dart';
import 'package:gainpath_admin_web/app/routing/admin_console_navigation.dart';
import 'package:gainpath_admin_web/app/shells/admin_shell.dart';
import 'package:gainpath_admin_web/features/analytics/presentation/admin/reports_screen.dart';
import 'package:gainpath_admin_web/features/operations_calendar/operations_calendar_screen.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

import '../../../test_support/fyp_render_support.dart';
import 'support/empty_coach_directory.dart';

const _admin = AuthSession(
  userId: 'calendar-fixture-admin',
  organizationId: 'calendar-fixture-org',
  branchIds: ['east'],
  email: 'calendar@example.test',
  role: AppRole.admin,
);

void main() {
  testWidgets(
      'branch overview opens a scoped calendar and drills into Branch Reports by MYT day',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <Map<String, Object?>>[];

    await tester.pumpWidget(AppRepositories.injected(
      session: _admin,
      coachRepositoryFactory: (scope, _) =>
          EmptyCoachDirectoryRepository(scope),
      accountContactFactory: (scope, _) =>
          NeutralAdminAccountContactRepository(scope: scope),
      child: AdminConsoleApp(
        theme: ThemeData(),
        title: 'GainPath Admin',
        home: AdminShell(
          liveSession: _admin,
          branchRequest: (input) async {
            requests.add(Map.of(input));
            return switch (input['action']) {
              'list' => {
                  'records': [
                    {
                      'branchId': 'east',
                      'displayName': 'Fixture East Gym',
                      'status': 'active',
                    },
                  ],
                },
              'branchStats' => {'visits': 0},
              'calendarEvents' => {'events': [], 'unavailable': []},
              'calendarInsights' => {'daily': [], 'unavailable': []},
              'branchReport' => {
                  'branchName': 'Fixture East Gym',
                  'daily': [],
                },
              _ => throw StateError('Unexpected branch fixture request.'),
            };
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final router = AdminConsoleNavigation.maybeOf(
        tester.element(find.byType(AdminShell)))!;
    await router.setNewRoutePath(Uri.parse('/console/branches/east/overview'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('branch-operations-calendar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.uri.path, '/console/operations-calendar');
    expect(router.uri.queryParameters['branch'], 'east');
    final calendar = tester.widget<OperationsCalendarScreen>(
        find.byType(OperationsCalendarScreen));
    expect(calendar.initialBranchId, 'east');
    final scoped =
        requests.where((input) => input['action'] == 'calendarEvents');
    expect(scoped, isNotEmpty);
    expect(scoped.every((input) => input['branchId'] == 'east'), isTrue);

    final day = DateTime.utc(2026, 11, 1);
    calendar.onOpenReport('east', day);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        router.uri, Uri.parse('/reports/branches?branch=east&date=2026-11-01'));
    final reports = tester.widget<ReportsScreen>(find.byType(ReportsScreen));
    expect(reports.initialBranchId, 'east');
    expect(reports.initialDate, day);
    expect(reports.category, ReportsCategory.branches);
    expect(
        requests.any((input) =>
            input['action'] == 'branchReport' &&
            input['branchId'] == 'east' &&
            input['startAtMillis'] ==
                day.subtract(const Duration(hours: 8)).millisecondsSinceEpoch &&
            input['endAtMillis'] ==
                day.add(const Duration(hours: 16)).millisecondsSinceEpoch),
        isTrue);

    await router.setNewRoutePath(Uri.parse('/console/operations-calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        tester
            .widget<OperationsCalendarScreen>(
                find.byType(OperationsCalendarScreen))
            .initialBranchId,
        isNull);
    await router.setNewRoutePath(Uri.parse('/reports/branches'));
    await tester.pumpAndSettle();
    final reportScope = find.descendant(
      of: find.byType(ReportsScreen),
      matching: find.byType(DropdownButton<String>),
    );
    await tester.tap(reportScope);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture East Gym').last);
    await tester.pumpAndSettle();
    expect(
        requests.lastWhere(
            (input) => input['action'] == 'branchReport')['branchId'],
        'east');

    await router.setNewRoutePath(Uri.parse('/console/operations-calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final allBranchesCalendar = tester.widget<OperationsCalendarScreen>(
        find.byType(OperationsCalendarScreen));
    allBranchesCalendar.onOpenReport(null, day);
    await tester.pumpAndSettle();
    expect(router.uri, Uri.parse('/reports/branches?date=2026-11-01'));
    final all =
        requests.lastWhere((input) => input['action'] == 'branchReport');
    expect(all['scope'], 'all');
    expect(all['branchId'], isNull);
    expect(tester.takeException(), isNull);
  });
}
