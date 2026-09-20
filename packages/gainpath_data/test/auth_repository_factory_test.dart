import 'package:gainpath_data/gainpath_data.dart';
import 'package:test/test.dart';

void main() {
  test('production rejects mock even when config was constructed directly', () {
    expect(
        () => AuthRepositoryFactory.create(
            config: const BackendConfig(BackendMode.mock, isProduction: true)),
        throwsStateError);
    expect(() => BackendConfig.parse('mock', isProduction: true),
        throwsStateError);
  });
  test('creates the in-memory auth repository for mock mode', () {
    final repository = AuthRepositoryFactory.create(
      config: const BackendConfig(BackendMode.mock),
    );

    expect(repository, isA<InMemoryAuthRepository>());
  });

  test('fails closed for Firebase mode without a configured gateway', () {
    expect(
      () => AuthRepositoryFactory.create(
        config: const BackendConfig(BackendMode.firebase),
      ),
      throwsUnsupportedError,
    );
  });

  test('creates the Firebase repository when a gateway is supplied', () {
    final repository = AuthRepositoryFactory.create(
      config: const BackendConfig(BackendMode.firebase),
      firebaseGateway: _NoopFirebaseGateway(),
    );

    expect(repository, isA<FirebaseAuthRepository>());
  });
}

class _NoopFirebaseGateway implements FirebaseAuthGateway {
  @override
  Future<FirebaseAuthUser> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FirebaseAuthUser> register({
    required String email,
    required String password,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {}
}
