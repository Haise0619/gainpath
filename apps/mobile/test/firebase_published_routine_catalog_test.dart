// SDK query doubles record method calls; these annotations apply only to
// this test fixture, never to runtime classes or architecture checks.
// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_published_routine_repository.dart';

Map<String, dynamic> document(String title, {String status = 'published'}) => {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': status,
      'sourceBlueprintId': 'blueprint',
      'title': title,
      'estimatedMinutes': 30,
      'exercises': [
        {
          'exerciseId': 'exercise',
          'name': 'Fixture',
          'sets': 3,
          'reps': 8,
          'dayNumber': 1
        }
      ]
    };

class _User implements User {
  @override
  String get uid => 'member';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth implements FirebaseAuth {
  bool signedIn = true;
  @override
  User? get currentUser => signedIn ? _User() : null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Doc implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Snapshot implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Firestore implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{
    'orgs/org/content/a': document('A'),
    'orgs/org/content/b': document('B'),
    'orgs/org/content/c': document('C'),
    'orgs/org/content/draft': document('Draft', status: 'draft'),
    'orgs/other/content/z': document('Other org'),
  };
  final reads = <({
    String path,
    Map<Object, Object?> filters,
    int limit,
    String? after,
    String? from,
    bool ordered,
    Source? source
  })>[];
  Completer<void>? delay;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Query(this, path);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Query(db, '$path/$collectionPath');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Query implements CollectionReference<Map<String, dynamic>> {
  _Query(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  final filters = <Object, Object?>{};
  int pageLimit = 999;
  String? after;
  String? from;
  bool ordered = false;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference(db, '${this.path}/$path');
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    db.reads.add((
      path: path,
      filters: Map.of(filters),
      limit: pageLimit,
      after: after,
      from: from,
      ordered: ordered,
      source: options?.source
    ));
    await db.delay?.future;
    final entries = db.documents.entries.where((e) {
      if (!e.key.startsWith('$path/') ||
          e.key.substring(path.length + 1).contains('/')) {
        return false;
      }
      final id = e.key.split('/').last;
      return (after == null || id.compareTo(after!) > 0) &&
          (from == null || id.compareTo(from!) >= 0) &&
          filters.entries.every((f) =>
              f.key is String ? e.value[f.key] == f.value : id == f.value);
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return _Snapshot(entries
        .take(pageLimit)
        .map((e) => _Doc(e.key.split('/').last, e.value))
        .toList());
  }

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #where) {
      filters[i.positionalArguments.first] = i.namedArguments[#isEqualTo];
      return this;
    }
    if (i.memberName == #limit) {
      pageLimit = i.positionalArguments.first as int;
      return this;
    }
    if (i.memberName == #orderBy) {
      ordered = true;
      return this;
    }
    if (i.memberName == #startAfter) {
      after = (i.positionalArguments.first as List).single as String;
      return this;
    }
    if (i.memberName == #startAt) {
      from = (i.positionalArguments.first as List).single as String;
      return this;
    }
    return super.noSuchMethod(i);
  }
}

void main() {
  test(
      'actual adapter uses scoped published server pages and exact filtered ID lookup',
      () async {
    final db = _Firestore();
    final auth = _Auth();
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    final repository = FirebasePublishedRoutineRepository(
        scope: scope,
        firestore: db,
        auth: auth,
        pageSize: 2,
        activeScope: () => scope);
    final first = await repository.loadPage();
    expect(first.items.map((r) => r.id), ['a', 'b']);
    expect(first.nextCursor, 'b');
    final next = await repository.loadPage(afterId: first.nextCursor);
    expect(next.items.single.id, 'c');
    expect(next.nextCursor, isNull);
    expect(await repository.loadById('draft'), isNull);
    expect((await repository.loadById('b'))?.title, 'B');
    expect(db.reads.last.filters.keys, everyElement(isA<String>()));
    expect(db.reads.last.ordered, isTrue);
    expect(db.reads.last.from, 'b');
    for (final read in db.reads) {
      expect(read.path, 'orgs/org/content');
      expect(read.source, Source.server);
      expect(read.filters['status'], 'published');
      expect(read.filters['kind'], 'routine');
    }
    expect(db.reads.first.limit, 3);
    expect(db.reads.first.ordered, isTrue);
    expect(db.reads[1].after, 'b');
  });
  test('actual adapter rejects stale post-read account and organization state',
      () async {
    final db = _Firestore()..delay = Completer<void>();
    final auth = _Auth();
    final scope = SessionScope(userId: 'member', organizationId: 'org');
    SessionScope? active = scope;
    final repository = FirebasePublishedRoutineRepository(
        scope: scope, firestore: db, auth: auth, activeScope: () => active);
    final request = repository.loadPage();
    active = SessionScope(userId: 'member', organizationId: 'other');
    db.delay!.complete();
    await expectLater(request, throwsStateError);
    auth.signedIn = false;
    await expectLater(repository.loadById('a'), throwsStateError);
  });
}
