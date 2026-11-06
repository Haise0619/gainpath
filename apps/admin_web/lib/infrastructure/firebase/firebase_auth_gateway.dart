import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_function_transport.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';

class FlutterFirebaseAuthGateway
    implements FirebaseAuthGateway, FirebaseAuthSessionGateway {
  FlutterFirebaseAuthGateway(
      {FirebaseAuth? auth,
      FirebaseFirestore? firestore,
      FirebaseFunctions? functions})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') return;
      throw AuthException(switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'network-request-failed' => 'Check your connection and retry.',
        'too-many-requests' => 'Too many requests. Wait before trying again.',
        _ => 'Could not request a reset email. Please try again.',
      });
    }
  }

  @override
  Stream<FirebaseAuthUser?> get userChanges =>
      _auth.authStateChanges().asyncMap(_resolveNullableUser);

  @override
  Future<FirebaseAuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _resolveUser(credential.user!);
  }

  @override
  Future<FirebaseAuthUser> register({
    required String email,
    required String password,
    required String name,
  }) =>
      Future.error(StateError(
          'Administrator accounts must be provisioned by an authorized backend process.'));

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
    return _resolveUser(refreshed);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<FirebaseAuthUser?> _resolveNullableUser(User? user) async =>
      user == null ? null : _resolveUser(user);

  Future<FirebaseAuthUser> _resolveUser(User user) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('The authenticated account has no email address.');
    }
    // Only absence/Rules denial falls back to ordinary membership resolution.
    // A found assignment must complete protected authorization before any
    // canonical lookup or registration provisioning can occur.
    Map<String, dynamic>? assignment;
    try {
      assignment = (await _firestore
              .collection('datasetAssignments')
              .doc(user.uid)
              .get(const GetOptions(source: Source.server)))
          .data();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }
    if (assignment != null) {
      final response = await firebaseCallable('fypDatasetSessionCommand',
              functions: _functions)
          .call<Object?>({'schemaVersion': 1});
      final session = FypDatasetSession.fromResponse(response.data);
      return FirebaseAuthUser(
          userId: user.uid,
          email: email,
          displayName: session.member['displayName'] as String?,
          emailVerified: user.emailVerified,
          datasetScope: session.scope,
          claims: {
            'organizationId': session.member['organizationId'],
            'role': session.member['role'],
            'status': session.member['status'],
            'branchIds': session.member['branchIds']
          });
    }
    final userData =
        (await _firestore.collection('users').doc(user.uid).get()).data();
    final organizationId = userData?['organizationId'];
    if (userData == null || organizationId is! String) {
      throw StateError('The account has no user assignment.');
    }
    final memberData = (await _firestore
            .collection('orgs')
            .doc(organizationId)
            .collection('members')
            .doc(user.uid)
            .get())
        .data();
    if (memberData == null ||
        memberData['organizationId'] != organizationId ||
        memberData['status'] != 'active') {
      throw StateError('The account has no active organization membership.');
    }
    return FirebaseAuthUser(
      userId: user.uid,
      email: email,
      displayName: userData['displayName'] is String &&
              (userData['displayName'] as String).trim().isNotEmpty
          ? (userData['displayName'] as String).trim()
          : null,
      emailVerified: user.emailVerified,
      claims: {
        'organizationId': organizationId,
        'role': memberData['role'],
        'status': memberData['status'],
        'branchIds': memberData['branchIds'],
      },
    );
  }
}
