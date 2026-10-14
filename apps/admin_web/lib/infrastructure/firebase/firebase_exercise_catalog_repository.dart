import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'exercise_catalog_store.dart';

class FirebaseExerciseCatalogRepository implements TutorialRepository {
  FirebaseExerciseCatalogRepository({
    required this.scope,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ExerciseCatalogStore? store,
    bool Function()? isSessionCurrent,
  })  : _firestore = firestore,
        _auth = auth,
        _injectedStore = store,
        _sessionGuard = isSessionCurrent {
    if (store != null && isSessionCurrent == null) {
      throw ArgumentError(
          'An injected catalog transport requires a session guard.');
    }
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Exercise catalog scope requires document IDs.');
      }
    }
  }

  final SessionScope scope;
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final ExerciseCatalogStore? _injectedStore;
  final bool Function()? _sessionGuard;
  final Object _lifetime = Object();
  bool _invalidated = false;
  late final ExerciseCatalogStore _store = _injectedStore ??
      FirestoreExerciseCatalogStore(
          _firestore ?? FirebaseFirestore.instance, scope);

  void _requireCurrentUser() {
    if (_invalidated ||
        (_sessionGuard != null && !_sessionGuard()) ||
        (_injectedStore == null &&
            (_auth ?? FirebaseAuth.instance).currentUser?.uid !=
                scope.userId)) {
      _invalidated = true;
      throw const TutorialEditAuthorizationChanged();
    }
  }

  @override
  bool get requiresCatalogSelection => true;

  @override
  List<TutorialVideo> get tutorials => const [];

  @override
  Future<List<TutorialVideo>> load() async {
    try {
      return await _load();
    } on TutorialEditAuthorizationChanged {
      _invalidated = true;
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        _invalidated = true;
        throw const TutorialEditAuthorizationChanged();
      }
      throw const FormatException('Could not load the exercise catalog.');
    } catch (_) {
      throw const FormatException('Could not load the exercise catalog.');
    }
  }

  Future<List<TutorialVideo>> _load() async {
    _requireCurrentUser();
    final assignment = await _store.readAssignment();
    _requireAssignment(assignment);
    final membership = await _store.readMembership();
    _requireAuthor(membership);
    final snapshot = await _store.load();
    _requireCurrentUser();
    final entries = snapshot.entries
        .map((document) => _fromDocument(document.key, document.value,
            baseline: _CatalogBaseline(_lifetime, document.key, document.value,
                membership!, assignment!)))
        .toList();
    entries
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return List.unmodifiable(entries);
  }

  @override
  Future<TutorialVideo> save(TutorialVideo tutorial) async {
    try {
      return await _save(tutorial);
    } on TutorialEditConflict {
      rethrow;
    } on TutorialEditAuthorizationChanged {
      _invalidated = true;
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        _invalidated = true;
        throw const TutorialEditAuthorizationChanged();
      }
      throw const TutorialCatalogSaveFailed();
    } catch (_) {
      throw const TutorialCatalogSaveFailed();
    }
  }

  Future<TutorialVideo> _save(TutorialVideo tutorial) async {
    _requireCurrentUser();
    final data = encodeCatalogFields(tutorial);
    if (tutorial.id.isEmpty) {
      _requireAssignment(await _store.readAssignment());
      final membership = await _store.readMembership();
      _requireAuthor(membership);
      _requireCurrentUser();
      final id = await _store.create(data);
      _requireCurrentUser();
      return _fromDocument(id, data);
    }
    final baseline = tutorial.editBaseline;
    if (baseline is! _CatalogBaseline ||
        !identical(baseline.lifetime, _lifetime) ||
        baseline.id != tutorial.id) {
      throw const TutorialEditConflict();
    }
    final patch = Map<String, Object?>.unmodifiable({
      for (final field in data.entries)
        if (field.key != 'schemaVersion' &&
            field.value != baseline.editable[field.key])
          field.key: field.value,
    });
    // Baseline and patch are captured OUTSIDE the retryable callback.
    await _store.transaction((transaction) async {
      _requireCurrentUser();
      final assignment = await transaction.readAssignment();
      _requireAssignment(assignment);
      if (!_same(assignment, baseline.assignment)) {
        throw const TutorialEditAuthorizationChanged();
      }
      final membership = await transaction.readMembership();
      _requireAuthor(membership);
      if (!_same(membership, baseline.membership)) {
        throw const TutorialEditAuthorizationChanged();
      }
      final current = await transaction.readExercise(tutorial.id);
      _requireCurrentUser();
      if (!_same(current, baseline.document)) {
        throw const TutorialEditConflict();
      }
      if (patch.isNotEmpty) transaction.update(tutorial.id, patch);
    });
    _requireCurrentUser();
    // Successful form closes. Another edit must explicitly reload a baseline.
    return _fromDocument(tutorial.id, {...baseline.document, ...patch});
  }

  void _requireAuthor(Map<String, dynamic>? membership) {
    if (membership == null ||
        membership['organizationId'] != scope.organizationId ||
        membership['status'] != 'active' ||
        !const ['admin', 'staff'].contains(membership['role'])) {
      _invalidated = true;
      throw const TutorialEditAuthorizationChanged();
    }
  }

  void _requireAssignment(Map<String, dynamic>? assignment) {
    if (assignment == null ||
        assignment['organizationId'] != scope.organizationId) {
      _invalidated = true;
      throw const TutorialEditAuthorizationChanged();
    }
  }

  /// The only client-authored fields in an exercise catalog record.
  static Map<String, Object?> encodeCatalogFields(TutorialVideo tutorial) => {
        'schemaVersion': 1,
        'exerciseName': tutorial.title.trim(),
        'muscleCategory': tutorial.category.trim(),
        'videoUrl': tutorial.videoUrl.trim(),
        'isActive': tutorial.status == TutorialStatus.active,
      };

  TutorialVideo _fromDocument(String id, Map<String, dynamic> data,
      {TutorialEditBaseline? baseline}) {
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
      editBaseline: baseline,
      title: (data['exerciseName'] as String).trim(),
      category: (data['muscleCategory'] as String).trim(),
      status: data['isActive'] == true
          ? TutorialStatus.active
          : TutorialStatus.draft,
      videoUrl: data['videoUrl'] as String,
    );
  }
}

class _CatalogBaseline extends TutorialEditBaseline {
  _CatalogBaseline(this.lifetime, this.id, Map<String, dynamic> document,
      Map<String, dynamic> membership, Map<String, dynamic> assignment)
      : document = _freeze(document) as Map<String, dynamic>,
        membership = _freeze(membership) as Map<String, dynamic>,
        assignment = _freeze(assignment) as Map<String, dynamic>,
        editable = Map<String, Object?>.unmodifiable({
          for (final key in [
            'exerciseName',
            'muscleCategory',
            'videoUrl',
            'isActive'
          ])
            key: document[key] is String
                ? (document[key] as String).trim()
                : document[key],
        });
  final Object lifetime;
  final String id;
  final Map<String, dynamic> document;
  final Map<String, dynamic> membership;
  final Map<String, dynamic> assignment;
  final Map<String, Object?> editable;
}

Object? _freeze(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
        value.map((key, entry) => MapEntry(key, _freeze(entry))));
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

bool _same(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        Iterable<int>.generate(a.length).every((i) => _same(a[i], b[i]));
  }
  return a == b;
}
