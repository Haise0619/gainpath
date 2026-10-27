import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/di/admin_presentation_dependencies.dart';
import 'package:gainpath_admin_web/app/di/app_repositories.dart';
import 'package:gainpath_admin_web/features/analytics/application/admin_reporting_gateway.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_reporting_gateway.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/recommendation.dart';
import 'package:google_fonts/google_fonts.dart';

const _testSession = AuthSession(
  userId: 'test-admin',
  organizationId: 'test-org',
  branchIds: ['test-branch'],
  displayName: 'Admin User',
  email: 'admin@test.com',
  role: AppRole.admin,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('AdminPresentationDependencies', () {
    test('creates neutral repository implementations for Firebase mode', () {
      final deps = AdminPresentationDependencies.fromScope(
        scope: _testSession.scope,
        isCurrent: () => true,
        session: _testSession,
      );

      expect(deps.analytics, isA<NeutralAnalyticsRepository>());
      expect(deps.recommendation, isA<NeutralRecommendationRepository>());
      expect(deps.membership, isA<NeutralMembershipRepository>());
      expect(deps.booking, isA<NeutralBookingRepository>());
      expect(deps.availability, isA<NeutralAvailabilityRepository>());
      expect(deps.coach, isA<NeutralCoachRepository>());
      expect(deps.userAccount, isA<NeutralUserAccountRepository>());
      expect(deps.reportingGateway, isA<FirebaseAdminReportingGateway>());

      // Verifies neutral accounts contain no seeded mock users
      expect(deps.userAccount.users, isEmpty);
      expect(deps.userAccount.branches, isEmpty);
      expect(deps.userAccount.adminName, 'Admin User');
      expect(deps.userAccount.adminEmail, 'admin@test.com');
    });

    test('Neutral analytics stats produce truthful dashes', () {
      final deps = AdminPresentationDependencies.fromScope(
        scope: _testSession.scope,
        isCurrent: () => true,
        session: _testSession,
      );

      final stats = deps.analytics.adminStats;
      expect(stats, isNotEmpty);
      for (final stat in stats) {
        expect(stat[1], '—'); // Value
        expect(stat[2], '—'); // Delta
      }
    });

    testWidgets('AppRepositories injects neutral contracts in Firebase mode',
        (tester) async {
      await tester.pumpWidget(
        AppRepositories(
          session: _testSession,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final hasDeps =
                    context.read<AdminPresentationDependencies?>() != null;
                final analytics = context.read<AnalyticsRepository>();
                final recommendation = context.read<RecommendationRepository>();
                final gateway = context.read<AdminReportingGateway>();
                final accounts = context.read<UserAccountRepository>();

                return Text(
                  'deps:$hasDeps,'
                  'analytics:${analytics is NeutralAnalyticsRepository},'
                  'rec:${recommendation is NeutralRecommendationRepository},'
                  'gateway:${gateway is FirebaseAdminReportingGateway},'
                  'users:${accounts.users.length}',
                );
              },
            ),
          ),
        ),
      );

      expect(
        find.text('deps:true,analytics:true,rec:true,gateway:true,users:0'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
