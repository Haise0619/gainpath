import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'firebase_function_transport.dart';

String firebaseAuthFailureMessage(String code) => switch (code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'Email or password is incorrect.',
      'email-already-in-use' => 'This email is already registered.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Choose a stronger password.',
      'network-request-failed' =>
        'Could not reach Firebase. Check your internet connection and retry.',
      'too-many-requests' => 'Too many attempts. Wait a while and try again.',
      'user-disabled' => 'This account is disabled. Contact gym staff.',
      'user-token-expired' ||
      'invalid-user-token' =>
        'Your session has expired. Sign in again.',
      'operation-not-allowed' =>
        'Email and password sign-in is not enabled for this Firebase project.',
      _ => 'Unable to complete authentication. Please try again.',
    };

Map<String, Object?> membershipClaims({
  required Map<String, Object?> userData,
  required Map<String, Object?> memberData,
}) {
  final organizationId = userData['organizationId'];
  if (organizationId is! String ||
      organizationId.trim().isEmpty ||
      memberData['organizationId'] != organizationId) {
    throw StateError('The account has no active organization membership.');
  }
  final lifecycleData = userData['accountLifecycle'];
  final lifecycle = lifecycleData == null
      ? 'active'
      : lifecycleData is Map
          ? lifecycleData['state']
          : null;
  final status = memberData['status'];
  if (status == 'suspended' || userData['status'] == 'suspended') {
    throw const AuthException('This account is suspended. Contact gym staff.');
  }
  if (lifecycle == 'pendingDeletion' &&
      status == 'pendingDeletion' &&
      memberData['role'] == 'member') {
    return {
      'organizationId': organizationId,
      'role': memberData['role'],
      'status': status,
      'branchIds': memberData['branchIds'],
      'accountLifecycleState': 'pendingDeletion',
    };
  }
  if (lifecycle != 'active' ||
      status != 'active' ||
      (userData['status'] != null && userData['status'] != 'active')) {
    throw const AuthException(
        'This account has an unavailable or inconsistent membership. Contact gym staff.');
  }
  return {
    'organizationId': organizationId,
    'role': memberData['role'],
    'status': memberData['status'],
    'branchIds': memberData['branchIds'],
  };
}

class FlutterFirebaseAuthGateway
    implements FirebaseAuthGateway, FirebaseAuthSessionGateway {
  FlutterFirebaseAuthGateway({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;
  final Set<String> _suppressedRegistrationUsers = <String>{};
  bool _authMutationInProgress = false;

  @override
  Stream<FirebaseAuthUser?> get userChanges =>
      _auth.authStateChanges().asyncExpand((user) {
        if (_authMutationInProgress ||
            (user != null && _suppressedRegistrationUsers.contains(user.uid))) {
          return const Stream<FirebaseAuthUser?>.empty();
        }
        return Stream.fromFuture(_resolveNullableUser(user));
      });

  @override
  Future<FirebaseAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _authMutationInProgress = true;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      _suppressedRegistrationUsers.remove(user.uid);
      return await _resolveUser(user, provisionIfMissing: true);
    } on AuthException {
      rethrow;
    } on StateError catch (error) {
      throw AuthException(error.message.toString());
    } on FirebaseAuthException catch (error) {
      throw AuthException(firebaseAuthFailureMessage(error.code));
    } on FirebaseException catch (error) {
      throw AuthException(error.code == 'permission-denied'
          ? 'This account cannot access its gym membership. Contact gym staff.'
          : 'Could not reach your account. Check your connection and retry.');
    } finally {
      _authMutationInProgress = false;
    }
  }

  @override
  Future<FirebaseAuthUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _authMutationInProgress = true;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      _suppressedRegistrationUsers.add(user.uid);
      try {
        await user.updateDisplayName(name.trim());
      } on FirebaseAuthException {
        // Membership stores the submitted name even if the optional Auth
        // profile update is temporarily unavailable.
      }
      await _provision(name.trim());
      return await _resolveUser(user);
    } on AuthException catch (error) {
      if (_auth.currentUser != null) {
        throw AuthException(
            '${error.message} Your account may already exist. Sign in with the same email and password to retry setup.');
      }
      rethrow;
    } on StateError catch (error) {
      throw AuthException(
          '${error.message} Sign in with the same email and password to retry setup.');
    } on FirebaseAuthException catch (error) {
      throw AuthException(firebaseAuthFailureMessage(error.code));
    } on FirebaseException catch (error) {
      throw AuthException(error.code == 'permission-denied'
          ? 'Account setup was denied. Contact gym staff.'
          : 'Could not finish account setup. Check your connection and retry.');
    } finally {
      _authMutationInProgress = false;
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
          'Sign in again to request a verification link.');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthException(firebaseAuthFailureMessage(error.code));
    }
  }

  @override
  Future<FirebaseAuthUser?> restoreUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null || refreshed.uid != user.uid) {
        throw const AuthException('Your session changed. Sign in again.');
      }
      await refreshed.getIdToken(true);
      return await _resolveUser(refreshed, provisionIfMissing: true);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'network-request-failed') {
        throw const FirebaseAuthRefreshUnavailable(
            'Could not reload your account. Check your connection and retry.');
      }
      throw AuthException(firebaseAuthFailureMessage(error.code));
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable' ||
          error.code == 'deadline-exceeded' ||
          error.code == 'network-request-failed') {
        throw const FirebaseAuthRefreshUnavailable(
            'Could not reload your account. Check your connection and retry.');
      }
      throw const AuthException(
          'Could not reload your account. Check your connection and retry.');
    } on StateError catch (error) {
      throw AuthException(error.message.toString());
    }
  }

  @override
  Future<void> signOut() async {
    _suppressedRegistrationUsers.clear();
    await _auth.signOut();
  }

  Future<FirebaseAuthUser?> _resolveNullableUser(User? user) async =>
      user == null ? null : _resolveUser(user);

  Future<FirebaseAuthUser> _resolveUser(
    User user, {
    bool provisionIfMissing = false,
  }) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('The authenticated account has no email address.');
    }
    final userSnapshot =
        await _firestore.collection('users').doc(user.uid).get();
    var userData = userSnapshot.data();
    if (userData == null && provisionIfMissing) {
      await _provision(_fallbackDisplayName(user));
      userData =
          (await _firestore.collection('users').doc(user.uid).get()).data();
    }
    final organizationId = userData?['organizationId'];
    if (userData == null || organizationId is! String) {
      throw StateError('The account has no user assignment.');
    }
    var memberData = (await _firestore
            .collection('orgs')
            .doc(organizationId)
            .collection('members')
            .doc(user.uid)
            .get())
        .data();
    if (memberData == null && provisionIfMissing) {
      await _provision(_fallbackDisplayName(user));
      memberData = (await _firestore
              .collection('orgs')
              .doc(organizationId)
              .collection('members')
              .doc(user.uid)
              .get())
          .data();
    }
    if (memberData == null) {
      throw StateError('The account has no organization membership.');
    }
    return FirebaseAuthUser(
      userId: user.uid,
      email: email,
      displayName: memberData['displayName'] is String
          ? memberData['displayName'] as String
          : userData['displayName'] is String
              ? userData['displayName'] as String
              : null,
      emailVerified: user.emailVerified,
      claims: membershipClaims(
        userData: userData.cast<String, Object?>(),
        memberData: memberData.cast<String, Object?>(),
      ),
    );
  }

  Future<void> _provision(String displayName) async {
    try {
      await firebaseCallable('provisionMemberRegistration',
              functions: _functions)
          .call<void>({
        'schemaVersion': 1,
        'displayName': displayName,
      });
    } on FirebaseFunctionsException catch (error) {
      throw AuthException(error.code == 'not-found'
          ? 'Account setup service is not deployed. Contact the project administrator.'
          : 'Account setup failed (${error.code}). Please retry or contact the project administrator.');
    }
  }

  String _fallbackDisplayName(User user) {
    final current = user.displayName?.trim();
    if (current != null && current.isNotEmpty) return current;
    final localPart = (user.email ?? '').split('@').first.trim();
    return localPart.isEmpty ? 'GainPath Member' : localPart;
  }
}
