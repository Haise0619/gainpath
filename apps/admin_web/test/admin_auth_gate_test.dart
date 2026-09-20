import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:google_fonts/google_fonts.dart';

class _UnverifiedAdminRepository
    implements AuthRepository, AuthSessionLifecycle, AuthVerificationActions {
  static const session = AuthSession(
    userId: 'admin-1',
    organizationId: 'gainpath',
    branchIds: [],
    email: 'admin@gainpath.test',
    role: AppRole.admin,
    needsVerification: true,
  );

  @override
  Stream<AuthSession?> get sessionChanges => const Stream.empty();

  @override
  Future<AuthSession?> restoreSession() async => session;

  @override
  Future<void> resendEmailVerification() async {}

  @override
  Future<AuthSession> register({
    required AppRole role,
    required String email,
    required String password,
    required String name,
  }) async =>
      session;

  @override
  Future<AuthSession> signIn({
    required AppRole role,
    required String email,
    required String password,
  }) async =>
      session;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('unverified administrators receive verification actions',
      (tester) async {
    await tester.pumpWidget(GainPathAdminWebApp(
      authRepository: _UnverifiedAdminRepository(),
      backendConfig: const BackendConfig(BackendMode.firebase),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text("I've verified my email"), findsOneWidget);
    expect(find.text('Resend verification email'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });
}
