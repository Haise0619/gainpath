import 'auth_repository.dart';
import 'firebase_auth_repository.dart';

class AuthRepositoryFactory {
  const AuthRepositoryFactory._();

  static AuthRepository create({
    FirebaseAuthGateway? firebaseGateway,
  }) {
    if (firebaseGateway == null) {
      throw UnsupportedError(
        'Firebase Auth is selected but no FirebaseAuthGateway is configured.',
      );
    }
    return FirebaseAuthRepository(firebaseGateway);
  }
}
