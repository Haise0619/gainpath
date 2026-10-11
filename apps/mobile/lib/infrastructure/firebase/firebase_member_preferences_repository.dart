import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class FirebaseMemberPreferencesRepository
    implements MemberPreferencesRepository {
  FirebaseMemberPreferencesRepository({
    required this.scope,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Settings ownership requires document IDs.');
      }
    }
  }

  @override
  final SessionScope scope;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _document() {
    if (_auth.currentUser?.uid != scope.userId) {
      throw const MemberPreferencesException(
          'Your session changed. Sign in again to continue.');
    }
    return _firestore
        .collection('orgs')
        .doc(scope.organizationId)
        .collection('preferences')
        .doc(scope.userId);
  }

  @override
  Future<MemberPreferences> load() async {
    try {
      final snapshot = await _document()
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      final data = snapshot.data();
      if (data == null) return const MemberPreferences();
      if (data['schemaVersion'] != 1 ||
          data['pushNotifications'] is! bool ||
          data['emailUpdates'] is! bool ||
          data['voiceCoaching'] is! bool) {
        throw const MemberPreferencesException(
            'Your saved settings could not be read. Contact support.');
      }
      return MemberPreferences(
        pushNotifications: data['pushNotifications'] as bool,
        emailUpdates: data['emailUpdates'] as bool,
        voiceCoaching: data['voiceCoaching'] as bool,
      );
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on TimeoutException {
      throw const MemberPreferencesException(
          'Loading settings took too long. Check your connection and retry.');
    }
  }

  @override
  Future<void> save(MemberPreferences preferences) async {
    try {
      await _document().set({
        'schemaVersion': 1,
        'pushNotifications': preferences.pushNotifications,
        'emailUpdates': preferences.emailUpdates,
        'voiceCoaching': preferences.voiceCoaching,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 20));
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on TimeoutException {
      throw const MemberPreferencesException(
          'Save has not been confirmed. Reopen settings to check the saved choice.');
    }
  }

  MemberPreferencesException _failure(FirebaseException error) =>
      MemberPreferencesException(error.code == 'permission-denied'
          ? 'Settings access was denied. Sign in again or contact support.'
          : 'Could not connect to settings. Check your connection and retry.');
}
