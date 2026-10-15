import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class FlutterFitnessProfileGateway implements FitnessProfileGateway {
  FlutterFitnessProfileGateway(
      {FirebaseFirestore? firestore, FirebaseAuth? auth, this.isSessionCurrent})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final bool Function()? isSessionCurrent;

  void _checkSession(SessionScope scope) {
    if (_auth.currentUser?.uid != scope.userId ||
        (isSessionCurrent != null && !isSessionCurrent!())) {
      throw const FitnessProfileException(
          'Your session changed. Sign in again to continue.',
          reloadRequired: true);
    }
  }

  DocumentReference<Map<String, dynamic>> _document(SessionScope scope) {
    _checkSession(scope);
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
      _checkSession(scope);
      return snapshot.data();
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on TimeoutException {
      throw const FitnessProfileException(
          'Loading took too long. Check your connection and retry.');
    }
  }

  @override
  Future<void> write(SessionScope scope, Map<String, Object?> data,
      {required Map<String, Object?>? expectedSnapshot}) async {
    try {
      final document = _document(scope);
      final original = freezeMemberDocument(expectedSnapshot);
      final patch = freezeMemberDocument(data)!;
      // The original form snapshot and intended patch never advance on retry.
      await _firestore.runTransaction<void>((transaction) async {
        _checkSession(scope);
        final current = await transaction.get(document);
        _checkSession(scope);
        if (!sameMemberDocumentValue(current.data(), original)) {
          throw const FitnessProfileException(
              'Your profile changed elsewhere. Reload before saving.',
              reloadRequired: true);
        }
        if (original == null) {
          transaction.set(
              document, {...patch, 'updatedAt': FieldValue.serverTimestamp()});
        } else if (patch.isNotEmpty) {
          transaction.update(
              document, {...patch, 'updatedAt': FieldValue.serverTimestamp()});
        }
      }, timeout: const Duration(seconds: 20));
      _checkSession(scope);
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on TimeoutException {
      throw const FitnessProfileException(
          'Save has not been confirmed. Reload before trying again; your answers are still here.',
          reloadRequired: true);
    }
  }

  FitnessProfileException _failure(FirebaseException error) {
    if (error.code == 'deadline-exceeded') {
      return const FitnessProfileException(
          'The request was not confirmed. Reload your profile before trying again.',
          reloadRequired: true);
    }
    return FitnessProfileException(error.code == 'permission-denied'
        ? 'Profile access was denied. Sign in again or contact support.'
        : 'Could not connect to your profile. Check your connection and retry.');
  }
}
