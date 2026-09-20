import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';

Map<String, Object?> membershipClaims({
  required Map<String, Object?> userData,
  required Map<String, Object?> memberData,
}) {
  final organizationId = userData['organizationId'];
  if (organizationId is! String ||
      organizationId.trim().isEmpty ||
      memberData['organizationId'] != organizationId ||
      memberData['status'] != 'active') {
    throw StateError('The account has no active organization membership.');
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
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
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
      return _resolveUser(user, provisionIfMissing: true);
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
      return _resolveUser(user);
    } finally {
      _authMutationInProgress = false;
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user.');
    await user.sendEmailVerification();
  }

  @override
  Future<FirebaseAuthUser?> restoreUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final refreshed = _auth.currentUser!;
    await refreshed.getIdToken(true);
    return _resolveUser(refreshed, provisionIfMissing: true);
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
      emailVerified: user.emailVerified,
      claims: membershipClaims(
        userData: userData.cast<String, Object?>(),
        memberData: memberData.cast<String, Object?>(),
      ),
    );
  }

  Future<void> _provision(String displayName) =>
      _functions.httpsCallable('provisionMemberRegistration').call<void>({
        'schemaVersion': 1,
        'displayName': displayName,
      });

  String _fallbackDisplayName(User user) {
    final current = user.displayName?.trim();
    if (current != null && current.isNotEmpty) return current;
    final localPart = (user.email ?? '').split('@').first.trim();
    return localPart.isEmpty ? 'GainPath Member' : localPart;
  }
}
