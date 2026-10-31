import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'exercise_catalog_store.dart';
import 'firebase_exercise_media_store.dart';

class FirebaseExerciseCatalogRepository
    implements
        TutorialRepository,
        TutorialMediaRepository,
        TutorialArchivingRepository,
        TutorialCatalogStatusRepository {
  FirebaseExerciseCatalogRepository({
    required this.scope,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ExerciseCatalogStore? store,
    TutorialMediaStore? mediaStore,
    bool Function()? isSessionCurrent,
  })  : _firestore = firestore,
        _auth = auth,
        _injectedStore = store,
        _injectedMediaStore = mediaStore,
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
  final TutorialMediaStore? _injectedMediaStore;
  late final TutorialMediaStore _mediaStore = _injectedMediaStore ??
      FirebaseExerciseMediaStore(
          scope: scope,
          isCurrent: () {
            try {
              _requireCurrentUser();
              return true;
            } catch (_) {
              return false;
            }
          });
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
  Future<TutorialVideo> saveWithMedia(TutorialVideo tutorial,
      {EquipmentImage? cover,
      EquipmentVideo? video,
      void Function(double)? onVideoProgress}) async {
    if (cover == null && video == null) return save(tutorial);
    _requireCurrentUser();
    if (tutorial.archived) throw const TutorialEditConflict();
    encodeCatalogFields(tutorial); // Validate text before sending any bytes.
    final baseline = tutorial.editBaseline;
    if (tutorial.id.isNotEmpty &&
        (baseline is! _CatalogBaseline ||
            !identical(baseline.lifetime, _lifetime) ||
            baseline.id != tutorial.id)) {
      throw const TutorialEditConflict();
    }
    Map<String, dynamic>? assignment, membership;
    Future<void> checkAuthority() async {
      _requireCurrentUser();
      final currentAssignment = await _store.readAssignment();
      _requireAssignment(currentAssignment);
      final currentMembership = await _store.readMembership();
      _requireAuthor(currentMembership);
      _requireCurrentUser();
      if ((assignment != null && !_same(assignment, currentAssignment)) ||
          (membership != null && !_same(membership, currentMembership)) ||
          (baseline is _CatalogBaseline &&
              (!_same(baseline.assignment, currentAssignment) ||
                  !_same(baseline.membership, currentMembership)))) {
        _invalidated = true;
        throw const TutorialEditAuthorizationChanged();
      }
      assignment ??= _freeze(currentAssignment) as Map<String, dynamic>;
      membership ??= _freeze(currentMembership) as Map<String, dynamic>;
    }

    try {
      await checkAuthority();
      if (baseline is _CatalogBaseline) {
        final current = await _store.readExercise(tutorial.id);
        _requireCurrentUser();
        if (current?['archived'] == true ||
            !_same(current, baseline.document)) {
          throw const TutorialEditConflict();
        }
      }
      var coverUrl = tutorial.thumbnailUrl, videoUrl = tutorial.videoUrl;
      if (cover != null) {
        coverUrl = await _mediaStore.uploadCover(cover);
        await checkAuthority();
      }
      if (video != null) {
        videoUrl =
            await _mediaStore.uploadVideo(video, onProgress: onVideoProgress);
        await checkAuthority();
      }
      return await save(TutorialVideo(
          id: tutorial.id,
          editBaseline: tutorial.editBaseline,
          trackingCapability: tutorial.trackingCapability,
          title: tutorial.title,
          category: tutorial.category,
          status: tutorial.status,
          coversExercise: tutorial.coversExercise,
          difficulty: tutorial.difficulty,
          durationMin: tutorial.durationMin,
          videoUrl: videoUrl,
          thumbnailUrl: coverUrl,
          description: tutorial.description,
          equipment: tutorial.equipment,
          tutorialSteps: tutorial.tutorialSteps));
    } on TutorialEditConflict {
      rethrow;
    } on TutorialEditAuthorizationChanged {
      rethrow;
    } on TutorialCatalogSaveFailed {
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        _invalidated = true;
        throw const TutorialEditAuthorizationChanged();
      }
      throw const TutorialMediaUploadFailed();
    } catch (_) {
      throw const TutorialMediaUploadFailed();
    }
  }

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
    if (tutorial.archived) throw const TutorialEditConflict();
    final data = encodeCatalogFields(tutorial);
    if (tutorial.id.isEmpty) {
      _requireAssignment(await _store.readAssignment());
      final membership = await _store.readMembership();
      _requireAuthor(membership);
      _requireCurrentUser();
      final id = await _store.create(data);
      _requireCurrentUser();
      return _readBack(id);
    }
    final baseline = tutorial.editBaseline;
    if (baseline is! _CatalogBaseline ||
        !identical(baseline.lifetime, _lifetime) ||
        baseline.id != tutorial.id) {
      throw const TutorialEditConflict();
    }
    final editable = {...const ExerciseTutorialDetails().toJson(), ...data};
    final patch = Map<String, Object?>.unmodifiable({
      for (final field in editable.entries)
        if (field.key != 'schemaVersion' &&
            !_same(field.value, baseline.editable[field.key]))
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
      if (current?['archived'] == true) throw const TutorialEditConflict();
      if (patch.isNotEmpty) transaction.update(tutorial.id, patch);
    });
    _requireCurrentUser();
    return _readBack(tutorial.id);
  }

  @override
  Future<void> archive(TutorialVideo tutorial) async {
    await setCatalogStatus(tutorial, ExerciseCatalogStatus.archived);
  }

  @override
  Future<TutorialVideo> setCatalogStatus(
      TutorialVideo tutorial, ExerciseCatalogStatus status) async {
    try {
      _requireCurrentUser();
      final baseline = tutorial.editBaseline;
      if (baseline is! _CatalogBaseline ||
          !identical(baseline.lifetime, _lifetime) ||
          baseline.id != tutorial.id) {
        throw const TutorialEditConflict();
      }
      await _store.transaction((transaction) async {
        _requireCurrentUser();
        final assignment = await transaction.readAssignment();
        final membership = await transaction.readMembership();
        _requireAssignment(assignment);
        _requireAuthor(membership);
        if (!_same(assignment, baseline.assignment) ||
            !_same(membership, baseline.membership)) {
          throw const TutorialEditAuthorizationChanged();
        }
        final current = await transaction.readExercise(tutorial.id);
        _requireCurrentUser();
        if (!_same(current, baseline.document)) {
          throw const TutorialEditConflict();
        }
        transaction.update(tutorial.id, {
          'archived': status == ExerciseCatalogStatus.archived,
          'isActive': status == ExerciseCatalogStatus.active,
        });
      });
      final saved = await _store.readExercise(tutorial.id);
      _requireCurrentUser();
      final assignment = await _store.readAssignment();
      _requireAssignment(assignment);
      final membership = await _store.readMembership();
      _requireAuthor(membership);
      _requireCurrentUser();
      if (!_same(assignment, baseline.assignment) ||
          !_same(membership, baseline.membership)) {
        throw const TutorialEditAuthorizationChanged();
      }
      if (saved == null ||
          saved['archived'] != (status == ExerciseCatalogStatus.archived) ||
          saved['isActive'] != (status == ExerciseCatalogStatus.active)) {
        throw const TutorialCatalogSaveFailed();
      }
      return _fromDocument(tutorial.id, saved);
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

  Future<TutorialVideo> _readBack(String id) async {
    final persisted = await _store.readExercise(id);
    _requireCurrentUser();
    if (persisted == null) {
      throw const TutorialCatalogSaveFailed();
    }
    // Successful form closes. Another edit must explicitly reload a baseline.
    return _fromDocument(id, persisted);
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
  static Map<String, Object?> encodeCatalogFields(TutorialVideo tutorial) {
    final details =
        ExerciseTutorialDetails.fromJson(tutorial.tutorialDetails.toJson());
    final defaults = const ExerciseTutorialDetails().toJson();
    return {
      'schemaVersion': 1,
      'exerciseName': tutorial.title.trim(),
      'muscleCategory': tutorial.category.trim(),
      'videoUrl': tutorial.videoUrl.trim(),
      'isActive': tutorial.status == TutorialStatus.active,
      for (final field in details.toJson().entries)
        if (!_same(field.value, defaults[field.key])) field.key: field.value,
    };
  }

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
    final details = ExerciseTutorialDetails.fromJson(data);
    return TutorialVideo(
      id: id,
      archived: data['archived'] == true,
      trackingCapability: ExerciseTrackingRegistry.resolve(
          organizationId: scope.organizationId, exerciseId: id),
      editBaseline: baseline,
      title: (data['exerciseName'] as String).trim(),
      category: (data['muscleCategory'] as String).trim(),
      status: data['isActive'] == true
          ? TutorialStatus.active
          : TutorialStatus.draft,
      videoUrl: data['videoUrl'] as String,
      description: details.description,
      thumbnailUrl: details.coverImageUrl,
      difficulty: details.difficulty,
      equipment: details.equipment,
      tutorialSteps: details.steps,
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
          ...ExerciseTutorialDetails.fromJson(document).toJson(),
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
