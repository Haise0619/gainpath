import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';

class FlutterMemberPhotoGateway implements MemberPhotoGateway {
  FlutterMemberPhotoGateway(
      {required this.scope,
      required this.isCurrent,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  bool _invalidated = false;
  String? _email;
  DocumentReference<Map<String, dynamic>> get _user =>
      _db.doc('users/${scope.userId}');
  DocumentReference<Map<String, dynamic>> get _member =>
      _db.doc('orgs/${scope.organizationId}/members/${scope.userId}');
  void _check() {
    final user = _auth.currentUser;
    if (_invalidated ||
        !isCurrent() ||
        user?.uid != scope.userId ||
        user?.emailVerified != true ||
        (_email != null && user?.email != _email)) {
      _invalidated = true;
      throw const MemberPhotoException('Your session changed. Sign in again.',
          reloadRequired: true);
    }
    _email ??= user?.email;
  }

  MemberPhotoDocuments _documents(
      Map<String, dynamic>? user, Map<String, dynamic>? member) {
    _check();
    if (user?['organizationId'] != scope.organizationId ||
        member?['organizationId'] != scope.organizationId ||
        member?['role'] != 'member' ||
        member?['status'] != 'active') {
      _invalidated = true;
      throw const MemberPhotoException('Profile photo access was denied.',
          reloadRequired: true);
    }
    return MemberPhotoDocuments(user!, member!);
  }

  @override
  Future<MemberPhotoDocuments> read() async {
    _check();
    final user = await _user.get(const GetOptions(source: Source.server));
    final member = await _member.get(const GetOptions(source: Source.server));
    return _documents(user.data(), member.data());
  }

  @override
  Future<void> write(MemberPhotoDocuments expected, String path) async {
    _check();
    Object? failure;
    try {
      await _db.runTransaction<void>((tx) async {
        if (failure != null) throw StateError('Photo save aborted.');
        try {
          _check();
          final user = await tx.get(_user);
          final member = await tx.get(_member);
          final current = _documents(user.data(), member.data());
          if (!sameMemberDocumentValue(current.member, expected.member)) {
            _invalidated = true;
            throw const MemberPhotoException(
                'Your account changed. Sign in again.',
                reloadRequired: true);
          }
          if (!sameMemberDocumentValue(current.user, expected.user)) {
            throw const MemberPhotoException(
                'Your account changed elsewhere. Reload before saving.',
                reloadRequired: true);
          }
          tx.update(_user, {
            'memberPhotoPath': path,
            'updatedAtMillis': DateTime.now().millisecondsSinceEpoch
          });
        } on MemberPhotoException catch (e) {
          failure = e;
          throw StateError('Photo save aborted.');
        }
      }, timeout: const Duration(seconds: 20));
      _check();
    } catch (_) {
      if (failure != null) throw failure!;
      rethrow;
    }
  }
}
