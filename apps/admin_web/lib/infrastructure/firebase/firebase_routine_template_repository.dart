import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

String buildPublishRoutineRequestId({
  required int timestampMicros,
  Random? random,
}) {
  final suffix = (random ?? Random.secure()).nextInt(0x7fffffff);
  return '$timestampMicros-$suffix';
}

class FirebaseRoutineTemplateRepository implements RoutineTemplateRepository {
  FirebaseRoutineTemplateRepository({
    required this.scope,
    required this.exerciseCatalog,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance {
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Routine authoring scope requires document IDs.');
      }
    }
  }

  final SessionScope scope;
  final TutorialRepository exerciseCatalog;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> _collection() {
    _requireCurrentUser();
    return _firestore
        .collection('orgs')
        .doc(scope.organizationId)
        .collection('routineBlueprints');
  }

  void _requireCurrentUser() {
    if (_auth.currentUser?.uid != scope.userId) {
      throw StateError('Your session changed. Sign in again.');
    }
  }

  @override
  List<RoutineBlueprint> get routineTemplates => const [];

  @override
  Future<List<RoutineBlueprint>> load() async {
    final docs =
        await _collection().get(const GetOptions(source: Source.server));
    final exercises = {
      for (final item in await exerciseCatalog.load()) item.id: item
    };
    final result =
        docs.docs.map((doc) => _decode(doc.id, doc.data(), exercises)).toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(result);
  }

  @override
  Future<RoutineBlueprint> save(RoutineBlueprint blueprint) async {
    final reference = blueprint.id.isEmpty
        ? _collection().doc()
        : _collection().doc(blueprint.id);
    final catalog = {
      for (final item in await exerciseCatalog.load()) item.id: item
    };
    final days = encodeRoutineDays(blueprint, catalog.values);
    final isCreate = blueprint.id.isEmpty;
    final data = <String, Object?>{
      'schemaVersion': 1,
      'name': blueprint.name.trim(),
      'sessionDurationMin': blueprint.sessionDurationMin,
      'days': days,
      'level': blueprint.level,
      'goal': blueprint.goal.trim(),
      'tags': blueprint.tags,
      'equipmentNeeded': blueprint.equipmentNeeded,
      'imageUrl': blueprint.imageUrl.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': scope.userId,
    };
    if (isCreate) {
      await reference.set({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await reference.update(data);
    }
    return RoutineBlueprint(
      id: reference.id,
      name: blueprint.name,
      level: blueprint.level,
      assignedMembers: blueprint.assignedMembers,
      days: blueprint.days,
      goal: blueprint.goal,
      tags: blueprint.tags,
      sessionDurationMin: blueprint.sessionDurationMin,
      equipmentNeeded: blueprint.equipmentNeeded,
      imageUrl: blueprint.imageUrl,
    );
  }

  /// Stores only stable catalog references and targets inside each blueprint.
  static List<Map<String, Object?>> encodeRoutineDays(
    RoutineBlueprint blueprint,
    Iterable<TutorialVideo> catalogEntries,
  ) {
    final catalog = {for (final entry in catalogEntries) entry.id: entry};
    return blueprint.days.map((day) {
      if (day.dayNumber < 1 || day.exercises.isEmpty) {
        throw StateError('Each routine day needs a number and an exercise.');
      }
      return <String, Object?>{
        'dayNumber': day.dayNumber,
        'exercises': day.exercises.map((exercise) {
          final record = catalog[exercise.exerciseId];
          if (record == null || record.status != TutorialStatus.active) {
            throw StateError(
                'Select an active exercise from the catalog for every row.');
          }
          return <String, Object?>{
            'exerciseId': exercise.exerciseId,
            'sets': exercise.sets,
            'reps': exercise.reps,
          };
        }).toList(growable: false),
      };
    }).toList(growable: false);
  }

  @override
  Future<void> publish(String blueprintId) async {
    _requireCurrentUser();
    final requestId = buildPublishRoutineRequestId(
      timestampMicros: DateTime.now().microsecondsSinceEpoch,
    );
    await _functions.httpsCallable('publishRoutineCommand').call({
      'schemaVersion': 1,
      'requestId': requestId,
      'organizationId': scope.organizationId,
      'blueprintId': blueprintId,
    });
  }

  RoutineBlueprint _decode(String id, Map<String, dynamic> data,
      Map<String, TutorialVideo> exercises) {
    if (data['schemaVersion'] != 1 ||
        data['name'] is! String ||
        data['sessionDurationMin'] is! int ||
        data['days'] is! List) {
      throw const FormatException('Routine blueprint is invalid.');
    }
    final days = (data['days'] as List).map((value) {
      if (value is! Map<String, dynamic> ||
          value['dayNumber'] is! int ||
          value['exercises'] is! List) {
        throw const FormatException('Routine day is invalid.');
      }
      final refs = (value['exercises'] as List).map((raw) {
        if (raw is! Map<String, dynamic> ||
            raw['exerciseId'] is! String ||
            raw['sets'] is! int ||
            raw['reps'] is! int) {
          throw const FormatException('Routine exercise reference is invalid.');
        }
        final id = raw['exerciseId'] as String;
        final catalogEntry = exercises[id];
        if (catalogEntry == null) {
          throw FormatException('Routine references missing exercise $id.');
        }
        return RoutineExerciseRef(
            catalogEntry.title, raw['sets'] as int, raw['reps'] as int,
            exerciseId: id);
      }).toList(growable: false);
      return RoutineDay(value['dayNumber'] as int, refs);
    }).toList(growable: false);
    return RoutineBlueprint(
      id: id,
      name: data['name'] as String,
      level: data['level'] is String ? data['level'] as String : 'Beginner',
      assignedMembers: 0,
      days: days,
      goal: data['goal'] is String ? data['goal'] as String : '',
      tags: data['tags'] is List
          ? List<String>.from(data['tags'] as List)
          : const [],
      sessionDurationMin: data['sessionDurationMin'] as int,
      equipmentNeeded: data['equipmentNeeded'] is List
          ? List<String>.from(data['equipmentNeeded'] as List)
          : const [],
      imageUrl: data['imageUrl'] is String ? data['imageUrl'] as String : '',
    );
  }
}
