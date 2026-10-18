import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/di/app_repositories.dart';
import 'package:gainpath_admin_web/app/shells/admin_shell.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:google_fonts/google_fonts.dart';

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

  group('Responsive Admin Console layouts', () {
    testWidgets('renders on desktop (1600x1000) without overflow', (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const AppRepositories(
          config: BackendConfig(BackendMode.firebase),
          session: _testSession,
          child: MaterialApp(
            home: AdminShell(liveSession: _testSession),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.text('GainPath — responsive-org'), findsOneWidget);
    });

    testWidgets('renders on tablet (950x1000) with collapsed rail without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(950, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const AppRepositories(
          config: BackendConfig(BackendMode.firebase),
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
        const AppRepositories(
          config: BackendConfig(BackendMode.firebase),
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
