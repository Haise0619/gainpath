// SDK boundary only: production transaction callbacks run unchanged.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_member_photo_gateway.dart';

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
          patch.keys, unorderedEquals(['memberPhotoPath', 'updatedAtMillis']));
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
  late FlutterMemberPhotoGateway gateway;
  var current = true;
  setUp(() {
    db = _Db();
    auth = _Auth();
    current = true;
    gateway = FlutterMemberPhotoGateway(
        scope: SessionScope(userId: 'm', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: auth);
  });
  test('transaction updates only own photo and timestamp', () async {
    final original = await gateway.read();
    await gateway.write(original, 'owned-path');
    expect(db.docs['users/m']!['memberPhotoPath'], 'owned-path');
    expect(db.docs['users/m']!['displayName'], 'Original');
    expect(db.writes, 1);
  });
  test(
      'stale first transaction abort remains sticky when retry sees original again',
      () async {
    final original = await gateway.read();
    db.beforeTransaction =
        () => db.docs['users/m']!['displayName'] = 'Concurrent';
    db.retryAfterFailure = true;
    await expectLater(gateway.write(original, 'new-photo'),
        throwsA(isA<MemberPhotoException>()));
    expect(db.writes, 0);
  });
  test('membership change aborts the transaction and invalidates future reads',
      () async {
    final original = await gateway.read();
    db.beforeTransaction =
        () => db.docs['orgs/o/members/m']!['status'] = 'suspended';
    await expectLater(gateway.write(original, 'new-photo'),
        throwsA(isA<MemberPhotoException>()));
    db.docs['orgs/o/members/m']!['status'] = 'active';
    await expectLater(gateway.read(), throwsA(isA<MemberPhotoException>()));
    expect(db.writes, 0);
  });
  test('session loss during read and Auth email drift reject stale results',
      () async {
    db.afterRead = () => current = false;
    await expectLater(gateway.read(), throwsA(isA<MemberPhotoException>()));
    current = true;
    await expectLater(gateway.read(), throwsA(isA<MemberPhotoException>()));
    db.afterRead = null;
    final fresh = FlutterMemberPhotoGateway(
        scope: SessionScope(userId: 'm', organizationId: 'o'),
        isCurrent: () => true,
        firestore: db,
        auth: auth);
    final original = await fresh.read();
    auth.email = 'changed@example.test';
    await expectLater(fresh.write(original, 'new-photo'),
        throwsA(isA<MemberPhotoException>()));
    expect(db.writes, 0);
  });
}
