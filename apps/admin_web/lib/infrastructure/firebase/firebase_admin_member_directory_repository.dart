import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';

class FirebaseAdminMemberDirectoryRepository
    implements AdminMemberDirectoryRepository {
  FirebaseAdminMemberDirectoryRepository(
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
  bool _invalidated = false;
  @override
  Future<AdminMemberDetails> loadDetails(String memberId) async {
    _check();
    if (memberId.isEmpty || memberId.length > 128 || memberId.contains('/')) {
      throw const FormatException('Invalid member identifier.');
    }
    await _admin().timeout(const Duration(seconds: 20));
    final snapshot = await _db
        .doc('orgs/${scope.organizationId}/members/$memberId')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    await _admin().timeout(const Duration(seconds: 20));
    final data = snapshot.exists ? snapshot.data() : null;
    if (data == null ||
        data['organizationId'] != scope.organizationId ||
        data['role'] != 'member') {
      throw StateError('Member record is unavailable.');
    }
    final status = data['status'];
    final branches = data['branchIds'];
    if (status is! String ||
        status.isEmpty ||
        status.length > 40 ||
        (branches != null &&
            (branches is! List ||
                branches.any((e) => e is! String || e.isEmpty)))) {
      throw StateError('Member record is invalid.');
    }
    int? millis(String field) {
      final value = data[field];
      if (value == null) return null;
      if (value is! int || value < 0 || value > 8640000000000000) {
        throw StateError('Member date is invalid.');
      }
      return value;
    }

    final name = data['displayName'] is String
        ? (data['displayName'] as String).trim()
        : '';
    final email =
        data['email'] is String ? (data['email'] as String).trim() : '';
    _check();
    return AdminMemberDetails(
        member: AdminMemberRecord(
            id: memberId,
            name: name.isEmpty ? (email.isEmpty ? memberId : email) : name,
            email: email,
            status: status),
        organizationId: scope.organizationId,
        branchIds: branches == null ? [] : List<String>.from(branches as List),
        createdAtMillis: millis('createdAtMillis'),
        updatedAtMillis: millis('updatedAtMillis'));
  }

  void _check() {
    if (_invalidated ||
        !isCurrent() ||
        _auth.currentUser?.uid != scope.userId ||
        _auth.currentUser?.emailVerified != true) {
      _invalidated = true;
      throw StateError('Directory session is no longer authorized.');
    }
  }

  Future<void> _admin() async {
    _check();
    const server = GetOptions(source: Source.server);
    final user = (await _db.doc('users/${scope.userId}').get(server)).data();
    final member = (await _db
            .doc('orgs/${scope.organizationId}/members/${scope.userId}')
            .get(server))
        .data();
    _check();
    if (user?['organizationId'] != scope.organizationId ||
        member?['organizationId'] != scope.organizationId ||
        member?['role'] != 'admin' ||
        member?['status'] != 'active') {
      _invalidated = true;
      throw StateError('Directory session is no longer authorized.');
    }
  }

  @override
  Future<AdminMemberPage> loadPage(
      {String query = '', String status = 'All', String? afterId}) async {
    _check();
    if (query.length > 120 ||
        !['All', 'Active', 'Suspended'].contains(status) ||
        (afterId != null &&
            (afterId.isEmpty ||
                afterId.length > 128 ||
                afterId.contains('/')))) {
      throw const FormatException('Invalid directory search.');
    }
    // Recheck the canonical assignment before AND after each bounded server read.
    await _admin().timeout(const Duration(seconds: 20));
    Query<Map<String, dynamic>> source = _db
        .collection('orgs/${scope.organizationId}/members')
        .where('role', isEqualTo: 'member')
        .orderBy(FieldPath.documentId);
    if (afterId != null) source = source.startAfter([afterId]);
    final page = await source
        .limit(101)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    await _admin().timeout(const Duration(seconds: 20));
    final needle = query.trim().toLowerCase(), items = <AdminMemberRecord>[];
    var scanned = 0;
    String? cursor;
    for (final doc in page.docs.take(100)) {
      scanned++;
      cursor = doc.id;
      final data = doc.data();
      if (data['organizationId'] != scope.organizationId ||
          data['role'] != 'member') {
        throw StateError(
            'Directory record has an invalid organization assignment.');
      }
      final name = data['displayName'] is String
          ? (data['displayName'] as String).trim()
          : '';
      final email =
          data['email'] is String ? (data['email'] as String).trim() : '';
      final rawStatus = data['status'];
      if (rawStatus is! String || rawStatus.isEmpty || rawStatus.length > 40) {
        throw StateError('Directory record has an invalid account status.');
      }
      if ((status == 'All' || rawStatus == status.toLowerCase()) &&
          (needle.isEmpty ||
              name.toLowerCase().contains(needle) ||
              email.toLowerCase().contains(needle))) {
        items.add(AdminMemberRecord(
            id: doc.id,
            name: name.isEmpty ? (email.isEmpty ? doc.id : email) : name,
            email: email,
            status: rawStatus));
        if (items.length == 24) break;
      }
    }
    _check();
    return AdminMemberPage(items,
        nextCursor: page.docs.length > scanned ? cursor : null);
  }
}
