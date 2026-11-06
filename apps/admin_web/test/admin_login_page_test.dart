import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/admin_login_page.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class _CapturingAuthRepository extends InMemoryAuthRepository {
  String? lastSubmittedEmail;
  String? lastSubmittedPassword;
  AppRole? lastRole;

  @override
  Future<AuthSession> signIn({
    AppRole? role,
    required String email,
    required String password,
  }) async {
    lastRole = role;
    lastSubmittedEmail = email;
    lastSubmittedPassword = password;
    return super.signIn(role: role, email: email, password: password);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget buildTestHost({
    AuthRepository? repository,
    Future<void> Function(String)? onPasswordReset,
  }) {
    return GainPathAdminWebApp.injected(
      authRepository: repository ?? InMemoryAuthRepository(),
      passwordResetSender: onPasswordReset,
    );
  }

  testWidgets('desktop view renders two-column layout with brand and features',
      (tester) async {
    tester.view.physicalSize = const Size(1648, 928);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestHost());
    await tester.pumpAndSettle();

    // Left Branding Section checks
    expect(find.text('GainPath'), findsWidgets);
    expect(find.text('ADMIN PORTAL'), findsOneWidget);
    expect(
      find.text('Manage your fitness center operations\nin one place.'),
      findsOneWidget,
    );
    expect(find.text('Member Management'), findsOneWidget);
    expect(find.text('Memberships & Plans'), findsOneWidget);
    expect(find.text('Class & Schedule Management'), findsOneWidget);
    expect(find.text('Reports & Analytics'), findsOneWidget);

    // Right Login Card checks
    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.text('Fitness Center Management Portal'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);

    // Form inputs exist
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('mobile narrow view adapts to single column with compact header',
      (tester) async {
    tester.view.physicalSize = const Size(420, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestHost());
    await tester.pumpAndSettle();

    // Brand and header are present
    expect(find.text('GainPath'), findsWidgets);
    expect(find.text('ADMIN PORTAL'), findsOneWidget);

    // Login Card is present
    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.text('Fitness Center Management Portal'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('validates empty and invalid credentials inline', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestHost());
    await tester.pumpAndSettle();

    // Tap Log In with empty fields
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your admin email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);

    // Enter invalid email format
    await tester.enterText(
        find.widgetWithText(TextField, 'Enter your admin email'),
        'invalid-email');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
  });

  testWidgets('password visibility toggles between obscure and plain text',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestHost());
    await tester.pumpAndSettle();

    final passwordField = find.widgetWithText(TextField, 'Enter your password');
    final initialField = tester.widget<TextField>(passwordField);
    expect(initialField.obscureText, isTrue);

    // Tap visibility toggle icon
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    final revealedField = tester.widget<TextField>(passwordField);
    expect(revealedField.obscureText, isFalse);

    // Tap again to hide
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    final hiddenField = tester.widget<TextField>(passwordField);
    expect(hiddenField.obscureText, isTrue);
  });

  testWidgets('successful credential submission dispatches login',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final capturingRepo = _CapturingAuthRepository();
    final authBloc = AuthBloc(repository: capturingRepo);
    addTearDown(authBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: RepositoryProvider<AuthRepository>.value(
          value: capturingRepo,
          child: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const AdminLoginPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Enter your admin email'),
      'admin@gainpath.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter your password'),
      'SecurePass123!',
    );

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(capturingRepo.lastSubmittedEmail, 'admin@gainpath.com');
    expect(capturingRepo.lastSubmittedPassword, 'SecurePass123!');
    expect(capturingRepo.lastRole, AppRole.admin);
  });

  group('responsive layout verification across target viewports', () {
    for (final size in const [
      Size(1535, 726),
      Size(1440, 900),
      Size(1920, 1080),
      Size(1366, 768),
      Size(768, 1024),
      Size(390, 844),
    ]) {
      testWidgets(
          'renders cleanly without overflow at ${size.width}x${size.height}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildTestHost());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('GainPath'), findsWidgets);
        expect(find.text('Admin Login'), findsOneWidget);
        expect(find.text('Log In'), findsOneWidget);

        // At 1535x726, verify login card width is between 480 and 510 px
        if (size == const Size(1535, 726)) {
          final cardFinder = find.ancestor(
            of: find.text('Admin Login'),
            matching: find.byType(Container),
          );
          final cardRenderBox =
              tester.renderObject(cardFinder.first) as RenderBox;
          expect(cardRenderBox.size.width, inInclusiveRange(480.0, 510.0));
        }
      });
    }
  });
}
