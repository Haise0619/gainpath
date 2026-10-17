// Fake only the SDK boundary; production transaction callbacks run unchanged.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_numeric_fitness_goal_gateway.dart';

class _Db extends Fake implements FirebaseFirestore {
  final docs = <String, Map<String, dynamic>>{};
  final serverTime = Timestamp.fromDate(DateTime.utc(2026, 10, 17));
  int writes = 0;
  int reads = 0;
  int? queryLimit;
  String? queryPath;
  String? queryField;
  Object? queryValue;
  Source? source;
  void Function()? afterRead;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    final transaction = _Tx(this);
    final result = await handler(transaction);
    for (final write in transaction.pending.entries) {
      docs[write.key] = {
        for (final field in write.value.entries)
          field.key: field.value is FieldValue ? serverTime : field.value
      };
      writes++;
    }
    return result;
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Db db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Ref(db, '${this.path}/${path ?? 'allocatedGoal'}');
  @override
  Query<Map<String, dynamic>> where(Object field,
      {Object? isEqualTo,
      Object? isNotEqualTo,
      Object? isLessThan,
      Object? isLessThanOrEqualTo,
      Object? isGreaterThan,
      Object? isGreaterThanOrEqualTo,
      Object? arrayContains,
      Iterable<Object?>? arrayContainsAny,
      Iterable<Object?>? whereIn,
      Iterable<Object?>? whereNotIn,
      bool? isNull}) {
    db.queryField = '$field';
    db.queryValue = isEqualTo;
    db.queryPath = path;
    return _Query(db, path);
  }
}

class _Query extends Fake implements Query<Map<String, dynamic>> {
  _Query(this.db, this.path);
  final _Db db;
  final String path;
  @override
  Query<Map<String, dynamic>> limit(int limit) {
    db.queryLimit = limit;
    return this;
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    db.source = options?.source;
    final entries = db.docs.entries
        .where((entry) =>
            entry.key.startsWith('$path/') &&
            entry.key.substring(path.length + 1).split('/').length == 1 &&
            entry.value[db.queryField] == db.queryValue)
        .take(db.queryLimit!);
    return _QuerySnapshot(entries
        .map((entry) => _QueryDoc(entry.key.split('/').last, entry.value))
        .toList());
  }
}

class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.db, this.path);
  final _Db db;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(db, '${this.path}/$path');
}

class _Tx extends Fake implements Transaction {
  _Tx(this.db);
  final _Db db;
  final pending = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
      DocumentReference<T> ref) async {
    db.reads++;
    final data = db.docs[ref.path];
    db.afterRead?.call();
    return _Snapshot(data == null ? null : {...data}) as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    pending[ref.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
}

class _QueryDoc extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDoc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Auth extends Fake implements FirebaseAuth {
  User? user = _User('member', true);
  @override
  User? get currentUser => user;
}

class _User extends Fake implements User {
  _User(this.uid, this.emailVerified);
  @override
  final String uid;
  @override
  final bool emailVerified;
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  const path = 'orgs/org/profiles/member/goals/goal';
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'category': 'trainingFrequency',
    'targetValue': 4,
    'unit': 'sessions',
    'evaluationPeriod': 'calendarWeek',
    'status': 'active'
  };
  late _Db db;
  late _Auth auth;
  late FlutterNumericFitnessGoalGateway gateway;
  var current = true;
  setUp(() {
    db = _Db();
    auth = _Auth();
    current = true;
    gateway = FlutterNumericFitnessGoalGateway(
        firestore: db, auth: auth, isSessionCurrent: () => current);
  });
  test(
      'production transaction atomically versions create, edit, archive and idempotent create',
      () async {
    await gateway.commit(scope, 'goal', payload, expectedRevision: null);
    expect(db.writes, 2);
    expect(db.docs[path], db.docs['$path/revisions/1']);
    expect(db.docs[path]!['targetValue'], isA<int>());
    expect(db.docs[path]!['createdAt'], db.serverTime);
    await gateway.commit(scope, 'goal', payload, expectedRevision: null);
    expect(db.writes, 2);
    await gateway.commit(scope, 'goal', {'targetValue': 5},
        expectedRevision: 1);
    expect(db.docs[path]!['revision'], 2);
    expect(db.docs[path]!['targetValue'], isA<int>());
    expect(db.docs['$path/revisions/1']!['targetValue'], 4.0);
    expect(db.docs['$path/revisions/2']!['targetValue'], 5.0);
    expect(db.docs[path]!['createdAt'], db.serverTime);
    await gateway.commit(scope, 'goal', {'status': 'archived'},
        expectedRevision: 2);
    expect(db.docs[path]!['status'], 'archived');
    expect(db.docs[path], db.docs['$path/revisions/3']);
  });
  test(
      'read is owner-scoped, bounded active-only and server authoritative with UTC timestamps',
      () async {
    await gateway.commit(scope, 'goal', payload, expectedRevision: null);
    final result = await gateway.readActive(scope, limit: 21);
    expect(db.queryPath, 'orgs/org/profiles/member/goals');
    expect(db.queryField, 'status');
    expect(db.queryValue, 'active');
    expect(db.queryLimit, 21);
    expect(db.source, Source.server);
    expect(result['goal']!['createdAt'], db.serverTime.toDate().toUtc());
    expect(result, hasLength(1));
  });
  test(
      'stale edits and changed create retry payload cannot replace history or current target',
      () async {
    await gateway.commit(scope, 'goal', payload, expectedRevision: null);
    await gateway.commit(scope, 'goal', {'targetValue': 5},
        expectedRevision: 1);
    await expectLater(
        gateway.commit(scope, 'goal', {'targetValue': 6.0},
            expectedRevision: 1),
        throwsA(isA<NumericGoalException>()));
    await expectLater(
        gateway.commit(scope, 'goal', payload, expectedRevision: null),
        throwsA(isA<NumericGoalException>()));
    expect(db.writes, 4);
    expect(db.docs[path]!['targetValue'], 5.0);
  });
  test(
      'logout, unverified/wrong user and session changes during transaction prevent writes',
      () async {
    for (final user in <User?>[
      null,
      _User('other', true),
      _User('member', false)
    ]) {
      auth.user = user;
      await expectLater(
          gateway.commit(scope, 'goal', payload, expectedRevision: null),
          throwsA(isA<NumericGoalException>()));
    }
    expect(db.reads, 0);
    auth.user = _User('member', true);
    db.afterRead = () => current = false;
    await expectLater(
        gateway.commit(scope, 'goal', payload, expectedRevision: null),
        throwsA(isA<NumericGoalException>()));
    expect(db.reads, 1);
    expect(db.writes, 0);
    expect(db.docs, isEmpty);
  });
}
