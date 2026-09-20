import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/profile_setup_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'registration verifies the demo session and reaches profile setup',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = InMemoryAuthRepository();
    await tester.pumpWidget(GainPathMobileApp(authRepository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'New Member');
    await tester.enterText(find.byType(TextField).at(1), 'new@example.com');
    await tester.tap(find.byType(Checkbox));
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text("I've verified my email"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    expect((await repository.restoreSession())!.needsVerification, isFalse);
    await tester.pumpWidget(const SizedBox());
    await repository.dispose();
  });
  testWidgets('mobile app host boots', (tester) async {
    await tester.pumpWidget(const GainPathMobileApp());
    await tester.pumpAndSettle();
    expect(find.text('GainPath Mobile'), findsOneWidget);
    expect(find.text('Sign in to GainPath Mobile'), findsOneWidget);
    expect(find.text('Gym Member'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('View introduction'), findsOneWidget);
  });

  testWidgets('Firebase registration opens without demo repositories',
      (tester) async {
    final repository = InMemoryAuthRepository();
    await tester.pumpWidget(GainPathMobileApp(
      authRepository: repository,
      backendConfig: const BackendConfig(BackendMode.firebase),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await repository.dispose();
  });

  testWidgets('authenticated member can enter the local workout flow',
      (tester) async {
    await tester.pumpWidget(const GainPathMobileApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'member@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });
}
