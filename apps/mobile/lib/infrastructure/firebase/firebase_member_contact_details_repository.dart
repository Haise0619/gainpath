import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';

class FirebaseMemberContactDetailsRepository
    implements MemberContactDetailsRepository {
  FirebaseMemberContactDetailsRepository(
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
  String? _email;
  DocumentReference<Map<String, dynamic>> get _user =>
      _db.doc('users/${scope.userId}');
  DocumentReference<Map<String, dynamic>> get _member =>
      _db.doc('orgs/${scope.organizationId}/members/${scope.userId}');
  void _check() {
    final user = _auth.currentUser;
    if (_invalidated ||
        !isCurrent() ||
        user?.uid != scope.userId ||
        user?.emailVerified != true ||
        (_email != null && user?.email != _email)) {
      _invalidated = true;
      throw const MemberContactDetailsException(
          'Your session changed. Sign in again.',
          reloadRequired: true);
    }
    _email ??= user?.email;
  }

  void _authorize(Map<String, dynamic>? user, Map<String, dynamic>? member) {
    _check();
    if (user?['organizationId'] != scope.organizationId ||
        member?['organizationId'] != scope.organizationId ||
        member?['role'] != 'member' ||
        member?['status'] != 'active') {
      _invalidated = true;
      throw const MemberContactDetailsException(
          'Contact details access was denied. Sign in again.',
          reloadRequired: true);
    }
  }

  @override
  Future<MemberContactDetails> load() async {
    _check();
    final user = (await _user
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 20)))
        .data();
    final member = (await _member
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 20)))
        .data();
    _authorize(user, member);
    final value = user!['contactDetails'] ?? '';
    if (value is! String) {
      throw const MemberContactDetailsException(
          'Your saved contact details could not be read.');
    }
    return MemberContactDetails(
        value: value, editBaseline: _Baseline(_lifetime, user, member!));
  }

  @override
  Future<MemberContactDetails> save(
      MemberContactDetails original, String value) async {
    _check();
    // Bound this optional free-text field; it is not a phone-number-only field.
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      throw const MemberContactDetailsException(
          'Use contact details without line breaks or control characters.');
    }
    value = value.trim();
    if (value.runes.length > 200) {
      throw const MemberContactDetailsException('Use up to 200 characters.');
    }
    final baseline = original.editBaseline;
    if (baseline is! _Baseline ||
        !identical(baseline.lifetime, _lifetime) ||
        original.value != (baseline.user['contactDetails'] ?? '')) {
      throw const MemberContactDetailsException(
          'Reload contact details before saving.',
          reloadRequired: true);
    }
    Object? failure;
    try {
      await _db.runTransaction<void>((tx) async {
        if (failure != null) throw StateError('Contact save aborted.');
        try {
          _check();
          final user = (await tx.get(_user)).data();
          final member = (await tx.get(_member)).data();
          _authorize(user, member);
          if (!sameMemberDocumentValue(member, baseline.member)) {
            _invalidated = true;
            throw const MemberContactDetailsException(
                'Your account changed. Sign in again.',
                reloadRequired: true);
          }
          if (!sameMemberDocumentValue(user, baseline.user)) {
            throw const MemberContactDetailsException(
                'Your account changed elsewhere. Reload before saving.',
                reloadRequired: true);
          }
          tx.update(_user, {
            'contactDetails': value,
            'updatedAtMillis': DateTime.now().millisecondsSinceEpoch
          });
        } on MemberContactDetailsException catch (e) {
          failure = e;
          throw StateError('Contact save aborted.');
        }
      }, timeout: const Duration(seconds: 20));
      _check();
    } catch (_) {
      if (failure != null) throw failure!;
      rethrow;
    }
    final saved = await load();
    if (saved.value != value) {
      throw const MemberContactDetailsException(
          'Save was not confirmed. Reload contact details.',
          reloadRequired: true);
    }
    return saved;
  }
}

class _Baseline {
  _Baseline(
      this.lifetime, Map<String, dynamic> user, Map<String, dynamic> member)
      : user = freezeMemberDocument(user)!,
        member = freezeMemberDocument(member)!;
  final Object lifetime;
  final Map<String, Object?> user, member;
}
