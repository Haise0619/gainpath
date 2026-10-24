import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_function_transport.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gamification.dart';
import '../../features/gamification/reward_fulfilment_repository.dart';

class FirebaseAdminMemberDirectoryRepository
    implements
        AdminMemberDirectoryRepository,
        MembershipVerificationRepository,
        RewardFulfilmentRepository {
  FirebaseAdminMemberDirectoryRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth,
      Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)?
          membershipCall})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _membershipCall = membershipCall ??
            ((name, input) async =>
                (await firebaseCallable(name).call<Map<String, dynamic>>(input))
                    .data);
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)
      _membershipCall;
  @override
  bool get current {
    try {
      _check();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AdminRewardVoucher> inspect(String redemptionId) =>
      _rewardVoucher('inspect', redemptionId);
  @override
  Future<AdminRewardVoucher> fulfil(String redemptionId) =>
      _rewardVoucher('fulfil', redemptionId);
  Future<AdminRewardVoucher> _rewardVoucher(
      String action, String redemptionId) async {
    _check();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(redemptionId)) {
      throw const FormatException('Invalid reward reference.');
    }
    final response = await _membershipCall('verifiedRewardsCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'action': action,
      'redemptionId': redemptionId
    }).timeout(const Duration(seconds: 20));
    _check();
    final data = Map<String, dynamic>.from(response['redemption'] as Map);
    if (response['schemaVersion'] != 1 ||
        data['redemptionId'] != redemptionId ||
        data['memberId'] is! String ||
        (data['memberId'] as String).isEmpty) {
      throw const FormatException('Invalid reward record.');
    }
    final value = VerifiedRewardRedemption.fromJson(data,
        organizationId: scope.organizationId,
        memberId: data['memberId'] as String);
    if (action == 'fulfil' && value.status != 'fulfilled') {
      throw const FormatException('Fulfilment unconfirmed.');
    }
    return AdminRewardVoucher(
        memberId: data['memberId'] as String, redemption: value);
  }

  @override
  Future<MemberMembershipVerification> verifyMembership(String memberId) async {
    _check();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(memberId)) {
      throw const FormatException('Invalid member identifier.');
    }
    final response = await _membershipCall('verifyMemberMembershipCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'memberId': memberId
    }).timeout(const Duration(seconds: 20));
    _check();
    return MemberMembershipVerification.fromJson(response,
        organizationId: scope.organizationId, memberId: memberId);
  }

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
