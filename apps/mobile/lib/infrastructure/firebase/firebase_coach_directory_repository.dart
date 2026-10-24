import 'firebase_booking_repository.dart';
import 'firebase_app_check_readiness.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_data/gainpath_data.dart' show InFlightRead;

class FirebaseCoachDirectoryRepository implements CoachDirectoryRepository {
  FirebaseCoachDirectoryRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFirestore? firestore,
      FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  @override
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final _pages = InFlightRead<CoachDirectoryPage<PublishedCoachProfile>>();
  final _profiles = InFlightRead<PublishedCoachProfile?>();
  void _check() {
    if (!isCurrent() || _auth.currentUser?.uid != scope.userId) {
      throw const CoachRepositoryException('permission-denied');
    }
  }

  void _id(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw const CoachRepositoryException('invalid-argument');
    }
  }

  Future<List<PublishedCoachProfile>> _ratings(
      List<PublishedCoachProfile> profiles) async {
    if (profiles.isEmpty) return profiles;
    final transport = BookingTransport(
        scope: scope,
        isCurrent: isCurrent,
        currentUid: () => _auth.currentUser?.uid);
    if (!await FirebaseAppCheckReadiness.instance
        .ensureReady(check: transport.check)) {
      throw const CoachRepositoryException('app-check-unavailable');
    }
    final result = await transport.call('getCoachRatingsCommand', {
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'coachIds': profiles.map((p) => p.id).toList()
    });
    if (result['schemaVersion'] != 1 || result['records'] is! List) {
      throw const CoachRepositoryException('invalid-response');
    }
    final records = {
      for (final r in result['records'] as List) r['coachId']: r
    };
    return profiles.map((p) {
      final r = records[p.id];
      if (r == null || r['reviewCount'] is! int) {
        throw const CoachRepositoryException('invalid-response');
      }
      return p.withRatings(
          (r['averageRating'] as num?)?.toDouble(), r['reviewCount'] as int);
    }).toList();
  }

  Query<Map<String, dynamic>> get _query => _db
      .collection('orgs/${scope.organizationId}/coaches')
      .where('status', isEqualTo: 'published')
      .orderBy(FieldPath.documentId);
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
      {String? afterId}) async {
    _check();
    if (afterId != null) _id(afterId);
    final page = await _pages.run(
        afterId == null ? 'first' : 'after:$afterId', () => _loadPage(afterId));
    _check();
    return page;
  }

  Future<CoachDirectoryPage<PublishedCoachProfile>> _loadPage(
      String? afterId) async {
    try {
      var query = _query;
      if (afterId != null) {
        _id(afterId);
        query = query.startAfter([afterId]);
      }
      final result = await query
          .limit(21)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      _check();
      final items = result.docs
          .take(20)
          .map((d) => PublishedCoachProfile.fromDocument(d.id, d.data()))
          .toList();
      return CoachDirectoryPage(await _ratings(items),
          nextCursor: result.docs.length > 20 ? items.last.id : null);
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code);
    }
  }

  @override
  Future<PublishedCoachProfile?> loadPublished(String coachId) async {
    _check();
    _id(coachId);
    final result = await _profiles.run(coachId, () => _loadPublished(coachId));
    _check();
    return result;
  }

  Future<PublishedCoachProfile?> _loadPublished(String coachId) async {
    try {
      final result = await _query
          .startAt([coachId])
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 20));
      _check();
      if (result.docs.isEmpty || result.docs.single.id != coachId) return null;
      return (await _ratings([
        PublishedCoachProfile.fromDocument(coachId, result.docs.single.data())
      ]))
          .single;
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code);
    }
  }
}
