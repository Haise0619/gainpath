import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class FirebasePasswordResetActions {
  FirebasePasswordResetActions({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;
  Future<void> send(String email) async {
    final emailError = const CredentialsPolicy()
        .validate(email: email, password: 'unused')
        .email;
    if (emailError != null) throw AuthException(emailError);
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Match Firebase's enumeration-protected neutral response.
      if (error.code == 'user-not-found' || error.code == 'user-disabled') {
        return;
      }
      throw AuthException(switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'network-request-failed' => 'Check your connection and retry.',
        'too-many-requests' => 'Too many requests. Wait before trying again.',
        _ => 'Could not request a reset email. Please try again.',
      });
    }
  }
}

class FirebasePasswordActions {
  FirebasePasswordActions({required this.scope, FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final SessionScope scope;
  final FirebaseAuth _auth;

  User _user() {
    final user = _auth.currentUser;
    if (user == null || user.uid != scope.userId || user.email == null) {
      throw const AuthException('Your session changed. Sign in again.');
    }
    return user;
  }

  Future<void> verifyCurrent(String password) async {
    final user = _user();
    try {
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password));
      _user();
    } on FirebaseAuthException catch (error) {
      throw AuthException(switch (error.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'That password is incorrect. Try again.',
        'too-many-requests' => 'Too many attempts. Wait before retrying.',
        _ =>
          'Could not confirm your password. Check your connection and retry.',
      });
    }
  }

  Future<void> saveNew(String password) async {
    try {
      await _user().updatePassword(password);
    } on FirebaseAuthException catch (error) {
      throw AuthException(switch (error.code) {
        'weak-password' => 'Choose a stronger password.',
        'requires-recent-login' =>
          'Your session needs verification again. Reopen Change password.',
        _ => 'Could not change your password. Check your connection and retry.',
      });
    }
  }
}
