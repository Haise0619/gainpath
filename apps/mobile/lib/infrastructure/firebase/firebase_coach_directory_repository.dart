import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';

class FirebaseCoachDirectoryRepository implements CoachDirectoryRepository {
  FirebaseCoachDirectoryRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  @override
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  void _check() {
    if (!isCurrent() || _auth.currentUser?.uid != scope.userId) {
      throw const CoachRepositoryException('permission-denied');
    }
  }

  void _id(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw const CoachRepositoryException('invalid-argument');
    }
  }

  Query<Map<String, dynamic>> get _query => _db
      .collection('orgs/${scope.organizationId}/coaches')
      .where('status', isEqualTo: 'published')
      .orderBy(FieldPath.documentId);
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
      {String? afterId}) async {
    _check();
    try {
      var query = _query;
      if (afterId != null) {
        _id(afterId);
        query = query.startAfter([afterId]);
      }
      final result = await query
          .limit(21)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      _check();
      final items = result.docs
          .take(20)
          .map((d) => PublishedCoachProfile.fromDocument(d.id, d.data()))
          .toList();
      return CoachDirectoryPage(items,
          nextCursor: result.docs.length > 20 ? items.last.id : null);
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code);
    }
  }

  @override
  Future<PublishedCoachProfile?> loadPublished(String coachId) async {
    _check();
    _id(coachId);
    try {
      final result = await _query
          .startAt([coachId])
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      _check();
      if (result.docs.isEmpty || result.docs.single.id != coachId) return null;
      return PublishedCoachProfile.fromDocument(
          coachId, result.docs.single.data());
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code);
    }
  }
}
