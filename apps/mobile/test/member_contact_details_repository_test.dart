// SDK boundary only: production transaction callbacks run unchanged.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_member_contact_details_repository.dart';

class _Db extends Fake implements FirebaseFirestore {
  final docs = <String, Map<String, dynamic>>{
    'users/m': {
      'organizationId': 'o',
      'displayName': 'Original',
      'memberPhotoPath': ''
    },
    'orgs/o/members/m': {
      'organizationId': 'o',
      'role': 'member',
      'status': 'active'
    },
  };
  void Function()? beforeTransaction;
  void Function()? afterRead;
  bool retryAfterFailure = false;
  int writes = 0;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => _Ref(this, path);
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    beforeTransaction?.call();
    try {
      final tx = _Tx(this);
      final result = await handler(tx);
      tx.commit?.call();
      return result;
    } catch (_) {
      if (!retryAfterFailure) rethrow;
      docs['users/m']!['displayName'] = 'Original';
      final tx = _Tx(this);
      final result = await handler(tx);
      tx.commit?.call();
      return result;
    }
  }
}

class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.db, this.path);
  final _Db db;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    expect(options?.source, Source.server);
    db.afterRead?.call();
    return _Snapshot(db.docs[path]);
  }
}

class _Snapshot<T> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  T? data() => value;
}

class _Tx extends Fake implements Transaction {
  _Tx(this.db);
  final _Db db;
  void Function()? commit;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
          DocumentReference<T> ref) async =>
      _Snapshot<T>(db.docs[ref.path] as T?);
  @override
  Transaction update(DocumentReference ref, Map<Object, Object?> patch) {
    commit = () {
      expect(
          patch.keys, unorderedEquals(['contactDetails', 'updatedAtMillis']));
      db.docs[ref.path]!.addAll(patch.cast<String, dynamic>());
      db.writes++;
    };
    return this;
  }
}

class _Auth extends Fake implements FirebaseAuth {
  String email = 'member@example.test';
  @override
  User get currentUser => _User(email);
}

class _User extends Fake implements User {
  _User(this.email);
  @override
  String get uid => 'm';
  @override
  final String email;
  @override
  bool get emailVerified => true;
}

void main() {
  late _Db db;
  late _Auth auth;
  late FirebaseMemberContactDetailsRepository repo;
  var current = true;
  setUp(() {
    db = _Db();
    auth = _Auth();
    current = true;
    repo = FirebaseMemberContactDetailsRepository(
        scope: SessionScope(userId: 'm', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: auth);
  });
  test(
      'optional contact details save, reopen, replace and clear without touching photo or other fields',
      () async {
    db.docs['users/m']!['memberPhotoPath'] = 'existing-private-photo';
    final initial = await repo.load();
    expect(initial.value, isEmpty);
    final saved = await repo.save(initial, '  +60 12 345 6789  ');
    expect(saved.value, '+60 12 345 6789');
    expect((await repo.load()).value, '+60 12 345 6789');
    final replaced = await repo.save(saved, 'Alternative contact');
    expect(replaced.value, 'Alternative contact');
    final cleared = await repo.save(replaced, '');
    expect(cleared.value, isEmpty);
    expect(db.docs['users/m']!['displayName'], 'Original');
    expect(db.docs['users/m']!['memberPhotoPath'], 'existing-private-photo');
    expect(db.docs['orgs/o/members/m']!['role'], 'member');
  });
  test(
      'stale baseline rejects write and remains aborted if transaction retries against original',
      () async {
    final original = await repo.load();
    db.beforeTransaction =
        () => db.docs['users/m']!['displayName'] = 'Concurrent';
    db.retryAfterFailure = true;
    await expectLater(repo.save(original, 'new'),
        throwsA(isA<MemberContactDetailsException>()));
    expect(db.writes, 0);
  });
  test(
      'foreign repository baseline, oversized text and control characters never write',
      () async {
    final other = FirebaseMemberContactDetailsRepository(
        scope: repo.scope, isCurrent: () => true, firestore: db, auth: auth);
    await expectLater(repo.save(await other.load(), 'new'),
        throwsA(isA<MemberContactDetailsException>()));
    final original = await repo.load();
    for (final value in ['x' * 201, 'line\nbreak', 'bad\u0000value']) {
      await expectLater(repo.save(original, value),
          throwsA(isA<MemberContactDetailsException>()));
    }
    expect(db.writes, 0);
    expect((await repo.save(original, 'x' * 200)).value.length, 200);
  });
  test(
      'session loss during load stays invalid; email and membership drift prevent writes',
      () async {
    db.afterRead = () => current = false;
    await expectLater(
        repo.load(), throwsA(isA<MemberContactDetailsException>()));
    current = true;
    db.afterRead = null;
    await expectLater(
        repo.load(), throwsA(isA<MemberContactDetailsException>()));
    final fresh = FirebaseMemberContactDetailsRepository(
        scope: repo.scope, isCurrent: () => true, firestore: db, auth: auth);
    final original = await fresh.load();
    auth.email = 'changed@example.test';
    await expectLater(fresh.save(original, 'new'),
        throwsA(isA<MemberContactDetailsException>()));
    auth.email = 'member@example.test';
    db.beforeTransaction = () => db.docs['orgs/o/members/m']!['role'] = 'coach';
    final another = FirebaseMemberContactDetailsRepository(
        scope: repo.scope, isCurrent: () => true, firestore: db, auth: auth);
    final baseline = await another.load();
    await expectLater(another.save(baseline, 'new'),
        throwsA(isA<MemberContactDetailsException>()));
    expect(db.writes, 0);
  });
  test('wrong role, inactive and mismatched organization deny reads', () async {
    for (final patch in [
      {'role': 'admin'},
      {'role': 'member', 'status': 'suspended'},
      {'status': 'active', 'organizationId': 'other'}
    ]) {
      db.docs['orgs/o/members/m']!.addAll(patch);
      final candidate = FirebaseMemberContactDetailsRepository(
          scope: repo.scope, isCurrent: () => true, firestore: db, auth: auth);
      await expectLater(
          candidate.load(), throwsA(isA<MemberContactDetailsException>()));
    }
  });
}
