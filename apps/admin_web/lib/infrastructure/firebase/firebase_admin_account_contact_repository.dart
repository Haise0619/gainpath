import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class FirebaseAdminAccountContactRepository
    extends AdminAccountContactRepository {
  FirebaseAdminAccountContactRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Object _lifetime = Object();
  bool _invalidated = false;
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
    return AdminAccountContact(
        displayName: (user['displayName'] as String?) ?? '',
        email: email,
        editBaseline: _Baseline(_lifetime, user, member!, email));
  }

  @override
  Future<AdminAccountContact> save(AdminAccountContact original,
      {required String displayName}) async {
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
    if (saved.displayName != displayName) {
      throw const AdminAccountContactConflict();
    }
    return saved;
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
