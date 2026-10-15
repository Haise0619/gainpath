// SDK interfaces are faked only at the Firestore boundary so production
// transaction callbacks can be tested offline without another repository.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_fitness_profile_gateway.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_member_preferences_repository.dart';

// A deterministic SDK boundary, not a second repository: transactions run the
// production callback, including one simulated retry against a changed record.
class _Firestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final writes = <Map<String, dynamic>>[];
  void Function()? beforeTransaction;
  void Function()? retryTransaction;
  Completer<void>? pendingRead;
  Object? transactionFailure;
  int clock = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    if (transactionFailure != null) throw transactionFailure!;
    beforeTransaction?.call();
    final first = _Transaction(this);
    var value = await handler(first);
    if (retryTransaction != null) {
      retryTransaction!();
      final retry = _Transaction(this);
      value = await handler(retry);
      retry.commit();
    } else {
      first.commit();
    }
    return value;
  }

  void write(String path, Map<String, dynamic> patch, {bool replace = false}) {
    writes.add({...patch});
    documents[path] = {
      if (!replace) ...?documents[path],
      ...patch,
      'updatedAt': Timestamp(++clock, 0),
    };
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(db, '${this.path}/$path');
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _Document(this.db, this.path);
  final _Firestore db;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(db, '${this.path}/$path');
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    expect(options?.source, Source.server);
    await db.pendingRead?.future;
    return _Snapshot(db.documents[path]);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async =>
      db.write(path, data, replace: true);
}

class _Snapshot<T> extends Fake implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  T? data() => value;
}

class _Transaction extends Fake implements Transaction {
  _Transaction(this.db);
  final _Firestore db;
  void Function()? _commit;
  void commit() => _commit?.call();
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
          DocumentReference<T> reference) async =>
      _Snapshot<T>(db.documents[reference.path] as T?);
  @override
  Transaction set<T>(DocumentReference<T> reference, T data,
      [SetOptions? options]) {
    _commit = () =>
        db.write(reference.path, data as Map<String, dynamic>, replace: true);
    return this;
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    _commit = () => db.write(reference.path, data.cast<String, dynamic>());
    return this;
  }
}

class _User extends Fake implements User {
  @override
  String get uid => 'member';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _User();
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  const profilePath = 'orgs/org/profiles/member';
  const preferencesPath = 'orgs/org/preferences/member';
  FitnessProfile profile() => FitnessProfile(
      gender: ProfileGender.unspecified,
      age: 25,
      heightCm: 165,
      weightKg: 65,
      experience: TrainingExperience.beginner,
      activity: ActivityLevel.lightlyActive,
      goals: {FitnessGoal.generalFitness});
  FirebaseFitnessProfileRepository repository(_Firestore db) =>
      FirebaseFitnessProfileRepository(
          scope: scope,
          gateway: FlutterFitnessProfileGateway(firestore: db, auth: _Auth()));
  FirebaseMemberPreferencesRepository preferences(_Firestore db) =>
      FirebaseMemberPreferencesRepository(
          scope: scope, firestore: db, auth: _Auth());

  test(
      'stale personal form cannot overwrite another session, even after a newer load',
      () async {
    final db = _Firestore();
    // Use two independent adapters against the same canonical document.
    final a = repository(db), b = repository(db);
    expect(await a.load(), isNull);
    await a.save(profile());
    final oldA = (await a.load())!, oldB = (await b.load())!;
    await a.save(oldA.copyWith(weightKg: 66));
    await b.load(); // This must not rebase oldB's original form provenance.
    final count = db.writes.length;
    await expectLater(b.save(oldB.copyWith(goals: {FitnessGoal.reduceStress})),
        throwsA(isA<FitnessProfileException>()));
    expect(db.writes.length, count);
    expect(db.documents[profilePath]!['weightKg'], 66);
    expect(db.documents[profilePath]!['goals'], ['generalFitness']);
  });

  test(
      'existing profile update sends only changed fields and preserves snapshot identity',
      () async {
    final db = _Firestore();
    final source = repository(db);
    await source.load();
    await source.save(profile());
    final original = (await source.load())!;
    await source.save(original.copyWith(weightKg: 66));
    expect(db.writes.last.keys, unorderedEquals(['weightKg', 'updatedAt']));
    expect(db.documents[profilePath]!['age'], 25);
  });

  test('missing profile creation rejects a concurrently created record',
      () async {
    final db = _Firestore();
    final first = repository(db), second = repository(db);
    await first.load();
    await second.load();
    await first.save(profile());
    await expectLater(second.save(profile().copyWith(weightKg: 66)),
        throwsA(isA<FitnessProfileException>()));
    expect(db.writes.length, 1);
  });

  test(
      'transaction retry compares the original profile snapshot without rebasing',
      () async {
    final db = _Firestore();
    final repo = repository(db);
    await repo.load();
    await repo.save(profile());
    final original = (await repo.load())!;
    db.retryTransaction = () => db.documents[profilePath] = {
          ...db.documents[profilePath]!,
          'age': 26,
          'updatedAt': Timestamp(99, 0)
        };
    final count = db.writes.length;
    await expectLater(repo.save(original.copyWith(weightKg: 66)),
        throwsA(isA<FitnessProfileException>()));
    expect(db.writes.length, count);
    expect(db.documents[profilePath]!['age'], 26);
  });

  test('stale preferences retain the other session choice after a later load',
      () async {
    final db = _Firestore();
    final a = preferences(db), b = preferences(db);
    final oldA = await a.load(), oldB = await b.load();
    await a.save(oldA.copyWith(pushNotifications: true));
    await b.load();
    await expectLater(b.save(oldB.copyWith(emailUpdates: true)),
        throwsA(isA<MemberPreferencesException>()));
    expect(db.documents[preferencesPath]!['pushNotifications'], isTrue);
    expect(db.documents[preferencesPath]!['emailUpdates'], isFalse);
  });

  test(
      'preference updates patch only intended fields and reject foreign provenance',
      () async {
    final db = _Firestore();
    final a = preferences(db), b = preferences(db);
    await a.save((await a.load()).copyWith(pushNotifications: true));
    final original = await a.load();
    await a.save(original.copyWith(emailUpdates: true));
    expect(db.writes.last.keys, unorderedEquals(['emailUpdates', 'updatedAt']));
    await expectLater(b.save(original.copyWith(voiceCoaching: true)),
        throwsA(isA<MemberPreferencesException>()));
    expect(db.documents[preferencesPath]!['voiceCoaching'], isFalse);
  });

  test('scope invalidation during a server read suppresses private results',
      () async {
    final db = _Firestore()..pendingRead = Completer<void>();
    var current = true;
    final profileRepository = FirebaseFitnessProfileRepository(
        scope: scope,
        gateway: FlutterFitnessProfileGateway(
            firestore: db, auth: _Auth(), isSessionCurrent: () => current));
    final preferenceRepository = FirebaseMemberPreferencesRepository(
        scope: scope,
        firestore: db,
        auth: _Auth(),
        isSessionCurrent: () => current);
    final profileRead = profileRepository.load();
    final preferenceRead = preferenceRepository.load();
    final profileFailure =
        expectLater(profileRead, throwsA(isA<FitnessProfileException>()));
    final preferencesFailure =
        expectLater(preferenceRead, throwsA(isA<MemberPreferencesException>()));
    current = false;
    db.pendingRead!.complete();
    await Future.wait([profileFailure, preferencesFailure]);
  });

  test(
      'scope invalidation before a transaction callback prevents every private write',
      () async {
    final db = _Firestore();
    var current = true;
    final a = FirebaseFitnessProfileRepository(
        scope: scope,
        gateway: FlutterFitnessProfileGateway(
            firestore: db, auth: _Auth(), isSessionCurrent: () => current));
    final b = FirebaseMemberPreferencesRepository(
        scope: scope,
        firestore: db,
        auth: _Auth(),
        isSessionCurrent: () => current);
    await a.load();
    final choices = await b.load();
    db.beforeTransaction = () => current = false;
    await expectLater(
        a.save(profile()), throwsA(isA<FitnessProfileException>()));
    current = true;
    await expectLater(b.save(choices.copyWith(emailUpdates: true)),
        throwsA(isA<MemberPreferencesException>()));
    expect(db.writes, isEmpty);
  });

  test('in-place snapshot list mutation cannot change a captured form baseline',
      () async {
    final db = _Firestore();
    final source = repository(db);
    await source.load();
    await source.save(profile());
    // Replace the stored goals with a mutable transport list before loading.
    db.documents[profilePath]!['goals'] = <String>['generalFitness'];
    final original = (await source.load())!;
    (db.documents[profilePath]!['goals'] as List<String>)[0] = 'reduceStress';
    await expectLater(source.save(original.copyWith(weightKg: 66)),
        throwsA(isA<FitnessProfileException>()));
    expect(db.documents[profilePath]!['weightKg'], 65);
  });

  test('preferences transaction retries reject the original stale snapshot',
      () async {
    final db = _Firestore();
    final repo = preferences(db);
    await repo.save((await repo.load()).copyWith(emailUpdates: true));
    final original = await repo.load();
    db.retryTransaction = () => db.documents[preferencesPath] = {
          ...db.documents[preferencesPath]!,
          'voiceCoaching': true,
          'updatedAt': Timestamp(99, 0)
        };
    final count = db.writes.length;
    await expectLater(repo.save(original.copyWith(pushNotifications: true)),
        throwsA(isA<MemberPreferencesException>()));
    expect(db.writes.length, count);
    expect(db.documents[preferencesPath]!['voiceCoaching'], isTrue);
  });

  test('unconfirmed profile transaction requires a reload before retry',
      () async {
    final db = _Firestore();
    final repo = repository(db);
    await repo.load();
    db.transactionFailure =
        FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded');
    await expectLater(
        repo.save(profile()),
        throwsA(isA<FitnessProfileException>().having(
            (error) => error.reloadRequired, 'requires reload', isTrue)));
    expect(db.writes, isEmpty);
  });

  test('unconfirmed preferences transaction requires a reload before retry',
      () async {
    final db = _Firestore();
    final repo = preferences(db);
    final original = await repo.load();
    db.transactionFailure =
        FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded');
    await expectLater(
        repo.save(original.copyWith(emailUpdates: true)),
        throwsA(isA<MemberPreferencesException>().having(
            (error) => error.reloadRequired, 'requires reload', isTrue)));
    expect(db.writes, isEmpty);
  });
}
