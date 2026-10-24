import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, SessionScope;
import 'package:gainpath_mobile/app/shells/member_shell.dart';
import 'package:gainpath_mobile/navigation/auth_navigation.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/profile_setup_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/shared/login_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/shared/onboarding_screen.dart';
import 'support/fitness_profile_fake.dart';
import 'support/test_mobile_app.dart';
import 'coach_profile_state_test.dart' show ProfileFake;

class ProviderVerificationAuth extends InMemoryAuthRepository {
  bool verifiedByProvider = false;

  @override
  Future<AuthSession?> restoreSession() async {
    final session = await super.restoreSession();
    if (verifiedByProvider && session?.needsVerification == true) {
      await verifyEmailForDemo();
    }
    return super.restoreSession();
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'registration waits for provider verification before profile setup',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = ProviderVerificationAuth();
    await tester.pumpWidget(GainPathMobileApp.injected(
      authRepository: repository,
      profileRepositoryFactory: FakeProfileGateway().repository,
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'New Member');
    await tester.enterText(find.byType(TextField).at(1), 'new@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.enterText(find.byType(TextField).at(3), 'password123');
    await tester.tap(find.byType(Checkbox));
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    repository.verifiedByProvider = true;
    await tester.tap(find.text("I've verified my email"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect((await repository.restoreSession())!.needsVerification, isFalse);
    await tester.pumpWidget(const SizedBox());
    await repository.dispose();
  });
  testWidgets('signed-out mobile app opens one login page', (tester) async {
    await tester.pumpWidget(const TestMobileApp());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Member or coach'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
    expect(find.text('Google'), findsNothing);
  });

  testWidgets('optional introduction returns to the shared login',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TestMobileApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('View introduction'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Member or coach'), findsOneWidget);
  });

  testWidgets('Firebase registration opens without demo repositories',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = InMemoryAuthRepository();
    await tester.pumpWidget(GainPathMobileApp.injected(
      authRepository: repository,
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await repository.dispose();
  });

  testWidgets('authenticated member can enter the local workout flow',
      (tester) async {
    await tester.pumpWidget(const TestMobileApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'member@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('shared mock login routes the coach demo account to coach home',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const TestMobileApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'coach@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Roster'), findsWidgets);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('restored coach account skips login', (tester) async {
    final repository = InMemoryAuthRepository();
    await repository.signIn(
      email: 'coach@example.com',
      password: 'password123',
    );
    await tester.pumpWidget(TestMobileApp(authRepository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Roster'), findsWidgets);
    expect(find.byType(LoginScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await repository.dispose();
  });

  testWidgets('named member route retains scoped profile composition',
      (tester) async {
    final repository = InMemoryAuthRepository();
    final session = await repository.signIn(
        email: 'member@example.com', password: 'password123');
    final profiles = FakeProfileGateway();
    final profileScopes = <SessionScope>[];
    await tester.pumpWidget(GainPathMobileApp.injected(
      authRepository: repository,
      profileRepositoryFactory: (scope) {
        profileScopes.add(scope);
        return profiles.repository(scope);
      },
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.member);
    await tester.pumpAndSettle();

    expect(profileScopes.length, greaterThan(1));
    expect(profileScopes, everyElement(session.scope));
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.byType(MemberShell), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await repository.dispose();
  });

  for (final role in ['member', 'coach']) {
    testWidgets(
        'Firebase $role login leaves the entry flow and sign-out returns',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = InMemoryAuthRepository();
      await tester.pumpWidget(GainPathMobileApp.injected(
        authRepository: repository,
        profileRepositoryFactory: FakeProfileGateway().repository,
        coachProfileFactory: (_, current) => ProfileFake(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Member or coach'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '$role@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      final submit = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      if (role == 'coach') {
        expect(find.text('Roster'), findsWidgets);
        await tester.tap(find.text('Profile').last);
        await tester.pumpAndSettle();
      }
      expect(
          role == 'member'
              ? find.byType(ProfileSetupScreen)
              : find.text('Not published in directory'),
          findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      if (role == 'coach') {
        await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Member or coach'), findsOneWidget);
      expect(find.text('Firebase identity connected'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await repository.dispose();
    });
  }
}
