import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';

class _DelayedAuth implements AuthRepository {
  final pending = Completer<AuthSession>();
  final started = Completer<void>();
  @override
  Future<AuthSession> signIn(
      {required AppRole role,
      required String email,
      required String password}) {
    started.complete();
    return pending.future;
  }

  @override
  Future<AuthSession> register(
          {required AppRole role,
          required String email,
          required String password,
          required String name}) =>
      pending.future;
  @override
  Future<void> signOut() async {}
}

void main() {
  test(
      'restored session is invalidated by logout even if restoration finishes later',
      () async {
    final repository = _RestorableAuth();
    final bloc = AuthBloc(repository: repository);
    await repository.restoring.future;
    bloc.add(const LoggedOut());
    await repository.loggedOut.future;
    repository.restored.complete(
        const AuthSession(email: 'member@example.com', role: AppRole.member));
    repository.changes.add(
        const AuthSession(email: 'member@example.com', role: AppRole.member));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.status, AuthStatus.signedOut);
    expect(bloc.state.session, isNull);
    await bloc.close();
    expect(repository.changes.hasListener, isFalse);
    await repository.dispose();
  });

  test('role policy rejects missing and malformed ownership', () {
    expect(
        AuthRolePolicy.canEnter(
            const AuthState(role: AppRole.member, status: AuthStatus.signedIn),
            allowed: {AppRole.member}),
        isFalse);
    expect(
        AuthRolePolicy.canEnter(
            const AuthState(
                role: AppRole.member,
                status: AuthStatus.signedIn,
                session: AuthSession(
                    userId: '',
                    organizationId: 'org-1',
                    email: 'a@example.com',
                    role: AppRole.member)),
            allowed: {AppRole.member}),
        isFalse);
  });

  test('logout wins over an already running login', () async {
    final repository = _DelayedAuth();
    final bloc = AuthBloc(repository: repository);
    bloc.add(const RoleSelected(AppRole.member));
    bloc.add(const LoginSubmitted(
        email: 'member@example.com', password: 'password123'));
    await repository.started.future;
    bloc.add(const LoggedOut());
    await bloc.stream
        .firstWhere((state) => state.status == AuthStatus.signedOut);
    repository.pending.complete(
        const AuthSession(email: 'member@example.com', role: AppRole.member));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.status, AuthStatus.signedOut);
    expect(bloc.state.session, isNull);
    await bloc.close();
  });
}

class _RestorableAuth extends _DelayedAuth implements AuthSessionLifecycle {
  final changes = StreamController<AuthSession?>.broadcast();
  final restored = Completer<AuthSession?>();
  final restoring = Completer<void>();
  final loggedOut = Completer<void>();
  @override
  Stream<AuthSession?> get sessionChanges => changes.stream;
  @override
  Future<AuthSession?> restoreSession() {
    restoring.complete();
    return restored.future;
  }

  @override
  Future<void> signOut() async {
    loggedOut.complete();
  }

  @override
  Future<void> dispose() => changes.close();
}
