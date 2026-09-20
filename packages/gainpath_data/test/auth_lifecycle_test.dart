import 'dart:async';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

const _user = FirebaseAuthUser(
    userId: 'firebase-user',
    email: 'member@example.com',
    emailVerified: true,
    claims: {'role': 'member', 'organizationId': 'org-1'});

class _Gateway implements FirebaseAuthGateway, FirebaseAuthSessionGateway {
  final controller = StreamController<FirebaseAuthUser?>.broadcast();
  Completer<FirebaseAuthUser>? login;
  final started = Completer<void>();
  FirebaseAuthUser? current = _user;
  @override
  Stream<FirebaseAuthUser?> get userChanges => controller.stream;
  @override
  Future<FirebaseAuthUser?> restoreUser() async => current;
  @override
  Future<FirebaseAuthUser> signIn(
      {required String email, required String password}) async {
    if (!started.isCompleted) started.complete();
    current = login == null ? _user : await login!.future;
    return current!;
  }

  @override
  Future<FirebaseAuthUser> register(
          {required String email,
          required String password,
          required String name}) =>
      signIn(email: email, password: password);
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> signOut() async {
    current = null;
  }
}

void main() {
  test('logout cancels in-flight provider login and leaves provider signed out',
      () async {
    final gateway = _Gateway()..login = Completer<FirebaseAuthUser>();
    final repository = FirebaseAuthRepository(gateway);
    final sessions = <AuthSession?>[];
    final subscription = repository.sessionChanges.listen(sessions.add);
    final login = repository.signIn(
        role: AppRole.member,
        email: 'member@example.com',
        password: 'password');
    final cancelled = expectLater(login, throwsA(isA<AuthException>()));
    await gateway.started.future;
    final logout = repository.signOut();
    gateway.login!.complete(_user);
    await cancelled;
    await logout;
    expect(gateway.current, isNull);
    expect(sessions.whereType<AuthSession>(), isEmpty);
    await subscription.cancel();
    await repository.dispose();
    await gateway.controller.close();
  });

  test('restoration and provider changes retain verified account scope',
      () async {
    final gateway = _Gateway();
    final repository = FirebaseAuthRepository(gateway);
    final session = await repository.restoreSession();
    expect(session?.scope,
        SessionScope(userId: 'firebase-user', organizationId: 'org-1'));
    final signedOut =
        repository.sessionChanges.firstWhere((session) => session == null);
    gateway.controller.add(null);
    await signedOut;
    await repository.dispose();
    await gateway.controller.close();
  });

  test('provider user without organization cannot be restored', () async {
    final gateway = _Gateway()
      ..current = const FirebaseAuthUser(
          userId: 'user', email: 'a@example.com', claims: {'role': 'member'});
    final repository = FirebaseAuthRepository(gateway);
    await expectLater(
        repository.restoreSession(), throwsA(isA<AuthException>()));
    expect(gateway.current, isNull);
    await repository.dispose();
    await gateway.controller.close();
  });

  test('fake IDs are stable and scoped, with instance-owned restored state',
      () async {
    final first = InMemoryAuthRepository(organizationId: 'org-1');
    final second = InMemoryAuthRepository(organizationId: 'org-2');
    final a = await first.signIn(
        role: AppRole.member,
        email: ' Member@Example.com ',
        password: 'password');
    final b = await second.signIn(
        role: AppRole.member,
        email: 'member@example.com',
        password: 'password');
    expect(a.userId, b.userId);
    expect(a.scope, isNot(b.scope));
    final c = await first.signIn(
        role: AppRole.member, email: 'other@example.com', password: 'password');
    expect(c.userId, isNot(a.userId));
    await first.signOut();
    expect(await first.restoreSession(), isNull);
    expect(await second.restoreSession(), b);
    await first.dispose();
    await second.dispose();
  });
}
