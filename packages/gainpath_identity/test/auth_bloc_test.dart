import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';

class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.fail = false});

  final bool fail;
  int signInCalls = 0;
  int registerCalls = 0;

  @override
  Future<AuthSession> signIn({
    required AppRole role,
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (fail) throw const AuthException('Unable to sign in.');
    return AuthSession(email: email, role: role);
  }

  @override
  Future<AuthSession> register({
    required AppRole role,
    required String email,
    required String password,
    required String name,
  }) async {
    registerCalls++;
    if (fail) throw const AuthException('Unable to register.');
    return AuthSession(
      email: email,
      role: role,
      needsVerification: role == AppRole.member,
    );
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'rejects invalid credentials without calling the repository',
      build: () => AuthBloc(repository: _RecordingAuthRepository()),
      act: (bloc) {
        bloc.add(const RoleSelected(AppRole.member));
        bloc.add(const LoginSubmitted(email: 'bad', password: ''));
      },
      expect: () => [
        const AuthState(role: AppRole.member),
        const AuthState(
          role: AppRole.member,
          fieldErrors: CredentialErrors(
            email: 'Enter a valid email address.',
            password: 'Enter your password.',
          ),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'requires terms before member registration',
      build: () => AuthBloc(repository: _RecordingAuthRepository()),
      act: (bloc) async {
        bloc.add(const RoleSelected(AppRole.member));
        bloc.add(
          const LoginSubmitted(
            email: 'member@example.com',
            password: 'password123',
            name: 'Member',
            confirm: 'password123',
            registering: true,
          ),
        );
      },
      expect: () => [
        const AuthState(role: AppRole.member),
        const AuthState(
          role: AppRole.member,
          message: AuthBloc.termsError,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'signs in through the repository and preserves the selected role',
      build: () => AuthBloc(repository: _RecordingAuthRepository()),
      act: (bloc) async {
        bloc.add(const RoleSelected(AppRole.coach));
        bloc.add(
          const LoginSubmitted(
            email: 'coach@example.com',
            password: 'password123',
          ),
        );
      },
      wait: const Duration(milliseconds: 5),
      expect: () => [
        const AuthState(role: AppRole.coach),
        const AuthState(role: AppRole.coach, status: AuthStatus.submitting),
        const AuthState(
          role: AppRole.coach,
          status: AuthStatus.signedIn,
          email: 'coach@example.com',
          session: AuthSession(email: 'coach@example.com', role: AppRole.coach),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'maps repository failures to a recoverable signed-out state',
      build: () => AuthBloc(repository: _RecordingAuthRepository(fail: true)),
      act: (bloc) async {
        bloc.add(const RoleSelected(AppRole.admin));
        bloc.add(
          const LoginSubmitted(
            email: 'admin@example.com',
            password: 'password123',
          ),
        );
      },
      wait: const Duration(milliseconds: 5),
      expect: () => [
        const AuthState(role: AppRole.admin),
        const AuthState(role: AppRole.admin, status: AuthStatus.submitting),
        const AuthState(
          role: AppRole.admin,
          message: 'Unable to sign in.',
        ),
      ],
    );
  });

  test('role policy limits each application to its own roles', () {
    const memberState = AuthState(
      session: AuthSession(email: 'member@example.com', role: AppRole.member),
      role: AppRole.member,
      status: AuthStatus.signedIn,
    );
    const adminState = AuthState(
      session: AuthSession(email: 'admin@example.com', role: AppRole.admin),
      role: AppRole.admin,
      status: AuthStatus.signedIn,
    );

    expect(AuthRolePolicy.canEnter(memberState, allowed: {AppRole.member}),
        isTrue);
    expect(AuthRolePolicy.canEnter(memberState, allowed: {AppRole.admin}),
        isFalse);
    expect(
        AuthRolePolicy.canEnter(adminState, allowed: {AppRole.admin}), isTrue);
  });
}
