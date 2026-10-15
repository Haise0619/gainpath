import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';

/// Transport seam for the existing catalog repository, not an editing service.
abstract interface class ExerciseCatalogStore {
  Future<Map<String, Map<String, dynamic>>> load();
  Future<Map<String, dynamic>?> readMembership();
  Future<Map<String, dynamic>?> readAssignment();
  Future<Map<String, dynamic>?> readExercise(String id);
  Future<String> create(Map<String, Object?> fields);
  Future<void> transaction(
      Future<void> Function(ExerciseCatalogTransaction) action);
}

abstract interface class ExerciseCatalogTransaction {
  Future<Map<String, dynamic>?> readMembership();
  Future<Map<String, dynamic>?> readAssignment();
  Future<Map<String, dynamic>?> readExercise(String id);
  void update(String id, Map<String, Object?> fields);
}

class FirestoreExerciseCatalogStore implements ExerciseCatalogStore {
  FirestoreExerciseCatalogStore(FirebaseFirestore firestore, SessionScope scope)
      : _firestore = firestore,
        _catalog = firestore
            .collection('orgs')
            .doc(scope.organizationId)
            .collection('exerciseVideos'),
        _member = firestore
            .collection('orgs')
            .doc(scope.organizationId)
            .collection('members')
            .doc(scope.userId),
        _assignment = firestore.collection('users').doc(scope.userId);

  final FirebaseFirestore _firestore;
  final CollectionReference<Map<String, dynamic>> _catalog;
  final DocumentReference<Map<String, dynamic>> _member;
  final DocumentReference<Map<String, dynamic>> _assignment;

  @override
  Future<Map<String, Map<String, dynamic>>> load() async {
    final snapshot =
        await _catalog.get(const GetOptions(source: Source.server));
    return {for (final document in snapshot.docs) document.id: document.data()};
  }

  @override
  Future<Map<String, dynamic>?> readMembership() async =>
      (await _member.get(const GetOptions(source: Source.server))).data();
  @override
  Future<Map<String, dynamic>?> readAssignment() async =>
      (await _assignment.get(const GetOptions(source: Source.server))).data();
  @override
  Future<Map<String, dynamic>?> readExercise(String id) async =>
      (await _catalog.doc(id).get(const GetOptions(source: Source.server)))
          .data();
  @override
  Future<String> create(Map<String, Object?> fields) async {
    final reference = _catalog.doc();
    await reference.set({
      ...fields,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp()
    });
    return reference.id;
  }

  @override
  Future<void> transaction(
          Future<void> Function(ExerciseCatalogTransaction) action) =>
      runCatalogTransactionPreservingFailures(
          (callback) => _firestore.runTransaction<void>((transaction) =>
              callback(_FirestoreCatalogTransaction(
                  transaction, _catalog, _member, _assignment))),
          action);
}

/// Flutter web wraps Dart callback exceptions in JS errors. Keep safe domain
/// failures outside the retryable callback so callers still receive their type.
Future<void> runCatalogTransactionPreservingFailures(
    Future<void> Function(Future<void> Function(ExerciseCatalogTransaction))
        runner,
    Future<void> Function(ExerciseCatalogTransaction) action) async {
  Object? failure;
  try {
    await runner((transaction) async {
      if (failure != null) throw StateError('Catalog edit aborted.');
      try {
        await action(transaction);
      } on TutorialEditConflict catch (error) {
        failure = error;
        throw StateError('Catalog edit aborted.');
      } on TutorialEditAuthorizationChanged catch (error) {
        failure = error;
        throw StateError('Catalog edit aborted.');
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied' ||
            error.code == 'unauthenticated') {
          failure = const TutorialEditAuthorizationChanged();
          throw StateError('Catalog edit aborted.');
        }
        rethrow;
      }
    });
  } catch (_) {
    if (failure != null) throw failure!;
    rethrow;
  }
}

class _FirestoreCatalogTransaction implements ExerciseCatalogTransaction {
  _FirestoreCatalogTransaction(
      this._transaction, this._catalog, this._member, this._assignment);
  final Transaction _transaction;
  final CollectionReference<Map<String, dynamic>> _catalog;
  final DocumentReference<Map<String, dynamic>> _member;
  final DocumentReference<Map<String, dynamic>> _assignment;
  @override
  Future<Map<String, dynamic>?> readMembership() async =>
      (await _transaction.get(_member)).data();
  @override
  Future<Map<String, dynamic>?> readAssignment() async =>
      (await _transaction.get(_assignment)).data();
  @override
  Future<Map<String, dynamic>?> readExercise(String id) async =>
      (await _transaction.get(_catalog.doc(id))).data();
  @override
  void update(String id, Map<String, Object?> fields) => _transaction.update(
      _catalog.doc(id), {...fields, 'updatedAt': FieldValue.serverTimestamp()});
}
