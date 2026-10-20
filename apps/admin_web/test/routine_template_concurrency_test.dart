// SDK objects are faked only at the injected transport boundary, not inherited
// by application code. The emulator tests exercise actual server Rules.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_routine_template_repository.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/workout.dart';

// The real repository runs against the SDK surface. The fake models aborted
// transaction writes and retries; emulator Rules cover the server boundary.
class _Firestore extends Fake implements FirebaseFirestore {
  final records = <String, Map<String, dynamic>>{
    'users/admin': {'organizationId': 'o'},
    'orgs/o/members/admin': {
      'organizationId': 'o',
      'role': 'admin',
      'status': 'active'
    },
    'orgs/o/exerciseVideos/e': {
      'schemaVersion': 1,
      'exerciseName': 'Squat',
      'isActive': true,
    },
    'orgs/o/routineBlueprints/r': {
      'schemaVersion': 1,
      'name': 'Original',
      'sessionDurationMin': 30,
      'days': [
        {
          'dayNumber': 1,
          'exercises': [
            {'exerciseId': 'e', 'sets': 3, 'reps': 8}
          ]
        }
      ],
      'createdAt': 1,
      'updatedAt': 2,
      'updatedBy': 'admin',
      'futureField': {'preserve': true},
    },
  };
  Map<String, dynamic>? patch;
  void Function()? retry;
  void Function()? afterRead;
  bool failReadBack = false;
  int commits = 0;
  int attempts = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    final tx = _Transaction(this);
    attempts++;
    var result = await handler(tx);
    if (retry != null) {
      tx.writes.clear();
      retry!();
      attempts++;
      result = await handler(tx);
    }
    for (final entry in tx.writes.entries) {
      patch = entry.value;
      records[entry.key]!.addAll(entry.value);
    }
    commits++;
    return result;
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Document(db, '$path/${id ?? 'created'}');
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get(
          [GetOptions? options]) async =>
      _Query(db.records.entries
          .where((e) =>
              e.key.startsWith('$path/') &&
              e.key.split('/').length == path.split('/').length + 1)
          .map((e) => _Snapshot(e.key.split('/').last, _clone(e.value)))
          .toList());
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      _Collection(db, '$path/$name');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    if (db.failReadBack &&
        db.commits > 0 &&
        path.contains('/routineBlueprints/')) {
      throw StateError('private-media-token-must-never-escape');
    }
    return _Snapshot(
        id, db.records[path] == null ? null : _clone(db.records[path]!));
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    db.patch = Map<String, dynamic>.from(data);
    db.records[path]!.addAll(db.patch!);
    db.commits++;
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    db.records[path] = Map.of(data);
    db.commits++;
  }
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.db);
  final _Firestore db;
  final writes = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
      DocumentReference<T> ref) async {
    final snapshot = await ref.get();
    if (ref.path.contains('/routineBlueprints/')) db.afterRead?.call();
    return snapshot;
  }

  @override
  Transaction update(DocumentReference ref, Map<Object, Object?> data) {
    writes[ref.path] = Map<String, dynamic>.from(data);
    return this;
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    db.records[ref.path] = <String, dynamic>{};
    writes[ref.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

class _Snapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic> data() => value!;
}

class _Query extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Query(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

Map<String, dynamic> _clone(Map<String, dynamic> data) =>
    data.map((k, v) => MapEntry(
        k,
        v is Map<String, dynamic>
            ? _clone(v)
            : v is List
                ? v
                    .map((x) => x is Map<String, dynamic> ? _clone(x) : x)
                    .toList()
                : v));

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? currentUser = _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'admin';
}

class _Functions extends Fake implements FirebaseFunctions {}

class _Catalog extends TutorialRepository {
  @override
  List<TutorialVideo> get tutorials => [
        TutorialVideo(
            id: 'e',
            title: 'Squat',
            category: 'Legs',
            status: TutorialStatus.active)
      ];
}

void main() {
  late _Firestore db;
  late _Auth auth;
  late FirebaseRoutineTemplateRepository repository;
  setUp(() {
    db = _Firestore();
    auth = _Auth();
    repository = FirebaseRoutineTemplateRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        exerciseCatalog: _Catalog(),
        firestore: db,
        auth: auth,
        functions: _Functions());
  });
  test('clean edit patches intended fields and preserves server metadata',
      () async {
    final original = (await repository.load()).single..name = 'Edited';
    await repository.save(original);
    expect(db.patch!.keys.toSet(), {'name', 'updatedAt', 'updatedBy'});
    expect(db.records['orgs/o/routineBlueprints/r']!['createdAt'], 1);
    expect(db.records['orgs/o/routineBlueprints/r']!['futureField'],
        {'preserve': true});
  });
  test('concurrent edit rejects original form rather than overwriting it',
      () async {
    final original = (await repository.load()).single..name = 'My edit';
    db.records['orgs/o/routineBlueprints/r']!['name'] = 'Other editor';
    await expectLater(
        repository.save(original), throwsA(isA<RoutineEditConflict>()));
    expect(db.records['orgs/o/routineBlueprints/r']!['name'], 'Other editor');
    expect(db.patch, isNull);
  });
  test('retry retains immutable original nested days baseline', () async {
    final original = (await repository.load()).single..goal = 'My goal';
    db.retry = () => (db.records['orgs/o/routineBlueprints/r']!['days'] as List)
        .first['exercises']
        .first['reps'] = 12;
    await expectLater(
        repository.save(original), throwsA(isA<RoutineEditConflict>()));
    expect(db.attempts, 2);
    expect(db.patch, isNull);
  });
  test('role or canonical organization change rejects edit', () async {
    final original = (await repository.load()).single..name = 'Edited';
    db.records['users/admin']!['organizationId'] = 'other';
    await expectLater(repository.save(original),
        throwsA(isA<RoutineEditAuthorizationChanged>()));
    expect(db.patch, isNull);
  });
  test('missing document is a safe conflict', () async {
    final original = (await repository.load()).single..name = 'Edited';
    db.records.remove('orgs/o/routineBlueprints/r');
    await expectLater(
        repository.save(original), throwsA(isA<RoutineEditConflict>()));
    expect(db.patch, isNull);
  });
  test('save does not report success if authoritative read-back fails',
      () async {
    final original = (await repository.load()).single..name = 'Edited';
    db.failReadBack = true;
    Object? failure;
    try {
      await repository.save(original);
    } catch (error) {
      failure = error;
    }
    expect(failure, isNotNull);
    expect('$failure', isNot(contains('private-media-token')));
  });
  test('create persists stable catalog IDs and reads its authoritative record',
      () async {
    final created = await repository.save(RoutineBlueprint(
        id: '',
        name: 'Created',
        level: 'Beginner',
        assignedMembers: 0,
        days: [
          const RoutineDay(
              1, [RoutineExerciseRef('Squat', 3, 8, exerciseId: 'e')])
        ]));
    expect(created.id, 'created');
    expect(created.editBaseline, isNotNull);
    expect(db.records['orgs/o/routineBlueprints/created']!['schemaVersion'], 1);
    expect(created.days.single.exercises.single.exerciseId, 'e');
  });
  test('unchanged form does not rewrite defaults or metadata', () async {
    await repository.save((await repository.load()).single);
    expect(db.patch, isNull);
    expect(db.records['orgs/o/routineBlueprints/r']!['updatedAt'], 2);
  });
  test('catalog deactivation between open and save rejects the save', () async {
    final original = (await repository.load()).single..name = 'Edited';
    db.records['orgs/o/exerciseVideos/e']!['isActive'] = false;
    await expectLater(
        repository.save(original), throwsA(isA<FormatException>()));
    expect(db.patch, isNull);
  });
  test('logout during transaction rejects pending save', () async {
    final original = (await repository.load()).single..name = 'Edited';
    db.afterRead = () => auth.currentUser = null;
    await expectLater(repository.save(original),
        throwsA(isA<RoutineEditAuthorizationChanged>()));
    expect(db.patch, isNull);
  });
  test('role change on retry cannot become a replacement baseline', () async {
    final original = (await repository.load()).single..name = 'Edited';
    db.retry = () => db.records['orgs/o/members/admin']!['role'] = 'staff';
    await expectLater(repository.save(original),
        throwsA(isA<RoutineEditAuthorizationChanged>()));
    expect(db.attempts, 2);
    expect(db.patch, isNull);
  });
  test('invalid targets fail before any write', () async {
    final original = (await repository.load()).single;
    original.days = [
      const RoutineDay(1, [RoutineExerciseRef('Squat', 0, 8, exerciseId: 'e')])
    ];
    await expectLater(
        repository.save(original), throwsA(isA<FormatException>()));
    expect(db.commits, 0);
  });
}
