import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

import '../../features/workout/data/published_routine.dart';
import '../../features/workout/domain/published_routine_catalog_repository.dart';

class FirebasePublishedRoutineRepository
    implements PublishedRoutineCatalogRepository {
  FirebasePublishedRoutineRepository({
    required this.scope,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.activeScope,
    this.pageSize = 20,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Routine scope requires document IDs.');
      }
    }
    if (pageSize < 1 || pageSize > 50) {
      throw ArgumentError('Routine pages must contain 1–50 items.');
    }
  }

  @override
  final SessionScope scope;
  final SessionScope? Function()? activeScope;
  final int pageSize;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  void _checkSession() {
    if (_auth.currentUser?.uid != scope.userId ||
        (activeScope != null && activeScope!() != scope)) {
      throw StateError('Your session changed. Sign in again.');
    }
  }

  Query<Map<String, dynamic>> _published() => _firestore
      .collection('orgs')
      .doc(scope.organizationId)
      .collection('content')
      .where('status', isEqualTo: 'published')
      .where('kind', isEqualTo: 'routine');

  @override
  Future<PublishedRoutinePage> loadPage({String? afterId}) async {
    _checkSession();
    Query<Map<String, dynamic>> query =
        _published().orderBy(FieldPath.documentId);
    if (afterId != null) {
      _checkId(afterId);
      query = query.startAfter([afterId]);
    }
    final results = await query
        .limit(pageSize + 1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    _checkSession();
    final items = results.docs
        .take(pageSize)
        .map((doc) => PublishedRoutine.fromDocument(doc.id, doc.data()))
        .toList();
    return PublishedRoutinePage(items,
        nextCursor: results.docs.length > pageSize ? items.last.id : null);
  }

  @override
  Future<PublishedRoutine?> loadById(String id) async {
    _checkSession();
    _checkId(id);
    // Equality on document ID can cause Rules to evaluate the actual draft
    // resource and deny the query. A bounded published range preserves the
    // normal list authorization and reads at most one authorized document.
    final result = await _published()
        .orderBy(FieldPath.documentId)
        .startAt([id])
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    _checkSession();
    if (result.docs.isEmpty || result.docs.single.id != id) return null;
    return PublishedRoutine.fromDocument(
        result.docs.single.id, result.docs.single.data());
  }

  void _checkId(String id) {
    if (id.trim().isEmpty || id.contains('/') || id == '.' || id == '..') {
      throw ArgumentError('A published content document ID is required.');
    }
  }

  /// Compatibility for consumers that still request one deterministic record.
  Future<PublishedRoutine?> load() async {
    final page = await loadPage();
    return page.items.isEmpty ? null : page.items.first;
  }
}
