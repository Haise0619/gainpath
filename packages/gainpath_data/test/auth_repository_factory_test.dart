import 'package:gainpath_data/gainpath_data.dart';
import 'package:test/test.dart';

void main() {
  test('fails closed for Firebase mode without a configured gateway', () {
    expect(
      () => AuthRepositoryFactory.create(),
      throwsUnsupportedError,
    );
  });

  test('creates the Firebase repository when a gateway is supplied', () {
    final repository = AuthRepositoryFactory.create(
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
