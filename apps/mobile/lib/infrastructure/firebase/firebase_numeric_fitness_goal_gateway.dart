import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class FlutterNumericFitnessGoalGateway implements NumericFitnessGoalGateway {
  FlutterNumericFitnessGoalGateway(
      {FirebaseFirestore? firestore,
      FirebaseAuth? auth,
      required this.isSessionCurrent})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final bool Function() isSessionCurrent;

  void _check(SessionScope scope) {
    if (_auth.currentUser?.uid != scope.userId ||
        _auth.currentUser?.emailVerified != true ||
        !isSessionCurrent()) {
      throw const NumericGoalException('Your session changed. Sign in again.',
          reloadRequired: true);
    }
  }

  CollectionReference<Map<String, dynamic>> _goals(SessionScope scope) {
    _check(scope);
    return _firestore
        .collection('orgs')
        .doc(scope.organizationId)
        .collection('profiles')
        .doc(scope.userId)
        .collection('goals');
  }

  @override
  String allocateId(SessionScope scope) => _goals(scope).doc().id;

  @override
  Future<Map<String, Map<String, Object?>>> readActive(SessionScope scope,
      {required int limit}) async {
    try {
      final snapshot = await _goals(scope)
          .where('status', isEqualTo: 'active')
          .limit(limit)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      _check(scope);
      return {
        for (final doc in snapshot.docs)
          doc.id: {
            ...doc.data(),
            'createdAt':
                (doc.data()['createdAt'] as Timestamp?)?.toDate().toUtc(),
            'updatedAt':
                (doc.data()['updatedAt'] as Timestamp?)?.toDate().toUtc(),
          }
      };
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on TimeoutException {
      throw const NumericGoalException(
          'Loading targets took too long. Check your connection and retry.');
    }
  }

  @override
  Future<void> commit(
      SessionScope scope, String id, Map<String, Object?> fields,
      {required int? expectedRevision}) async {
    validateGoalId(id);
    try {
      final ref = _goals(scope).doc(id);
      final intended = Map<String, Object?>.unmodifiable(fields);
      await _firestore.runTransaction<void>((transaction) async {
        _check(scope);
        final snapshot = await transaction.get(ref);
        _check(scope);
        final old = snapshot.data();
        if (expectedRevision == null &&
            old != null &&
            old['revision'] == 1 &&
            intended.entries.every((e) => old[e.key] == e.value)) {
          // A timed-out first create may already have committed. The retained
          // document ID and identical intended payload make the retry harmless.
          return;
        }
        if ((expectedRevision == null && old != null) ||
            (expectedRevision != null &&
                (old == null ||
                    old['revision'] != expectedRevision ||
                    old['status'] != 'active'))) {
          throw const NumericGoalException(
              'This target changed elsewhere. Reload targets before saving.',
              reloadRequired: true);
        }
        final revision = (expectedRevision ?? 0) + 1;
        final next = <String, Object?>{
          ...?old,
          ...intended,
          'revision': revision,
          if (old == null) 'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        transaction.set(ref, next);
        // Immutable snapshots preserve the meaning of goalId + revision for
        // future comparisons even after a target is edited or archived.
        transaction.set(ref.collection('revisions').doc('$revision'), next);
      }, timeout: const Duration(seconds: 20));
      _check(scope);
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on TimeoutException {
      throw const NumericGoalException(
          'Save has not been confirmed. Retry the same form, or reload targets before editing.',
          reloadRequired: true);
    }
  }

  NumericGoalException _failure(FirebaseException error) => NumericGoalException(
      error.code == 'permission-denied'
          ? 'Target access was denied. Sign in again or contact support.'
          : 'Could not confirm the request. Check your connection and retry.',
      reloadRequired: error.code == 'deadline-exceeded');
}
