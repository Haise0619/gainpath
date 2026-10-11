import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

import '../../features/workout/data/published_routine.dart';

class FirebasePublishedRoutineRepository {
  FirebasePublishedRoutineRepository({
    required this.scope,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Routine scope requires document IDs.');
      }
    }
  }

  final SessionScope scope;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<PublishedRoutine?> load() async {
    if (_auth.currentUser?.uid != scope.userId) {
      throw StateError('Your session changed. Sign in again.');
    }
    final results = await _firestore
        .collection('orgs')
        .doc(scope.organizationId)
        .collection('content')
        .where('status', isEqualTo: 'published')
        .where('kind', isEqualTo: 'routine')
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    if (results.docs.isEmpty) return null;
    final doc = results.docs.single;
    return PublishedRoutine.fromDocument(doc.id, doc.data());
  }
}
