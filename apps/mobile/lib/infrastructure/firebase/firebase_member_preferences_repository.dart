import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class FirebaseMemberPreferencesRepository
    implements MemberPreferencesRepository {
  FirebaseMemberPreferencesRepository({
    required this.scope,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.isSessionCurrent,
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
  final bool Function()? isSessionCurrent;
  final Object _lifetime = Object();

  void _checkSession() {
    if (_auth.currentUser?.uid != scope.userId ||
        (isSessionCurrent != null && !isSessionCurrent!())) {
      throw const MemberPreferencesException(
          'Your session changed. Sign in again to continue.',
          reloadRequired: true);
    }
  }

  DocumentReference<Map<String, dynamic>> _document() {
    _checkSession();
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
      _checkSession();
      if (data == null) {
        return MemberPreferences(
            editBaseline: _PreferencesBaseline(_lifetime, null));
      }
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
        editBaseline:
            _PreferencesBaseline(_lifetime, freezeMemberDocument(data)),
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
      final document = _document();
      final baseline = preferences.editBaseline;
      if (baseline is! _PreferencesBaseline ||
          !identical(baseline.lifetime, _lifetime)) {
        throw const MemberPreferencesException(
            'Reload settings before saving this choice.',
            reloadRequired: true);
      }
      final original = baseline.snapshot;
      final fields = <String, Object?>{
        'schemaVersion': 1,
        'pushNotifications': preferences.pushNotifications,
        'emailUpdates': preferences.emailUpdates,
        'voiceCoaching': preferences.voiceCoaching,
      };
      final patch = freezeMemberDocument({
        for (final field in fields.entries)
          if (original == null ||
              (field.key != 'schemaVersion' &&
                  !sameMemberDocumentValue(field.value, original[field.key])))
            field.key: field.value,
      })!;
      await _firestore.runTransaction<void>((transaction) async {
        _checkSession();
        final current = await transaction.get(document);
        _checkSession();
        if (!sameMemberDocumentValue(current.data(), original)) {
          throw const MemberPreferencesException(
              'Your settings changed elsewhere. Reload before saving.',
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
      _checkSession();
    } on FirebaseException catch (error) {
      throw _failure(error);
    } on TimeoutException {
      throw const MemberPreferencesException(
          'Save has not been confirmed. Reload settings before trying again.',
          reloadRequired: true);
    }
  }

  MemberPreferencesException _failure(FirebaseException error) {
    if (error.code == 'deadline-exceeded') {
      return const MemberPreferencesException(
          'The request was not confirmed. Reload settings before trying again.',
          reloadRequired: true);
    }
    return MemberPreferencesException(error.code == 'permission-denied'
        ? 'Settings access was denied. Sign in again or contact support.'
        : 'Could not connect to settings. Check your connection and retry.');
  }
}

class _PreferencesBaseline {
  const _PreferencesBaseline(this.lifetime, this.snapshot);
  final Object lifetime;
  final Map<String, Object?>? snapshot;
}
