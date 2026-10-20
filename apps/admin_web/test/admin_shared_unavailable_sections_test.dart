import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/di/app_repositories.dart';
import 'package:gainpath_admin_web/features/content/presentation/admin/system_settings_screen.dart';
import 'package:gainpath_admin_web/features/membership/presentation/admin/refunds_screen.dart';
import 'package:gainpath_admin_web/features/recommendation/presentation/admin/admin_recommendation_screens.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/content.dart';
import 'package:google_fonts/google_fonts.dart';

const _testSession = AuthSession(
  userId: 'unavail-admin',
  organizationId: 'unavail-org',
  branchIds: ['b1'],
  displayName: 'Unavailable Admin',
  email: 'admin@unavail.org',
  role: AppRole.admin,
);

class _FakeFacilitySettingsRepository implements FacilitySettingsRepository {
  @override
  Future<FacilityNameSnapshot> load() async {
    return const FacilityNameSnapshot(
      organizationId: 'unavail-org',
      displayName: 'Unified Facility',
      editBaseline: Object(),
    );
  }

  @override
  Future<FacilityNameSnapshot> save(FacilityNameSnapshot original,
      {required String displayName}) async {
    return FacilityNameSnapshot(
      organizationId: original.organizationId,
      displayName: displayName,
      editBaseline: Object(),
    );
  }
}

class _FakeBaseline extends ComplianceDocumentEditBaseline {}

class _FakeComplianceDocumentRepository implements ComplianceDocumentRepository {
  @override
  Future<ComplianceDocumentSnapshot> load() async {
    return ComplianceDocumentSnapshot(
      current: ComplianceDocument(
        text: 'Sample compliance text',
        isArchived: false,
        revision: 1,
        updatedAt: DateTime.now(),
      ),
      history: const [],
      editBaseline: _FakeBaseline(),
    );
  }

  @override
  Future<ComplianceDocumentSnapshot> save(ComplianceDocumentSnapshot original,
      {required String text, required bool isArchived}) async {
    return original;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Unavailable sections & Truthful states', () {
    testWidgets('System settings conversion rate tab is read-only in live mode',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<FacilitySettingsRepository>.value(
              value: _FakeFacilitySettingsRepository(),
            ),
            RepositoryProvider<ComplianceDocumentRepository>.value(
              value: _FakeComplianceDocumentRepository(),
            ),
          ],
          child: const MaterialApp(
            home: SystemSettingsScreen(live: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Reward conversion tab
      await tester.tap(find.text('Reward conversion'));
      await tester.pumpAndSettle();

      // Explanatory note must be displayed
      expect(
        find.text(
          'Reward conversion policy is managed by organization operations and is read-only in this console.',
        ),
        findsOneWidget,
      );

      // Save button must be disabled (null onPressed)
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save conversion rate'),
      );
      expect(saveButton.onPressed, isNull);

      // Rate examples should show '—'
      expect(find.text('Conversion rate: —'), findsOneWidget);
    });

    testWidgets('Refunds screen fails closed without a scoped repository',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppRepositories(
          config: const BackendConfig(BackendMode.firebase),
          session: _testSession,
          child: const MaterialApp(
            home: RefundsScreen(live: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Payment review requires a current Admin session.'),
        findsOneWidget,
      );
      expect(find.text('Approve refund'), findsNothing);
    });

    testWidgets('Recommendations screen displays honest unavailable metrics and prevents mutations',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppRepositories(
          config: const BackendConfig(BackendMode.firebase),
          session: _testSession,
          child: const MaterialApp(
            home: RiskLeaderboardScreen(live: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // High-risk and matched leads show '—'
      expect(find.text('—'), findsWidgets);

      // Content gaps empty / unavailable explanation
      expect(
        find.text('Content gap analysis is unavailable in this release.'),
        findsOneWidget,
      );

      // Exercise data unavailable explanation
      expect(
        find.text('High-risk exercise data is unavailable in this release.'),
        findsOneWidget,
      );
    });
  });
}
