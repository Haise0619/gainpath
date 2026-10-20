import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';

class FirebaseCoachProfileRepository implements CoachProfileRepository {
  FirebaseCoachProfileRepository(
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

  Future<T> _read<T>(String collection,
      T Function(String, Map<String, dynamic>?) parse) async {
    _check();
    try {
      final doc = await _db
          .doc('orgs/${scope.organizationId}/$collection/${scope.userId}')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      _check();
      return parse(doc.id, doc.data());
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code);
    }
  }

  @override
  Future<CoachProfessionalProfile?> loadOwn() => _read(
      'coachProfiles',
      (id, data) => data == null
          ? null
          : CoachProfessionalProfile.fromDocument(id, data));
  @override
  Future<PublishedCoachProfile?> loadOwnPublication() => _read(
      'coaches',
      (id, data) =>
          data == null ? null : PublishedCoachProfile.fromDocument(id, data));
  @override
  Future<CoachCommandResult> save(
      {required int expectedRevision,
      required CoachProfilePatch patch,
      required String requestId}) async {
    _check();
    try {
      final response = await _functions
          .httpsCallable('saveCoachProfileCommand')
          .call<Map<String, dynamic>>({
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        'requestId': requestId,
        'expectedRevision': expectedRevision,
        'patch': patch.toJson()
      });
      _check();
      final result = CoachCommandResult.fromJson(response.data);
      if (result.coachId != scope.userId ||
          result.requestId != requestId ||
          result.outcome != 'saved') {
        throw const CoachRepositoryException('failed-precondition');
      }
      return result;
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code);
    }
  }
}
