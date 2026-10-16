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
