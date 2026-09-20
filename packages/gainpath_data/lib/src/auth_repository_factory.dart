import 'auth_repository.dart';
import 'backend_config.dart';
import 'firebase_auth_repository.dart';
import 'in_memory_auth_repository.dart';

class AuthRepositoryFactory {
  const AuthRepositoryFactory._();

  static AuthRepository create({
    required BackendConfig config,
    FirebaseAuthGateway? firebaseGateway,
  }) {
    config.validate();
    if (config.isMock) return InMemoryAuthRepository();
    if (firebaseGateway == null) {
      throw UnsupportedError(
        'Firebase Auth is selected but no FirebaseAuthGateway is configured.',
      );
    }
    return FirebaseAuthRepository(firebaseGateway);
  }
}
