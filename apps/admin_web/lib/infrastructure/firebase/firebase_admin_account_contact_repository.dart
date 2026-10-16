import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'firebase_account_photo_store.dart';

class FirebaseAdminAccountContactRepository
    extends AdminAccountContactRepository {
  FirebaseAdminAccountContactRepository(
      {required this.scope,
      required this.isCurrent,
      AccountPhotoStore? photoStore,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _photos = photoStore,
        _auth = auth ?? FirebaseAuth.instance;
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Object _lifetime = Object();
  bool _invalidated = false;
  AccountPhotoStore? _photos;
  Future<Uint8List?>? _preview;
  AccountPhotoStore get _photoStore =>
      _photos ??= FirebaseAccountPhotoStore(scope: scope, isCurrent: isCurrent);
  bool _ownedPhoto(String path) => RegExp(
          '^orgs/${RegExp.escape(scope.organizationId)}/profilePhotos/${RegExp.escape(scope.userId)}/[a-f0-9]{32}\$')
      .hasMatch(path);
  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(scope.userId);
  DocumentReference<Map<String, dynamic>> get _member => _db
      .collection('orgs')
      .doc(scope.organizationId)
      .collection('members')
      .doc(scope.userId);

  void _check() {
    if (_invalidated ||
        !isCurrent() ||
        _auth.currentUser?.uid != scope.userId ||
        _auth.currentUser?.emailVerified != true) {
      _invalidated = true;
      throw const AdminAccountContactSessionChanged();
    }
  }

  void _author(Map<String, dynamic>? user, Map<String, dynamic>? member) {
    _check();
    if (user?['organizationId'] != scope.organizationId ||
        member?['organizationId'] != scope.organizationId ||
        member?['role'] != 'admin' ||
        member?['status'] != 'active') {
      _invalidated = true;
      throw const AdminAccountContactSessionChanged();
    }
  }

  @override
  Future<AdminAccountContact> load() async {
    _check();
    final user =
        (await _user.get(const GetOptions(source: Source.server))).data();
    final member =
        (await _member.get(const GetOptions(source: Source.server))).data();
    _author(user, member);
    final email = _auth.currentUser?.email;
    if (email == null ||
        email.isEmpty ||
        (user!['displayName'] != null && user['displayName'] is! String)) {
      throw const FormatException('Account contact details are unavailable.');
    }
    final preferences = user['notificationPreferences'];
    if (preferences != null &&
        (preferences is! Map ||
            preferences.length != 3 ||
            !['pushAlerts', 'emailAlerts', 'weeklyDigest']
                .every((key) => preferences[key] is bool))) {
      throw const FormatException('Notification preferences are unavailable.');
    }
    return AdminAccountContact(
        notificationPreferences: preferences == null
            ? null
            : Map<String, bool>.unmodifiable(
                Map<String, bool>.from(preferences as Map)),
        displayName: (user['displayName'] as String?) ?? '',
        avatarPath:
            user['avatarPath'] is String ? user['avatarPath'] as String : '',
        email: email,
        editBaseline: _Baseline(_lifetime, user, member!, email));
  }

  @override
  Future<AdminAccountContact> save(AdminAccountContact original,
      {required String displayName,
      AccountPhoto? photo,
      bool removePhoto = false}) async {
    if (photo != null && removePhoto) {
      throw const FormatException('Choose a photo or remove it, not both.');
    }
    displayName = displayName.trim();
    if (displayName.runes.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(displayName)) {
      throw const FormatException(
          'Use up to 80 characters without line breaks or control characters.');
    }
    _check();
    final baseline = original.editBaseline;
    if (baseline is! _Baseline || !identical(baseline.lifetime, _lifetime)) {
      throw const AdminAccountContactConflict();
    }
    String? avatarPath;
    if (photo != null) {
      // Upload once, outside retryable transactions, after checking the original edit.
      final user =
          (await _user.get(const GetOptions(source: Source.server))).data();
      final member =
          (await _member.get(const GetOptions(source: Source.server))).data();
      _author(user, member);
      if (_auth.currentUser?.email != baseline.email ||
          !_same(member, baseline.member)) {
        _invalidated = true;
        throw const AdminAccountContactSessionChanged();
      }
      if (!_same(user, baseline.user)) {
        throw const AdminAccountContactConflict();
      }
      avatarPath = await _photoStore.upload(photo);
      _check();
      if (!_ownedPhoto(avatarPath)) throw const AccountPhotoUnavailable();
    } else if (removePhoto) {
      avatarPath = '';
    }
    Object? failure;
    try {
      await _db.runTransaction<void>((tx) async {
        if (failure != null) throw StateError('Account save aborted.');
        try {
          _check();
          final user = (await tx.get(_user)).data();
          final member = (await tx.get(_member)).data();
          _author(user, member);
          if (_auth.currentUser?.email != baseline.email ||
              !_same(member, baseline.member)) {
            throw const AdminAccountContactSessionChanged();
          }
          if (!_same(user, baseline.user)) {
            throw const AdminAccountContactConflict();
          }
          _check();
          tx.update(_user, {
            'displayName': displayName,
            if (avatarPath != null) 'avatarPath': avatarPath,
            'updatedAtMillis': DateTime.now().millisecondsSinceEpoch
          });
        } on AdminAccountContactConflict catch (e) {
          failure = e;
          throw StateError('Account save aborted.');
        } on AdminAccountContactSessionChanged catch (e) {
          _invalidated = true;
          failure = e;
          throw StateError('Account save aborted.');
        }
      });
    } catch (_) {
      if (failure != null) throw failure!;
      rethrow;
    }
    final saved = await load();
    if (saved.displayName != displayName ||
        (avatarPath != null && saved.avatarPath != avatarPath)) {
      throw const AdminAccountContactConflict();
    }
    return saved;
  }

  @override
  Future<AdminAccountContact> saveNotificationPreferences(
      AdminAccountContact original,
      {required bool pushAlerts,
      required bool emailAlerts,
      required bool weeklyDigest}) async {
    _check();
    final baseline = original.editBaseline;
    if (baseline is! _Baseline || !identical(baseline.lifetime, _lifetime)) {
      throw const AdminAccountContactConflict();
    }
    final preferences = {
      'pushAlerts': pushAlerts,
      'emailAlerts': emailAlerts,
      'weeklyDigest': weeklyDigest
    };
    Object? failure;
    try {
      await _db.runTransaction<void>((tx) async {
        if (failure != null) throw StateError('Preference save aborted.');
        try {
          _check();
          final user = (await tx.get(_user)).data();
          final member = (await tx.get(_member)).data();
          _author(user, member);
          if (_auth.currentUser?.email != baseline.email ||
              !_same(member, baseline.member)) {
            throw const AdminAccountContactSessionChanged();
          }
          if (!_same(user, baseline.user)) {
            throw const AdminAccountContactConflict();
          }
          _check();
          tx.update(_user, {
            'notificationPreferences': preferences,
            'updatedAtMillis': DateTime.now().millisecondsSinceEpoch
          });
        } on AdminAccountContactConflict catch (e) {
          failure = e;
          throw StateError('Preference save aborted.');
        } on AdminAccountContactSessionChanged catch (e) {
          _invalidated = true;
          failure = e;
          throw StateError('Preference save aborted.');
        }
      });
    } catch (_) {
      if (failure != null) throw failure!;
      rethrow;
    }
    final saved = await load();
    if (!_same(saved.notificationPreferences, preferences)) {
      throw const AdminAccountContactConflict();
    }
    return saved;
  }

  @override
  Future<Uint8List?> loadCurrentPhoto() {
    _check();
    return _preview ??= load().then(readPhoto);
  }

  @override
  Future<Uint8List?> readPhoto(AdminAccountContact account) async {
    _check();
    final baseline = account.editBaseline;
    if (baseline is! _Baseline ||
        !identical(baseline.lifetime, _lifetime) ||
        account.avatarPath !=
            (baseline.user['avatarPath'] is String
                ? baseline.user['avatarPath']
                : '')) {
      throw const AdminAccountContactConflict();
    }
    if (account.avatarPath.isEmpty) return null;
    if (!_ownedPhoto(account.avatarPath)) throw const AccountPhotoUnavailable();
    final bytes = await _photoStore.read(account.avatarPath);
    _check();
    return bytes;
  }
}

Object? _freeze(Object? value) => value is Map
    ? Map.unmodifiable(value.map((key, item) => MapEntry(key, _freeze(item))))
    : value is List
        ? List.unmodifiable(value.map(_freeze))
        : value;
bool _same(Object? a, Object? b) => a is Map && b is Map
    ? a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]))
    : a is List && b is List
        ? a.length == b.length &&
            List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]))
        : a == b;

class _Baseline extends AdminAccountContactBaseline {
  _Baseline(this.lifetime, Map<String, dynamic> user,
      Map<String, dynamic> member, this.email)
      : user = _freeze(user) as Map,
        member = _freeze(member) as Map;
  final Object lifetime;
  final Map user, member;
  final String email;
}
