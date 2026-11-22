import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/di/app_repositories.dart';
import 'package:gainpath_admin_web/app/di/admin_presentation_dependencies.dart';
import 'package:gainpath_admin_web/app/routing/admin_console_navigation.dart';
import 'package:gainpath_admin_web/app/shells/admin_shell.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:google_fonts/google_fonts.dart';
import 'support/empty_coach_directory.dart';

const _testSession = AuthSession(
  userId: 'responsive-admin',
  organizationId: 'responsive-org',
  branchIds: ['b1'],
  displayName: 'Responsive Admin',
  email: 'admin@responsive.org',
  role: AppRole.admin,
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Add Coach route stays under the shell Coaches breadcrumb',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AppRepositories.injected(
      coachRepositoryFactory: (scope, _) => EmptyCoachDirectoryRepository(scope),
      accountContactFactory: (scope, _) =>
          NeutralAdminAccountContactRepository(scope: scope),
      session: _testSession,
      child: AdminConsoleApp(
        theme: ThemeData(),
        title: 'GainPath Admin',
        home: AdminShell(
          liveSession: _testSession,
          coachBranchRequest: (request) async {
            expect(request['action'], 'list');
            return {
              'records': [
                {
                  'branchId': 'b1',
                  'displayName': 'Main Branch',
                  'status': 'active',
                },
              ],
            };
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final router = AdminConsoleNavigation.maybeOf(
        tester.element(find.byType(AdminShell)))!;
    await router.setNewRoutePath(Uri.parse('/console/coaches'));
    await tester.pumpAndSettle();
    final addCoach = find.byKey(const ValueKey('add-coach'));
    final search = find.byType(TextField);
    await tester.enterText(search, 'Strength');
    await tester.tap(addCoach);
    await tester.pumpAndSettle();

    expect(router.uri.path, '/console/coaches/add');
    final crumb = find.widgetWithText(InkWell, 'Coaches').last;
    final current = find.text('Add Coach');
    expect(crumb, findsOneWidget);
    expect(current, findsOneWidget);
    expect(tester.getCenter(current).dy, tester.getCenter(crumb).dy);
    expect(find.text('1 of 3 · Account information'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Coach');
    await tester.tap(crumb);
    await tester.pumpAndSettle();
    expect(find.text('Discard coach onboarding?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(router.uri.path, '/console/coaches');
    expect(find.text('Coach Management'), findsOneWidget);
    expect(tester.widget<TextField>(search).controller!.text, 'Strength');

    await router.setNewRoutePath(Uri.parse('/console/coaches/add'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 · Account information'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Keep this draft');
    await router.setNewRoutePath(Uri.parse('/console/coaches'));
    await tester.pumpAndSettle();
    expect(find.text('Discard coach onboarding?'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(router.uri.path, '/console/coaches/add');
    expect(find.text('Keep this draft'), findsOneWidget);

    await router.setNewRoutePath(Uri.parse('/console/coaches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(router.uri.path, '/console/coaches');
    expect(find.text('Coach Management'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Responsive Admin Console layouts', () {
    testWidgets('renders on desktop (1600x1000) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppRepositories.injected(
          coachRepositoryFactory: (scope, _) =>
              EmptyCoachDirectoryRepository(scope),
          accountContactFactory: (scope, _) =>
              NeutralAdminAccountContactRepository(scope: scope),
          session: _testSession,
          child: MaterialApp(
            home: AdminShell(liveSession: _testSession),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.text('GAINPATH / ADMIN'), findsOneWidget);
      final sidebar = find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 224);
      expect(sidebar, findsOneWidget);
      expect(tester.getSize(sidebar).width, 224);
    });

    testWidgets(
        'renders on tablet (950x1000) with collapsed rail without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(950, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppRepositories.injected(
          coachRepositoryFactory: (scope, _) =>
              EmptyCoachDirectoryRepository(scope),
          accountContactFactory: (scope, _) =>
              NeutralAdminAccountContactRepository(scope: scope),
          session: _testSession,
          child: MaterialApp(
            home: AdminShell(liveSession: _testSession),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminShell), findsOneWidget);
    });

    testWidgets('renders on narrow viewport (768x1024) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppRepositories.injected(
          coachRepositoryFactory: (scope, _) =>
              EmptyCoachDirectoryRepository(scope),
          accountContactFactory: (scope, _) =>
              NeutralAdminAccountContactRepository(scope: scope),
          session: _testSession,
          child: MaterialApp(
            home: AdminShell(liveSession: _testSession),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminShell), findsOneWidget);
    });
  });
}
