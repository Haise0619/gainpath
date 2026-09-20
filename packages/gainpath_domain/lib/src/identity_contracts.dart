import 'identity.dart';

abstract interface class AuthRepository {
  Future<AuthSession> signIn(
      {required AppRole role, required String email, required String password});
  Future<AuthSession> register(
      {required AppRole role,
      required String email,
      required String password,
      required String name});
  Future<void> signOut();
}

/// Session-aware providers implement this alongside the command contract.
abstract interface class AuthSessionLifecycle {
  Stream<AuthSession?> get sessionChanges;
  Future<AuthSession?> restoreSession();
  Future<void> dispose();
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
