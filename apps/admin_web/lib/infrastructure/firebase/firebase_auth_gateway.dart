import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';

class FlutterFirebaseAuthGateway
    implements FirebaseAuthGateway, FirebaseAuthSessionGateway {
  FlutterFirebaseAuthGateway({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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
