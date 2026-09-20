import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

class _FakeFirebaseAuthGateway implements FirebaseAuthGateway {
  _FakeFirebaseAuthGateway({required this.user});

  FirebaseAuthUser user;
  int signOutCalls = 0;
  int verificationCalls = 0;

  @override
  Future<FirebaseAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    return user;
  }

  @override
  Future<FirebaseAuthUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    return user;
  }

  @override
  Future<void> sendEmailVerification() async {
    verificationCalls++;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

void main() {
  test('maps a Firebase user and role claim into an AuthSession', () async {
    final gateway = _FakeFirebaseAuthGateway(
      user: const FirebaseAuthUser(
        userId: 'firebase-user-1',
        email: 'member@example.com',
        emailVerified: true,
        claims: {'role': 'member', 'organizationId': 'org-1'},
      ),
    );
    final repository = FirebaseAuthRepository(gateway);

    final session = await repository.signIn(
      role: AppRole.member,
      email: 'member@example.com',
      password: 'password123',
    );

    expect(session.userId, 'firebase-user-1');
    expect(session.role, AppRole.member);
    expect(session.email, 'member@example.com');
    expect(session.needsVerification, isFalse);
  });

  test('rejects a client role that does not match the server claim', () async {
    final gateway = _FakeFirebaseAuthGateway(
      user: const FirebaseAuthUser(
        userId: 'firebase-user-2',
        email: 'member@example.com',
        claims: {'role': 'member', 'organizationId': 'org-1'},
      ),
    );
    final repository = FirebaseAuthRepository(gateway);

    await expectLater(
      repository.signIn(
        role: AppRole.admin,
        email: 'member@example.com',
        password: 'password123',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('rejects users without a recognized role claim', () async {
    final repository = FirebaseAuthRepository(
      _FakeFirebaseAuthGateway(
        user: const FirebaseAuthUser(
          userId: 'firebase-user-3',
          email: 'unknown@example.com',
          claims: {'organizationId': 'org-1'},
        ),
      ),
    );

    await expectLater(
      repository.signIn(
        role: AppRole.member,
        email: 'unknown@example.com',
        password: 'password123',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('allows only member self-registration and requests verification',
      () async {
    final gateway = _FakeFirebaseAuthGateway(
      user: const FirebaseAuthUser(
        userId: 'firebase-user-4',
        email: 'new@example.com',
        claims: {'role': 'member', 'organizationId': 'org-1'},
      ),
    );
    final repository = FirebaseAuthRepository(gateway);

    final session = await repository.register(
      role: AppRole.member,
      email: 'new@example.com',
      password: 'password123',
      name: 'New Member',
    );

    expect(session.role, AppRole.member);
    expect(session.needsVerification, isTrue);
    expect(gateway.verificationCalls, 1);

    await expectLater(
      repository.register(
        role: AppRole.coach,
        email: 'coach@example.com',
        password: 'password123',
        name: 'Coach',
      ),
      throwsA(isA<AuthException>()),
    );
  });

  test('delegates sign-out to the provider gateway', () async {
    final gateway = _FakeFirebaseAuthGateway(
      user: const FirebaseAuthUser(
        userId: 'firebase-user-5',
        email: 'user@example.com',
        claims: {'role': 'member'},
      ),
    );

    await FirebaseAuthRepository(gateway).signOut();

    expect(gateway.signOutCalls, 1);
  });
}
