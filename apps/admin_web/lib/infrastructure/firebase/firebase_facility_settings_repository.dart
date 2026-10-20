import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class FirebaseFacilitySettingsRepository implements FacilitySettingsRepository {
  FirebaseFacilitySettingsRepository(
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
  DocumentReference<Map<String, dynamic>> get _organization =>
      _db.collection('orgs').doc(scope.organizationId);
  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(scope.userId);
  DocumentReference<Map<String, dynamic>> get _member =>
      _organization.collection('members').doc(scope.userId);
  void _check() {
    if (_invalidated ||
        !isCurrent() ||
        _auth.currentUser?.uid != scope.userId ||
        _auth.currentUser?.emailVerified != true) {
      _invalidated = true;
      throw const FacilitySettingsSessionChanged();
    }
  }

  void _author(Map<String, dynamic>? user, Map<String, dynamic>? member) {
    _check();
    if (user?['organizationId'] != scope.organizationId ||
        member?['organizationId'] != scope.organizationId ||
        member?['role'] != 'admin' ||
        member?['status'] != 'active') {
      _invalidated = true;
      throw const FacilitySettingsSessionChanged();
    }
  }

  Future<(Map<String, dynamic>, Map<String, dynamic>)> _readAuthor() async {
    _check();
    final user =
        (await _user.get(const GetOptions(source: Source.server))).data();
    final member =
        (await _member.get(const GetOptions(source: Source.server))).data();
    _author(user, member);
    return (user!, member!);
  }

  @override
  Future<FacilityNameSnapshot> load() async {
    final author = await _readAuthor();
    final data =
        (await _organization.get(const GetOptions(source: Source.server)))
            .data();
    final after = await _readAuthor();
    if (!_same(author.$1, after.$1) || !_same(author.$2, after.$2)) {
      _invalidated = true;
      throw const FacilitySettingsSessionChanged();
    }
    if (data == null ||
        data['organizationId'] != scope.organizationId ||
        data['status'] != 'active' ||
        data['displayName'] is! String ||
        data['updatedAtMillis'] is! int) {
      throw const FormatException('Facility settings are unavailable.');
    }
    return FacilityNameSnapshot(
        organizationId: scope.organizationId,
        displayName: data['displayName'],
        editBaseline: _Baseline(_lifetime, data, author.$1, author.$2));
  }

  @override
  Future<FacilityNameSnapshot> save(FacilityNameSnapshot original,
      {required String displayName}) async {
    displayName = displayName.trim();
    if (displayName.isEmpty ||
        displayName.length > 120 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(displayName)) {
      throw const FormatException(
          'Enter a facility name of 1–120 characters without line breaks or control characters.');
    }
    _check();
    final baseline = original.editBaseline;
    if (baseline is! _Baseline ||
        !identical(baseline.lifetime, _lifetime) ||
        original.organizationId != scope.organizationId) {
      throw const FacilitySettingsConflict();
    }
    Object? failure;
    try {
      await _db.runTransaction<void>((tx) async {
        if (failure != null) throw StateError('Facility name save aborted.');
        try {
          _check();
          final user = (await tx.get(_user)).data(),
              member = (await tx.get(_member)).data();
          _author(user, member);
          if (!_same(user, baseline.user) || !_same(member, baseline.member)) {
            _invalidated = true;
            throw const FacilitySettingsSessionChanged();
          }
          final current = (await tx.get(_organization)).data();
          if (!_same(current, baseline.organization)) {
            throw const FacilitySettingsConflict();
          }
          _check();
          tx.update(_organization, {
            'displayName': displayName,
            'updatedAtMillis': DateTime.now().millisecondsSinceEpoch
          });
        } on FacilitySettingsConflict catch (e) {
          failure = e;
          throw StateError('Facility name save aborted.');
        } on FacilitySettingsSessionChanged catch (e) {
          failure = e;
          throw StateError('Facility name save aborted.');
        }
      });
    } catch (_) {
      if (failure != null) throw failure!;
      rethrow;
    }
    final saved = await load();
    if (saved.displayName != displayName) {
      throw const FacilitySettingsConflict();
    }
    return saved;
  }
}

Object? _freeze(Object? value) => value is Map
    ? Map.unmodifiable(value.map((k, v) => MapEntry(k, _freeze(v))))
    : value is List
        ? List.unmodifiable(value.map(_freeze))
        : value;
bool _same(Object? a, Object? b) => a is Map && b is Map
    ? a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]))
    : a is List && b is List
        ? a.length == b.length &&
            List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]))
        : a == b;

class _Baseline {
  _Baseline(this.lifetime, Map<String, dynamic> organization,
      Map<String, dynamic> user, Map<String, dynamic> member)
      : organization = _freeze(organization) as Map,
        user = _freeze(user) as Map,
        member = _freeze(member) as Map;
  final Object lifetime;
  final Map organization, user, member;
}
