import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class FirebaseExerciseCatalogRepository implements TutorialRepository {
  FirebaseExerciseCatalogRepository({
    required this.scope,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance {
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Exercise catalog scope requires document IDs.');
      }
    }
  }

  final SessionScope scope;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _collection() {
    _requireCurrentUser();
    return _firestore
        .collection('orgs')
        .doc(scope.organizationId)
        .collection('exerciseVideos');
  }

  void _requireCurrentUser() {
    if (_auth.currentUser?.uid != scope.userId) {
      throw StateError('Your session changed. Sign in again.');
    }
  }

  @override
  bool get requiresCatalogSelection => true;

  @override
  List<TutorialVideo> get tutorials => const [];

  @override
  Future<List<TutorialVideo>> load() async {
    final snapshot =
        await _collection().get(const GetOptions(source: Source.server));
    final entries =
        snapshot.docs.map((doc) => _fromDocument(doc.id, doc.data())).toList();
    entries
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return List.unmodifiable(entries);
  }

  @override
  Future<TutorialVideo> save(TutorialVideo tutorial) async {
    final collection = _collection();
    final data = {
      ...encodeCatalogFields(tutorial),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (tutorial.id.isEmpty) {
      final reference = collection.doc();
      await reference.set({...data, 'createdAt': FieldValue.serverTimestamp()});
      return _fromDocument(reference.id,
          {...data, 'isActive': tutorial.status == TutorialStatus.active});
    }
    await collection.doc(tutorial.id).update(data);
    return _fromDocument(tutorial.id,
        {...data, 'isActive': tutorial.status == TutorialStatus.active});
  }

  /// The only client-authored fields in an exercise catalog record.
  static Map<String, Object?> encodeCatalogFields(TutorialVideo tutorial) => {
        'schemaVersion': 1,
        'exerciseName': tutorial.title.trim(),
        'muscleCategory': tutorial.category.trim(),
        'videoUrl': tutorial.videoUrl.trim(),
        'isActive': tutorial.status == TutorialStatus.active,
      };

  TutorialVideo _fromDocument(String id, Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        data['exerciseName'] is! String ||
        (data['exerciseName'] as String).trim().isEmpty ||
        data['muscleCategory'] is! String ||
        (data['muscleCategory'] as String).trim().isEmpty ||
        data['videoUrl'] is! String ||
        data['isActive'] is! bool) {
      throw const FormatException('Exercise catalog record is invalid.');
    }
    return TutorialVideo(
      id: id,
      title: (data['exerciseName'] as String).trim(),
      category: (data['muscleCategory'] as String).trim(),
      status: data['isActive'] == true
          ? TutorialStatus.active
          : TutorialStatus.draft,
      videoUrl: data['videoUrl'] as String,
    );
  }
}
