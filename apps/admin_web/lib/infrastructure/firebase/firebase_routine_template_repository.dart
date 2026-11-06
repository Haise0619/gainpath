import 'dart:convert';
import 'firebase_data_scope.dart';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'firebase_function_transport.dart';

String buildPublishRoutineRequestId({
  required int timestampMicros,
  Random? random,
}) {
  final suffix = (random ?? Random.secure()).nextInt(0x7fffffff);
  return '$timestampMicros-$suffix';
}

class FirebaseRoutineTemplateRepository
    implements RoutineTemplateRepository, RoutineArchivingRepository {
  FirebaseRoutineTemplateRepository({
    required this.scope,
    required this.exerciseCatalog,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    bool Function()? isSessionCurrent,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions,
        _sessionGuard = isSessionCurrent {
    for (final id in [scope.userId, scope.organizationId]) {
      if (id.contains('/') || id == '.' || id == '..') {
        throw ArgumentError('Routine authoring scope requires document IDs.');
      }
    }
  }

  final SessionScope scope;
  final _pendingV2Commands = <String, Map<String, Object?>>{};
  final _pendingPublishRequests = <String, String>{};
  final TutorialRepository exerciseCatalog;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions? _functions;
  final bool Function()? _sessionGuard;
  final Object _lifetime = Object();
  bool _invalidated = false;
  bool _saving = false;
  final Set<String> _v2Ids = {};

  CollectionReference<Map<String, dynamic>> _collection() {
    _requireCurrentUser();
    return _firestore.scopeRoot(scope).collection('routineBlueprints');
  }

  void _requireCurrentUser() {
    if (_invalidated ||
        (_sessionGuard != null && !_sessionGuard()) ||
        _auth.currentUser?.uid != scope.userId) {
      _invalidated = true;
      throw const RoutineEditAuthorizationChanged();
    }
  }

  @override
  List<RoutineBlueprint> get routineTemplates => const [];

  @override
  Future<List<RoutineBlueprint>> load() async {
    try {
      _requireCurrentUser();
      final assignment =
          await _assignment.get(const GetOptions(source: Source.server));
      final membership =
          await _member.get(const GetOptions(source: Source.server));
      _requireAuthor(assignment.data(), membership.data());
      final docs =
          await _collection().get(const GetOptions(source: Source.server));
      final upgraded = await _firestore
          .scopeRoot(scope)
          .collection('routineBlueprintsV2')
          .get(const GetOptions(source: Source.server));
      _v2Ids
        ..clear()
        ..addAll(upgraded.docs
            .where((d) => d.data()['archived'] != true)
            .map((d) => d.id));
      final exercises = {
        for (final item in await exerciseCatalog.load()) item.id: item
      };
      _requireCurrentUser();
      final result = [
        ...docs.docs.where((d) => !_v2Ids.contains(d.id)),
        ...upgraded.docs
      ]
          .where((doc) => doc.data()['archived'] != true)
          .map((doc) => _decode(doc.id, doc.data(), exercises,
              baseline: _RoutineBaseline(_lifetime, doc.id, doc.data(),
                  assignment.data()!, membership.data()!)))
          .toList();
      result
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return List.unmodifiable(result);
    } on RoutineEditAuthorizationChanged {
      rethrow;
    } on FirebaseException catch (error) {
      _translateAuthorization(error);
      throw const FormatException('Could not load routine templates.');
    } catch (_) {
      throw const FormatException('Could not load routine templates.');
    }
  }

  DocumentReference<Map<String, dynamic>> get _assignment =>
      _firestore.scopeUser(scope);
  DocumentReference<Map<String, dynamic>> get _member =>
      _firestore.scopeRoot(scope).collection('members').doc(scope.userId);

  void _requireAuthor(
      Map<String, dynamic>? assignment, Map<String, dynamic>? membership) {
    _requireCurrentUser();
    if (assignment?['organizationId'] != scope.organizationId ||
        membership?['organizationId'] != scope.organizationId ||
        membership?['status'] != 'active' ||
        !const ['admin', 'staff'].contains(membership?['role'])) {
      _invalidated = true;
      throw const RoutineEditAuthorizationChanged();
    }
  }

  void _translateAuthorization(FirebaseException error) {
    if (error.code == 'permission-denied' || error.code == 'unauthenticated') {
      _invalidated = true;
      throw const RoutineEditAuthorizationChanged();
    }
  }

  @override
  Future<RoutineBlueprint> save(RoutineBlueprint blueprint) async {
    if (_saving) throw const RoutineSaveFailed();
    _saving = true;
    try {
      return await _save(blueprint);
    } on RoutineEditConflict {
      rethrow;
    } on RoutineEditAuthorizationChanged {
      _invalidated = true;
      rethrow;
    } on FormatException {
      rethrow;
    } on FirebaseException catch (error) {
      _translateAuthorization(error);
      throw const RoutineSaveFailed();
    } catch (_) {
      throw const RoutineSaveFailed();
    } finally {
      _saving = false;
    }
  }

  Future<RoutineBlueprint> _save(RoutineBlueprint blueprint) async {
    _requireCurrentUser();
    if (blueprint.schemaVersion == 2) return _saveV2(blueprint);
    // Snapshot mutable form lists BEFORE the first await. Neither retries nor
    // edits made while a request is pending may change the intended patch.
    final data = _editableFields(blueprint);
    _validate(data);
    final baseline = blueprint.editBaseline;
    final isCreate = blueprint.id.isEmpty;
    if (!isCreate &&
        (baseline is! _RoutineBaseline ||
            !identical(baseline.lifetime, _lifetime) ||
            baseline.id != blueprint.id)) {
      throw const RoutineEditConflict();
    }
    final reference = blueprint.id.isEmpty
        ? _collection().doc()
        : _collection().doc(blueprint.id);
    final original = baseline is _RoutineBaseline ? baseline : null;
    final patch = <String, Object?>{
      for (final field in data.entries)
        if (isCreate || !_same(field.value, original!.editable[field.key]))
          field.key: field.value,
    };
    final catalog = {
      for (final item in await exerciseCatalog.load()) item.id: item
    };
    Map<String, dynamic>? savedAssignment;
    Map<String, dynamic>? savedMembership;
    // Keep safe domain failures outside Flutter web's JS exception wrapping.
    Object? domainFailure;
    try {
      await _firestore.runTransaction<void>((transaction) async {
        if (domainFailure != null) throw StateError('Routine edit aborted.');
        try {
          _requireCurrentUser();
          final assignment = (await transaction.get(_assignment)).data();
          final membership = (await transaction.get(_member)).data();
          _requireAuthor(assignment, membership);
          if (original != null &&
              (!_same(assignment, original.assignment) ||
                  !_same(membership, original.membership))) {
            throw const RoutineEditAuthorizationChanged();
          }
          final current = await transaction.get(reference);
          if (isCreate
              ? current.exists
              : !current.exists ||
                  current.data()?['archived'] == true ||
                  !_same(current.data(), original!.document)) {
            throw const RoutineEditConflict();
          }
          for (final id in _exerciseIds(data)) {
            final exercise = await transaction.get(_firestore
                .scopeRoot(scope)
                .collection('exerciseVideos')
                .doc(id));
            if (!exercise.exists ||
                exercise.data()?['schemaVersion'] != 1 ||
                exercise.data()?['isActive'] != true) {
              throw const FormatException(
                  'Select active catalog exercises for every row.');
            }
          }
          _requireCurrentUser();
          savedAssignment = assignment;
          savedMembership = membership;
          final fields = {
            ...patch,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': scope.userId
          };
          if (isCreate) {
            transaction.set(reference, {
              ...fields,
              'schemaVersion': 1,
              'createdAt': FieldValue.serverTimestamp()
            });
          } else if (patch.isNotEmpty) {
            transaction.update(reference, fields);
          }
        } on RoutineEditConflict catch (error) {
          domainFailure = error;
          throw StateError('Routine edit aborted.');
        } on RoutineEditAuthorizationChanged catch (error) {
          domainFailure = error;
          throw StateError('Routine edit aborted.');
        } on FormatException catch (error) {
          domainFailure = error;
          throw StateError('Routine edit aborted.');
        }
      });
    } catch (_) {
      if (domainFailure != null) throw domainFailure!;
      rethrow;
    }
    _requireCurrentUser();
    final persisted =
        await reference.get(const GetOptions(source: Source.server));
    _requireCurrentUser();
    if (!persisted.exists) throw const RoutineSaveFailed();
    try {
      return _decode(reference.id, persisted.data()!, catalog,
          baseline: _RoutineBaseline(_lifetime, reference.id, persisted.data()!,
              savedAssignment!, savedMembership!));
    } catch (_) {
      // A write may already be committed. Never classify a malformed read-back
      // as a retryable form validation failure (especially for creates).
      throw const RoutineSaveFailed();
    }
  }

  Future<RoutineBlueprint> _saveV2(RoutineBlueprint blueprint) async {
    final baseline = blueprint.editBaseline;
    if (blueprint.id.isNotEmpty &&
        (baseline is! _RoutineBaseline ||
            !identical(baseline.lifetime, _lifetime) ||
            baseline.id != blueprint.id)) {
      throw const RoutineEditConflict();
    }
    final assignment =
        await _assignment.get(const GetOptions(source: Source.server));
    final member = await _member.get(const GetOptions(source: Source.server));
    _requireAuthor(assignment.data(), member.data());
    final original = baseline is _RoutineBaseline ? baseline : null;
    if (original != null &&
        (!_same(original.assignment, assignment.data()) ||
            !_same(original.membership, member.data()))) {
      throw const RoutineEditAuthorizationChanged();
    }
    final catalog = await exerciseCatalog.load();
    final data = _editableFields(blueprint);
    data['schemaVersion'] = 2;
    data['days'] = encodeRoutineDays(blueprint, catalog);
    final commandKey = jsonEncode([blueprint.id, data]);
    final pending = _pendingV2Commands[commandKey];
    final id = pending?['blueprintId'] as String? ??
        (blueprint.id.isEmpty
            ? _firestore
                .scopeRoot(scope)
                .collection('routineBlueprintsV2')
                .doc()
                .id
            : blueprint.id);
    _requireCurrentUser();
    final command = pending ??
        <String, Object?>{
          'schemaVersion': 1,
          'action': 'saveBlueprintV2',
          'organizationId': scope.organizationId,
          'blueprintId': id,
          'requestId': buildPublishRoutineRequestId(
              timestampMicros: DateTime.now().microsecondsSinceEpoch),
          'expectedRevision': original?.document['schemaVersion'] == 2
              ? original!.document['editRevision'] ?? 0
              : 0,
          if (original?.document['schemaVersion'] == 1)
            'expectedLegacyUpdatedAtMillis':
                (original!.document['updatedAt'] as Timestamp)
                    .millisecondsSinceEpoch,
          'blueprint': data,
        };
    _pendingV2Commands[commandKey] = command;
    try {
      await firebaseScopedCallable(scope, 'exerciseCatalogCommand',
              functions: _functions)
          .call(command);
    } on FirebaseFunctionsException catch (error) {
      if (['aborted', 'already-exists', 'failed-precondition']
          .contains(error.code)) throw const RoutineEditConflict();
      if (['permission-denied', 'unauthenticated'].contains(error.code))
        throw const RoutineEditAuthorizationChanged();
      rethrow;
    }
    _requireCurrentUser();
    final persisted = await _firestore
        .scopeRoot(scope)
        .collection('routineBlueprintsV2')
        .doc(id)
        .get(const GetOptions(source: Source.server));
    _requireCurrentUser();
    if (!persisted.exists) throw const RoutineSaveFailed();
    final result = _decode(
        id, persisted.data()!, {for (final e in catalog) e.id: e},
        baseline: _RoutineBaseline(_lifetime, id, persisted.data()!,
            assignment.data()!, member.data()!));
    _v2Ids.add(id);
    _pendingV2Commands.remove(commandKey);
    return result;
  }

  @override
  Future<void> archive(RoutineBlueprint blueprint) async {
    if (_saving) throw const RoutineSaveFailed();
    _saving = true;
    Object? domainFailure;
    try {
      _requireCurrentUser();
      final baseline = blueprint.editBaseline;
      if (baseline is! _RoutineBaseline ||
          !identical(baseline.lifetime, _lifetime) ||
          baseline.id != blueprint.id) throw const RoutineEditConflict();
      if (blueprint.schemaVersion == 2) {
        await firebaseScopedCallable(scope, 'exerciseCatalogCommand',
                functions: _functions)
            .call({
          'schemaVersion': 1,
          'action': 'archiveBlueprintV2',
          'organizationId': scope.organizationId,
          'blueprintId': blueprint.id,
          'expectedRevision': baseline.document['editRevision'] ?? 0,
          'requestId': buildPublishRoutineRequestId(
              timestampMicros: DateTime.now().microsecondsSinceEpoch)
        });
        _requireCurrentUser();
        return;
      }
      final reference = _collection().doc(blueprint.id);
      try {
        await _firestore.runTransaction<void>((transaction) async {
          if (domainFailure != null) throw StateError('Archive aborted.');
          try {
            _requireCurrentUser();
            final assignment = (await transaction.get(_assignment)).data();
            final membership = (await transaction.get(_member)).data();
            _requireAuthor(assignment, membership);
            if (!_same(assignment, baseline.assignment) ||
                !_same(membership, baseline.membership)) {
              throw const RoutineEditAuthorizationChanged();
            }
            final current = await transaction.get(reference);
            _requireCurrentUser();
            if (!current.exists || !_same(current.data(), baseline.document)) {
              throw const RoutineEditConflict();
            }
            transaction.update(reference, {
              'archived': true,
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedBy': scope.userId
            });
          } on RoutineEditConflict catch (error) {
            domainFailure = error;
            throw StateError('Archive aborted.');
          } on RoutineEditAuthorizationChanged catch (error) {
            domainFailure = error;
            throw StateError('Archive aborted.');
          }
        });
      } catch (_) {
        if (domainFailure != null) throw domainFailure!;
        rethrow;
      }
      final saved =
          await reference.get(const GetOptions(source: Source.server));
      _requireCurrentUser();
      if (saved.data()?['archived'] != true) throw const RoutineSaveFailed();
    } on RoutineEditConflict {
      rethrow;
    } on RoutineEditAuthorizationChanged {
      rethrow;
    } on FirebaseException catch (error) {
      _translateAuthorization(error);
      throw const RoutineSaveFailed();
    } catch (_) {
      throw const RoutineSaveFailed();
    } finally {
      _saving = false;
    }
  }

  static Map<String, Object?> _editableFields(RoutineBlueprint blueprint) => {
        'name': blueprint.name.trim(),
        'sessionDurationMin': blueprint.sessionDurationMin,
        'days': blueprint.days
            .map((day) => <String, Object?>{
                  'dayNumber': day.dayNumber,
                  'exercises': day.exercises
                      .map((e) => <String, Object?>{
                            'exerciseId': e.exerciseId,
                            'sets': e.sets,
                            if (blueprint.schemaVersion == 1) 'reps': e.reps,
                            if (blueprint.schemaVersion == 2) ...{
                              'entryId': e.entryId,
                              'executionMode': e.executionMode?.name,
                              ...e.prescription!.toJson(),
                              if (e.sourceCatalogRevision != null)
                                'sourceCatalogRevision':
                                    e.sourceCatalogRevision,
                            },
                          })
                      .toList()
                })
            .toList(),
        'level': blueprint.level,
        'goal': blueprint.goal.trim(),
        'tags': List<String>.of(blueprint.tags),
        'equipmentNeeded': List<String>.of(blueprint.equipmentNeeded),
        'imageUrl': blueprint.imageUrl.trim(),
      };

  static Iterable<String> _exerciseIds(Map<String, Object?> data) =>
      (data['days'] as List)
          .expand((day) =>
              (day['exercises'] as List).map((e) => e['exerciseId'] as String))
          .toSet();

  static void _validate(Map<String, Object?> data) {
    final name = data['name'] as String;
    final duration = data['sessionDurationMin'] as int;
    final days = data['days'] as List;
    if (name.isEmpty ||
        name.length > 120 ||
        duration < 5 ||
        duration > 240 ||
        days.isEmpty ||
        days.length > 14) {
      throw const FormatException(
          'Use a name of 1–120 characters, 5–240 minutes and 1–14 days.');
    }
    var total = 0;
    final seen = <int>{};
    for (final day in days) {
      final number = day['dayNumber'] as int;
      final exercises = day['exercises'] as List;
      if (number < 1 ||
          number > 14 ||
          !seen.add(number) ||
          exercises.isEmpty ||
          exercises.length > 20) {
        throw const FormatException(
            'Use unique days 1–14 with 1–20 exercises each.');
      }
      total += exercises.length;
      for (final exercise in exercises) {
        final id = exercise['exerciseId'] as String;
        if (id.isEmpty ||
            id.contains('/') ||
            id == '.' ||
            id == '..' ||
            exercise['sets'] < 1 ||
            exercise['sets'] > 50 ||
            exercise['reps'] < 1 ||
            exercise['reps'] > 100) {
          throw const FormatException(
              'Select catalog exercises with sets 1–50 and reps 1–100.');
        }
      }
    }
    if (total > 50) {
      throw const FormatException(
          'A routine can contain at most 50 exercises.');
    }
  }

  /// Stores only stable catalog references and targets inside each blueprint.
  static List<Map<String, Object?>> encodeRoutineDays(
    RoutineBlueprint blueprint,
    Iterable<TutorialVideo> catalogEntries,
  ) {
    final catalog = {for (final entry in catalogEntries) entry.id: entry};
    final entryIds = <String>{};
    return blueprint.days.map((day) {
      if (day.dayNumber < 1 || day.exercises.isEmpty) {
        throw StateError('Each routine day needs a number and an exercise.');
      }
      return <String, Object?>{
        'dayNumber': day.dayNumber,
        'exercises': day.exercises.map((exercise) {
          final record = catalog[exercise.exerciseId];
          if (record == null ||
              record.archived ||
              record.status != TutorialStatus.active) {
            throw StateError(
                'Select an active exercise from the catalog for every row.');
          }
          if (blueprint.schemaVersion == 2) {
            final target = exercise.prescription;
            if (exercise.entryId.trim().isEmpty ||
                !entryIds.add(exercise.entryId) ||
                target == null ||
                exercise.executionMode == null ||
                target.sets != exercise.sets ||
                (target is TimedPrescription) !=
                    (exercise.executionMode ==
                        ExerciseExecutionMode.videoGuidedTimed) ||
                (target is TimedPrescription && exercise.reps != null) ||
                (target is RepetitionPrescription &&
                    target.repetitions != exercise.reps)) {
              throw const FormatException(
                  'Invalid stable routine entry or target');
            }
            target.validate();
          }
          return <String, Object?>{
            'exerciseId': exercise.exerciseId,
            if (blueprint.schemaVersion == 1) ...{
              'sets': exercise.sets,
              'reps': exercise.reps
            },
            if (blueprint.schemaVersion == 2) ...{
              'entryId': exercise.entryId,
              'executionMode': exercise.executionMode?.name,
              ...exercise.prescription!.toJson(),
              if (exercise.sourceCatalogRevision != null)
                'sourceCatalogRevision': exercise.sourceCatalogRevision,
            },
          };
        }).toList(growable: false),
      };
    }).toList(growable: false);
  }

  @override
  Future<void> publish(String blueprintId) async {
    _requireCurrentUser();
    final requestId = _pendingPublishRequests.putIfAbsent(
        blueprintId,
        () => buildPublishRoutineRequestId(
              timestampMicros: DateTime.now().microsecondsSinceEpoch,
            ));
    try {
      final response = await firebaseScopedCallable(
              scope, 'publishRoutineCommand',
              functions: _functions)
          .call({
        'schemaVersion': _v2Ids.contains(blueprintId) ? 2 : 1,
        'requestId': requestId,
        'organizationId': scope.organizationId,
        'blueprintId': blueprintId,
      });
      _requireCurrentUser();
      if (_v2Ids.contains(blueprintId)) {
        final result = Map<String, dynamic>.from(response.data as Map),
            contentId = 'routine_v2_$blueprintId';
        if (result['schemaVersion'] != 2 ||
            result['requestId'] != requestId ||
            result['sourceBlueprintId'] != blueprintId ||
            result['contentId'] != contentId ||
            result['status'] != 'published') throw const RoutinePublishFailed();
        final persisted = await _firestore
            .scopeRoot(scope)
            .collection('content')
            .doc(contentId)
            .get(const GetOptions(source: Source.server));
        _requireCurrentUser();
        if (!persisted.exists ||
            persisted.data()?['schemaVersion'] != 2 ||
            persisted.data()?['kind'] != 'routine_v2' ||
            persisted.data()?['status'] != 'published' ||
            persisted.data()?['sourceBlueprintId'] != blueprintId ||
            persisted.data()?['publishedAtMillis'] !=
                result['publishedAtMillis']) throw const RoutinePublishFailed();
      }
      _pendingPublishRequests.remove(blueprintId);
    } on RoutineEditAuthorizationChanged {
      rethrow;
    } catch (_) {
      throw const RoutinePublishFailed();
    }
  }

  RoutineBlueprint _decode(String id, Map<String, dynamic> data,
      Map<String, TutorialVideo> exercises,
      {RoutineEditBaseline? baseline}) {
    if (![1, 2].contains(data['schemaVersion']) ||
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
            (data['schemaVersion'] == 1 && raw['reps'] is! int)) {
          throw const FormatException('Routine exercise reference is invalid.');
        }
        final id = raw['exerciseId'] as String;
        final catalogEntry = exercises[id];
        if (catalogEntry == null) {
          throw FormatException('Routine references missing exercise $id.');
        }
        return RoutineExerciseRef(
            catalogEntry.title, raw['sets'] as int, raw['reps'] as int?,
            exerciseId: id,
            entryId: raw['entryId'] as String? ?? '',
            executionMode: data['schemaVersion'] == 2
                ? ExerciseExecutionMode.fromJson(raw['executionMode'])
                : null,
            prescription: data['schemaVersion'] == 2
                ? ExercisePrescription.fromJson(raw)
                : null,
            sourceCatalogRevision: raw['sourceCatalogRevision'] as int?);
      }).toList(growable: false);
      return RoutineDay(value['dayNumber'] as int, refs);
    }).toList(growable: false);
    return RoutineBlueprint(
      id: id,
      editBaseline: baseline,
      schemaVersion: data['schemaVersion'] as int,
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

class _RoutineBaseline extends RoutineEditBaseline {
  _RoutineBaseline(this.lifetime, this.id, Map<String, dynamic> document,
      Map<String, dynamic> assignment, Map<String, dynamic> membership)
      : document = _freeze(document) as Map<String, dynamic>,
        assignment = _freeze(assignment) as Map<String, dynamic>,
        membership = _freeze(membership) as Map<String, dynamic>,
        editable = _freeze({
          'name': (document['name'] as String).trim(),
          'sessionDurationMin': document['sessionDurationMin'],
          'days': document['days'],
          'level': document['level'] ?? 'Beginner',
          'goal': (document['goal'] as String? ?? '').trim(),
          'tags': document['tags'] ?? <String>[],
          'equipmentNeeded': document['equipmentNeeded'] ?? <String>[],
          'imageUrl': (document['imageUrl'] as String? ?? '').trim(),
        }) as Map<String, dynamic>;
  final Object lifetime;
  final String id;
  final Map<String, dynamic> document, assignment, membership, editable;
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
