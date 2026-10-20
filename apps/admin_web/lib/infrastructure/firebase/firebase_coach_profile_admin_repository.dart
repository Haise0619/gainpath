import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';

class FirebaseCoachProfileAdminRepository
    implements CoachProfileAdminRepository {
  FirebaseCoachProfileAdminRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFirestore? firestore,
      FirebaseFunctions? functions,
      FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;
  @override
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  void _check() {
    if (!isCurrent() || _auth.currentUser?.uid != scope.userId) {
      throw const CoachRepositoryException('permission-denied');
    }
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    _check();
    try {
      final doc = await _db
          .doc(path)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      _check();
      return doc.data();
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code);
    }
  }

  @override
  Future<bool> canManageDirectory() async {
    final user = await _get('users/${scope.userId}'),
        membership =
            await _get('orgs/${scope.organizationId}/members/${scope.userId}');
    return user?['organizationId'] == scope.organizationId &&
        membership?['organizationId'] == scope.organizationId &&
        membership?['status'] == 'active' &&
        membership?['role'] == 'admin';
  }

  Future<void> _admin() async {
    _check();
    if (!await canManageDirectory()) {
      throw const CoachRepositoryException('permission-denied');
    }
  }

  Future<CoachDirectoryPage<T>> _page<T>(String collection, String? cursor,
      T Function(String, Map<String, dynamic>) parse) async {
    await _admin();
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('orgs/${scope.organizationId}/$collection')
          .orderBy(FieldPath.documentId);
      if (cursor != null) {
        _id(cursor);
        query = query.startAfter([cursor]);
      }
      final docs = await query
          .limit(21)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      await _admin();
      final items =
          docs.docs.take(20).map((d) => parse(d.id, d.data())).toList();
      return CoachDirectoryPage(items,
          nextCursor: docs.docs.length > 20 ? docs.docs[19].id : null);
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code);
    }
  }

  void _id(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw const CoachRepositoryException('invalid-argument');
    }
  }

  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
          {String? afterId}) =>
      _page('coachProfiles', afterId, CoachProfessionalProfile.fromDocument);
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
          {String? afterId}) =>
      _page('coaches', afterId, PublishedCoachProfile.fromDocument);
  @override
  Future<CoachPublicationReview> loadReview(String coachId) async {
    await _admin();
    _id(coachId);
    final root = 'orgs/${scope.organizationId}';
    final draft = await _get('$root/coachProfiles/$coachId'),
        publication = await _get('$root/coaches/$coachId');
    Map<String, dynamic>? membership;
    try {
      membership = await _get('$root/members/$coachId');
    } on CoachRepositoryException catch (e) {
      if (!['permission-denied', 'not-found'].contains(e.code)) rethrow;
    }
    Map<String, dynamic>? certSummary;
    try {
      certSummary = await _get('$root/coachProfiles/$coachId/certificationState/current');
    } on CoachRepositoryException catch (e) {
      if (!['permission-denied', 'not-found'].contains(e.code)) rethrow;
    }
    // Users/Auth are private and not client-readable by this Admin. The trusted
    // publication command independently verifies target assignment/Auth.
    final rawBranches = membership?['branchIds'];
    final validBranches = rawBranches is List &&
        rawBranches.isNotEmpty &&
        rawBranches.length <= 8 &&
        rawBranches.every((v) =>
            v is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(v)) &&
        rawBranches.toSet().length == rawBranches.length;
    final certVerified = certSummary?['certificationVerified'] == true;
    final rawApprovedCount = certSummary?['approvedCount'];
    final approvedCount =
        rawApprovedCount is num ? rawApprovedCount.toInt() : 0;
    await _admin();
    return CoachPublicationReview(
        coachId: coachId,
        draft: draft == null
            ? null
            : CoachProfessionalProfile.fromDocument(coachId, draft),
        publication: publication == null
            ? null
            : PublishedCoachProfile.fromDocument(coachId, publication),
        branchIds: validBranches ? List<String>.from(rawBranches) : [],
        targetMembershipEligible: membership?['role'] == 'coach' &&
            membership?['status'] == 'active' &&
            membership?['organizationId'] == scope.organizationId &&
            validBranches,
        certificationVerified: certVerified,
        approvedCertificationCount: approvedCount);
  }

  @override
  Future<CoachCommandResult> setStatus(
      {required CoachPublicationReview baseline,
      required CoachDirectoryAction action,
      required String requestId}) async {
    await _admin();
    _id(baseline.coachId);
    if (action == CoachDirectoryAction.publish && !baseline.canPublish) {
      if (!baseline.certificationVerified ||
          baseline.approvedCertificationCount <= 0) {
        throw const CoachRepositoryException('failed-precondition',
            'An approved certification is required for publication.');
      }
      throw const CoachRepositoryException('failed-precondition');
    }
    try {
      final response = await _functions
          .httpsCallable('setCoachDirectoryStatusCommand')
          .call<Map<String, dynamic>>({
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        'coachId': baseline.coachId,
        'requestId': requestId,
        'action': action.name,
        'expectedPublicRevision': baseline.publicRevision,
        if (action == CoachDirectoryAction.publish) ...{
          'expectedProfileRevision': baseline.draft!.revision,
          'expectedCoachBranchIds': baseline.branchIds
        }
      });
      await _admin();
      final result = CoachCommandResult.fromJson(response.data);
      if (result.requestId != requestId ||
          result.coachId != baseline.coachId ||
          result.outcome !=
              (action == CoachDirectoryAction.publish
                  ? 'published'
                  : 'inactive')) {
        throw const CoachRepositoryException('failed-precondition');
      }
      return result;
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code, e.message);
    }
  }
}
