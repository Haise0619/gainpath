import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class FlutterFitnessProfileGateway implements FitnessProfileGateway {
  FlutterFitnessProfileGateway(
      {FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _document(SessionScope scope) {
    if (_auth.currentUser?.uid != scope.userId) {
      throw const FitnessProfileException(
          'Your session changed. Sign in again to continue.');
    }
    return _firestore
        .collection('orgs')
        .doc(scope.organizationId)
        .collection('profiles')
        .doc(scope.userId);
  }

  @override
  Future<Map<String, Object?>?> read(SessionScope scope) async {
    try {
      // An offline cache miss must never be interpreted as a new member.
      final snapshot = await _document(scope)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      return snapshot.data();
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on TimeoutException {
      throw const FitnessProfileException(
          'Loading took too long. Check your connection and retry.');
    }
  }

  @override
  Future<void> write(SessionScope scope, Map<String, Object?> data) async {
    try {
      // The future completes only when the backend acknowledges the write.
      await _document(scope)
          .set({...data, 'updatedAt': FieldValue.serverTimestamp()}).timeout(
              const Duration(seconds: 20));
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on TimeoutException {
      // Firestore may still have a queued write; do not falsely claim failure
      // or completion. Retrying the same full profile is idempotent.
      throw const FitnessProfileException(
          'Save has not been confirmed yet. Reconnect and retry; your answers are still here.');
    }
  }

  FitnessProfileException _failure(FirebaseException error) =>
      FitnessProfileException(error.code == 'permission-denied'
          ? 'Profile access was denied. Sign in again or contact support.'
          : 'Could not connect to your profile. Check your connection and retry.');
}
