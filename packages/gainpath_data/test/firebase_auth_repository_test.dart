import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

class _FakeFirebaseAuthGateway implements FirebaseAuthGateway {
  _FakeFirebaseAuthGateway({required this.user});

  FirebaseAuthUser user;
  int signOutCalls = 0;
  int verificationCalls = 0;
  bool verificationFails = false;

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
    if (verificationFails) throw const AuthException('Connection unavailable.');
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

void main() {
  test(
      'inactive or inconsistent membership claims cannot become active sessions',
      () async {
    for (final status in ['suspended', 'disabled', 'pendingDeletion']) {
      final repository = FirebaseAuthRepository(_FakeFirebaseAuthGateway(
          user: FirebaseAuthUser(
              userId: 'member',
              email: 'member@example.com',
              claims: {
            'role': 'member',
            'organizationId': 'gainpath',
            'branchIds': ['main'],
            'status': status,
          })));
      await expectLater(
          repository.signIn(
              email: 'member@example.com', password: 'password123'),
          throwsA(isA<AuthException>()));
      await repository.dispose();
    }
  });
  test('pending deletion retains scoped recovery session without active access',
      () async {
    final repository = FirebaseAuthRepository(_FakeFirebaseAuthGateway(
        user: const FirebaseAuthUser(
            userId: 'member',
            email: 'member@example.com',
            emailVerified: true,
            claims: {
          'role': 'member',
          'organizationId': 'gainpath',
          'branchIds': ['main'],
          'accountLifecycleState': 'pendingDeletion'
        })));
    final session = await repository.signIn(
        email: 'member@example.com', password: 'password123');
    expect(session.accountLifecycleState, 'pendingDeletion');
    await repository.dispose();
  });
  test('verification delivery failure preserves the created pending account',
      () async {
    final gateway = _FakeFirebaseAuthGateway(
        user: const FirebaseAuthUser(
      userId: 'new-user',
      email: 'new@example.com',
      claims: {
        'role': 'member',
        'organizationId': 'gainpath',
        'branchIds': ['main']
      },
    ))
      ..verificationFails = true;
    final repository = FirebaseAuthRepository(gateway);
    final session = await repository.register(
        role: AppRole.member,
        email: 'new@example.com',
        password: 'password123',
        name: 'New Member');
    expect(session.needsVerification, isTrue);
    expect(gateway.signOutCalls, 0);
    gateway.verificationFails = false;
    await repository.resendEmailVerification();
    expect(gateway.verificationCalls, 2);
    await repository.dispose();
  });

  test('verification resend is throttled and forbidden after logout', () async {
    final gateway = _FakeFirebaseAuthGateway(
        user: const FirebaseAuthUser(
      userId: 'new-user',
      email: 'new@example.com',
      claims: {
        'role': 'member',
        'organizationId': 'gainpath',
        'branchIds': ['main']
      },
    ));
    final repository = FirebaseAuthRepository(gateway);
    await repository.register(
        role: AppRole.member,
        email: 'new@example.com',
        password: 'password123',
        name: 'New Member');
    await expectLater(
        repository.resendEmailVerification(), throwsA(isA<AuthException>()));
    expect(gateway.verificationCalls, 1);
    await repository.signOut();
    await expectLater(
        repository.resendEmailVerification(), throwsA(isA<AuthException>()));
    expect(gateway.verificationCalls, 1);
    await repository.dispose();
  });
  test('shared sign-in uses the coach role from Firebase membership', () async {
    final repository = FirebaseAuthRepository(_FakeFirebaseAuthGateway(
      user: const FirebaseAuthUser(
        userId: 'coach-1',
        email: 'coach@example.com',
        emailVerified: true,
        claims: {
          'role': 'coach',
          'organizationId': 'org-1',
          'branchIds': ['branch-1'],
        },
      ),
    ));
    final session = await repository.signIn(
      email: 'coach@example.com',
      password: 'password123',
    );
    expect(session.role, AppRole.coach);
  });
  test('Firebase Admin Web sign-in accepts only Admin or Staff membership',
      () async {
    for (final role in ['admin', 'staff']) {
      final repository = FirebaseAuthRepository(_FakeFirebaseAuthGateway(
        user: FirebaseAuthUser(
          userId: '$role-1',
          email: '$role@example.com',
          emailVerified: true,
          claims: {
            'role': role,
            'organizationId': 'org-1',
            'branchIds': const <String>[],
          },
        ),
      ));
      final session = await repository.signIn(
        role: AppRole.admin,
        email: '$role@example.com',
        password: 'password123',
      );
      expect(session.role, AppRole.admin);
    }
    final memberRepository = FirebaseAuthRepository(_FakeFirebaseAuthGateway(
      user: const FirebaseAuthUser(
        userId: 'member-1',
        email: 'member@example.com',
        emailVerified: true,
        claims: {
          'role': 'member',
          'organizationId': 'org-1',
          'branchIds': ['branch-1'],
        },
      ),
    ));
    await expectLater(
      memberRepository.signIn(
        role: AppRole.admin,
        email: 'member@example.com',
        password: 'password123',
      ),
      throwsA(isA<AuthException>()),
    );
  });
  test('maps a Firebase user and role claim into an AuthSession', () async {
    final gateway = _FakeFirebaseAuthGateway(
      user: const FirebaseAuthUser(
        userId: 'firebase-user-1',
        email: 'member@example.com',
        displayName: 'New Member',
        emailVerified: true,
        claims: {
          'role': 'member',
          'organizationId': 'org-1',
          'branchIds': ['branch-1']
        },
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
    expect(session.displayName, 'New Member');
    expect(session.branchIds, ['branch-1']);
    expect(session.needsVerification, isFalse);
  });

  test('rejects a client role that does not match the server claim', () async {
    final gateway = _FakeFirebaseAuthGateway(
      user: const FirebaseAuthUser(
        userId: 'firebase-user-2',
        email: 'member@example.com',
        claims: {
          'role': 'member',
          'organizationId': 'org-1',
          'branchIds': ['branch-1']
        },
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
          claims: {
            'organizationId': 'org-1',
            'branchIds': ['branch-1']
          },
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
        claims: {
          'role': 'member',
          'organizationId': 'org-1',
          'branchIds': ['branch-1']
        },
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

  test('rejects member sessions without valid branch scope', () async {
    for (final branchIds in <Object?>[
      null,
      const [],
      const [''],
      const [1]
    ]) {
      final repository = FirebaseAuthRepository(
        _FakeFirebaseAuthGateway(
          user: FirebaseAuthUser(
            userId: 'firebase-user-branch',
            email: 'member@example.com',
            emailVerified: true,
            claims: {
              'role': 'member',
              'organizationId': 'gainpath',
              if (branchIds != null) 'branchIds': branchIds,
            },
          ),
        ),
      );

      await expectLater(
        repository.signIn(
          role: AppRole.member,
          email: 'member@example.com',
          password: 'password123',
        ),
        throwsA(isA<AuthException>()),
      );
    }
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
