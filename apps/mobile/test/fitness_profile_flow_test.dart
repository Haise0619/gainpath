import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AgeBracket;
import 'package:gainpath_mobile/main.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/profile_setup_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/physical_profile_screen.dart';
import 'package:gainpath_mobile/app/shells/member_shell.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/gamification_dashboard_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/experience_level_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/activity_level_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/goals_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/numeric_fitness_targets.dart';
import 'package:gainpath_mobile/features/identity/presentation/shared/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/fitness_profile_fake.dart';
import 'coach_directory_flow_test.dart' show DirectoryFake;

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), 'password123');
  await tap(tester, 'Sign in');
}

Future<void> confirmInitialMetrics(WidgetTester tester) async {
  await tap(tester, 'Continue');
  expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull);
  await tester.tap(find.byType(DropdownButtonFormField<AgeBracket>));
  await tester.pumpAndSettle();
  await tap(tester, '25–34 years');
  await tap(tester, 'Continue');
  await tap(tester, 'This is my height');
  await tap(tester, 'Continue');
  await tap(tester, 'This is my weight');
  await tap(tester, 'Continue');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mount(WidgetTester tester, InMemoryAuthRepository auth,
      FakeProfileGateway profiles,
      {WidgetBuilder? settingsBuilder}) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GainPathMobileApp(
      authRepository: auth,
      backendConfig: const BackendConfig(BackendMode.firebase),
      profileRepositoryFactory: profiles.repository,
      routineLoaderFactory: (_) async => null,
      coachDirectoryFactory: (scope, current) =>
          DirectoryFake(scope)..profile = null,
      memberSettingsBuilder: settingsBuilder,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'setup saves, editing preloads, and logout/login reloads only the correct account',
      (tester) async {
    final auth = InMemoryAuthRepository();
    final profiles = FakeProfileGateway();
    await mount(tester, auth, profiles);
    await signIn(tester, 'one@example.com');
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull);
    await tap(tester, 'Prefer not to say');
    await confirmInitialMetrics(tester);
    await tap(tester, 'Build muscle');
    await tap(tester, 'Continue');
    await tap(tester, 'Lightly active');
    await tap(tester, 'Continue');
    await tap(tester, 'Beginner');
    profiles.failWrite = true;
    await tap(tester, 'Finish setup');
    expect(find.text('Could not save profile. Retry.'), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    profiles.failWrite = false;
    profiles.pendingWrite = Completer<void>();
    await tap(tester, 'Finish setup');
    expect(find.text('Saving…'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull);
    profiles.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(MemberShell), findsOneWidget);
    await tap(tester, 'Profile');
    expect(find.text('65 kg'), findsWidgets);
    final firstScope = (await auth.restoreSession())!.scope;

    await tap(tester, 'Physical profile');
    expect(find.byType(PhysicalProfileScreen), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider).last).value, 65);
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pumpAndSettle();
    await tap(tester, 'Save changes');
    expect(find.text('66 kg'), findsWidgets);
    await tap(tester, 'Sign out');
    expect(find.byType(LoginScreen), findsOneWidget);
    await signIn(tester, 'two@example.com');
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.text('66 kg'), findsNothing);
    await tap(tester, 'Sign out');
    await signIn(tester, 'one@example.com');
    await tap(tester, 'Profile');
    expect(find.text('66 kg'), findsWidgets);
    expect(profiles.records[firstScope]!['weightKg'], 66);

    // Recreate the app with the persisted store and a restored auth session.
    await tester.pumpWidget(const SizedBox());
    await mount(tester, auth, profiles);
    await tap(tester, 'Profile');
    expect(find.text('66 kg'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await auth.dispose();
  });

  testWidgets('load error offers retry and never opens an empty setup',
      (tester) async {
    final auth = InMemoryAuthRepository();
    final profiles = FakeProfileGateway()..failRead = true;
    await mount(tester, auth, profiles);
    await signIn(tester, 'one@example.com');
    expect(find.text('Could not load profile.'), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    final scope = (await auth.restoreSession())!.scope;
    profiles.failRead = false;
    await profiles.repository(scope).save(sampleProfile());
    await tap(tester, 'Retry');
    await tap(tester, 'Profile');
    expect(find.text('65 kg'), findsWidgets);
    await tap(tester, 'Physical profile');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('65 kg'), findsWidgets);
    expect(profiles.writes, 1);
    await tester.pumpWidget(const SizedBox());
    await auth.dispose();
  });

  testWidgets(
      'setup keeps answers after unverified save and explicitly reloads the saved profile',
      (tester) async {
    final auth = InMemoryAuthRepository();
    final profiles = FakeProfileGateway();
    await mount(tester, auth, profiles);
    await signIn(tester, 'one@example.com');
    await tap(tester, 'Prefer not to say');
    await confirmInitialMetrics(tester);
    await tap(tester, 'Build muscle');
    await tap(tester, 'Continue');
    await tap(tester, 'Lightly active');
    await tap(tester, 'Continue');
    await tap(tester, 'Beginner');
    profiles.afterWrite = () => profiles.failRead = true;
    await tap(tester, 'Finish setup');
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.text('How experienced are you?'), findsOneWidget);
    expect(find.text('Reload saved profile'), findsOneWidget);
    profiles.failRead = false;
    await tap(tester, 'Reload saved profile');
    expect(find.byType(MemberShell), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await auth.dispose();
  });

  testWidgets(
      'existing profile editors persist training preferences without demo targets',
      (tester) async {
    final auth = InMemoryAuthRepository();
    final profiles = FakeProfileGateway();
    final account =
        await auth.signIn(email: 'one@example.com', password: 'password123');
    await profiles.repository(account.scope).save(sampleProfile());
    await mount(tester, auth, profiles);
    expect(find.text('Premium member'), findsNothing);
    expect(find.text('4/5'), findsNothing);
    await tap(tester, 'Profile');
    await tap(tester, 'Experience level');
    expect(find.byType(ExperienceLevelScreen), findsOneWidget);
    await tap(tester, 'Advanced');
    await tap(tester, 'Save');
    expect(find.text('Advanced'), findsOneWidget);
    await tap(tester, 'Activity level');
    expect(find.byType(ActivityLevelScreen), findsOneWidget);
    await tap(tester, 'Very active');
    await tap(tester, 'Save');
    expect(find.text('Very active'), findsOneWidget);
    await tap(tester, 'Fitness goals');
    expect(find.byType(GoalsScreen), findsOneWidget);
    expect(find.byType(NumericFitnessTargets), findsOneWidget);
    await tap(tester, 'Reduce stress');
    await tap(tester, 'Save changes');
    expect(profiles.records[account.scope]!['experience'], 'advanced');
    expect(profiles.records[account.scope]!['activity'], 'veryActive');
    expect(profiles.records[account.scope]!['goals'], contains('reduceStress'));
    await tester.pumpWidget(const SizedBox());
    await auth.dispose();
  });

  testWidgets('Firebase member Profile opens the connected Settings route',
      (tester) async {
    final auth = InMemoryAuthRepository();
    final profiles = FakeProfileGateway();
    final account =
        await auth.signIn(email: 'one@example.com', password: 'password123');
    await profiles.repository(account.scope).save(sampleProfile());
    await mount(tester, auth, profiles,
        settingsBuilder: (_) =>
            const Scaffold(body: Center(child: Text('Live settings'))));
    await tap(tester, 'Profile');
    await tap(tester, 'Settings');
    expect(find.text('Live settings'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await auth.dispose();
  });

  testWidgets(
      'Firebase member keeps the original tab layouts without mock actions',
      (tester) async {
    final auth = InMemoryAuthRepository();
    final profiles = FakeProfileGateway();
    final account =
        await auth.signIn(email: 'one@example.com', password: 'password123');
    await profiles.repository(account.scope).save(sampleProfile());
    await mount(tester, auth, profiles);
    expect(find.byType(MemberHomeScreen), findsOneWidget);
    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('- day streak'), findsOneWidget);
    expect(find.text('Check-in is not connected yet.'), findsOneWidget);
    expect(find.text('No published routine yet'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Claim'))
            .onPressed,
        isNotNull);
    await tap(tester, 'Claim');
    expect(find.text('This feature is currently unavailable.'), findsOneWidget);
    await tap(tester, 'Workout');
    expect(find.byType(WorkoutPrepScreen), findsOneWidget);
    expect(find.text('Watch tutorial'), findsOneWidget);
    expect(find.text('View routine'), findsOneWidget);
    expect(find.text('Review camera setup'), findsOneWidget);
    expect(find.text('Scan equipment'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Start guided session'), 300,
        scrollable: find.descendant(
            of: find.byType(WorkoutPrepScreen),
            matching: find.byType(Scrollable)));
    expect(
        tester
            .widget<FilledButton>(find.ancestor(
                of: find.text('Start guided session'),
                matching:
                    find.byWidgetPredicate((widget) => widget is FilledButton)))
            .onPressed,
        isNotNull);
    await tap(tester, 'Rewards');
    expect(find.byType(GamificationDashboardScreen), findsOneWidget);
    expect(find.text('YOUR POINTS'), findsOneWidget);
    await tap(tester, 'Coaches');
    expect(find.byType(BrowseCoachesScreen), findsOneWidget);
    expect(find.text('No coaches available yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await auth.dispose();
  });

  testWidgets(
      'logout during a save cannot show that profile to the next account',
      (tester) async {
    final auth = InMemoryAuthRepository();
    final profiles = FakeProfileGateway();
    final first =
        await auth.signIn(email: 'one@example.com', password: 'password123');
    await profiles.repository(first.scope).save(sampleProfile());
    await mount(tester, auth, profiles);
    await tap(tester, 'Profile');
    await tap(tester, 'Physical profile');
    profiles.pendingWrite = Completer<void>();
    await tap(tester, 'Save changes');
    await auth.signOut();
    await tester.pumpAndSettle();
    await signIn(tester, 'two@example.com');
    profiles.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect(find.text("What's your gender?"), findsOneWidget);
    expect(profiles.records.length, 1);
    await tester.pumpWidget(const SizedBox());
    await auth.dispose();
  });
}
