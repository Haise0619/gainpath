// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/content/presentation/admin/system_settings_screen.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_facility_settings_repository.dart';

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'admin';
  @override
  bool get emailVerified => true;
}

class _Db extends Fake implements FirebaseFirestore {
  final records = <String, Map<String, dynamic>>{
    'users/admin': {'organizationId': 'o'},
    'orgs/o/members/admin': {
      'organizationId': 'o',
      'role': 'admin',
      'status': 'active'
    },
  };
  Map<String, dynamic>? patch;
  void Function()? retry;
  void Function()? afterRead;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(TransactionHandler<T> handler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    var tx = _Tx(this);
    var result = await handler(tx);
    if (retry != null) {
      retry!();
      tx = _Tx(this);
      result = await handler(tx);
    }
    for (final e in tx.writes.entries) {
      patch = e.value;
      final fields = e.value
          .map((k, v) => MapEntry(k, v is FieldValue ? Timestamp.now() : v));
      records[e.key] = {...?records[e.key], ...fields};
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
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Ref(db, '$path/${id ?? 'created'}');
  @override
  Query<Map<String, dynamic>> orderBy(Object field,
          {bool descending = false}) =>
      this;
  @override
  Query<Map<String, dynamic>> limit(int n) => this;
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    expect(options?.source, Source.server);
    return _Page(db.records.entries
        .where((e) => e.key.startsWith('$path/'))
        .map((e) => _Snap(e.key.split('/').last, Map.of(e.value)))
        .toList());
  }
}

class _Page extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Page(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Snap extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Snap(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic> data() => value!;
}

class _Missing extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists => false;
  @override
  Map<String, dynamic>? data() => null;
}

class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.db, this.path);
  final _Db db;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      _Collection(db, '$path/$name');
  @override
  String get id => path.split('/').last;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    expect(options?.source, Source.server);
    final d = db.records[path];
    final DocumentSnapshot<Map<String, dynamic>> result =
        d == null ? _Missing() : _Snap(id, Map.of(d));
    db.afterRead?.call();
    return result;
  }
}

class _Tx extends Fake implements Transaction {
  _Tx(this.db);
  final _Db db;
  final writes = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
      DocumentReference<T> reference) async {
    final d = db.records[reference.path];
    return (d == null ? _Missing() : _Snap(reference.id, Map.of(d)))
        as DocumentSnapshot<T>;
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    writes[reference.path] = Map<String, dynamic>.from(data);
    return this;
  }

  @override
  Transaction set<T>(DocumentReference<T> reference, T data,
      [SetOptions? options]) {
    writes[reference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

class _Compliance extends Fake implements ComplianceDocumentRepository {
  @override
  Future<ComplianceDocumentSnapshot> load() async =>
      throw StateError('Not part of this test');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _Db db;
  late FirebaseFacilitySettingsRepository repo;
  var current = true;
  setUp(() {
    db = _Db();
    db.records['orgs/o'] = {
      'schemaVersion': 1,
      'organizationId': 'o',
      'displayName': 'Existing facility',
      'status': 'active',
      'createdAtMillis': 1,
      'updatedAtMillis': 1,
      'timezone': 'protected-policy',
      'customField': 'preserve'
    };
    current = true;
    repo = FirebaseFacilitySettingsRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth());
  });
  test(
      'saves and reloads only facility name while preserving operational fields',
      () async {
    final original = await repo.load();
    final saved = await repo.save(original, displayName: ' New facility name ');
    expect(saved.displayName, 'New facility name');
    expect((await repo.load()).displayName, 'New facility name');
    expect(db.patch!.keys.toSet(), {'displayName', 'updatedAtMillis'});
    expect(db.records['orgs/o']!['timezone'], 'protected-policy');
    expect(db.records['orgs/o']!['customField'], 'preserve');
  });
  test('stale facility edits cannot overwrite changes from another editor',
      () async {
    final original = await repo.load();
    db.records['orgs/o']!['displayName'] = 'Other editor';
    await expectLater(repo.save(original, displayName: 'Stale'),
        throwsA(isA<FacilitySettingsConflict>()));
    expect(db.records['orgs/o']!['displayName'], 'Other editor');
  });
  test('rejects changed canonical organization, roles and session', () async {
    final original = await repo.load();
    db.records['orgs/o/members/admin']!['role'] = 'staff';
    await expectLater(repo.save(original, displayName: 'Blocked'),
        throwsA(isA<FacilitySettingsSessionChanged>()));
    db.records['orgs/o/members/admin']!['role'] = 'admin';
    await expectLater(
        repo.load(), throwsA(isA<FacilitySettingsSessionChanged>()));
  });
  test('rejects another repository baseline and invalid facility names',
      () async {
    final original = await repo.load();
    final other = FirebaseFacilitySettingsRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => true,
        firestore: db,
        auth: _Auth());
    await expectLater(other.save(original, displayName: 'Other'),
        throwsA(isA<FacilitySettingsConflict>()));
    for (final name in [' ', 'line\nbreak', List.filled(121, 'x').join()]) {
      await expectLater(
          repo.save(original, displayName: name), throwsFormatException);
    }
    current = false;
    await expectLater(repo.save(original, displayName: 'Blocked'),
        throwsA(isA<FacilitySettingsSessionChanged>()));
  });
  test('transaction retry does not rebase stale operational changes', () async {
    final original = await repo.load();
    db.retry = () => db.records['orgs/o']!['customField'] = 'changed elsewhere';
    await expectLater(repo.save(original, displayName: 'Changed'),
        throwsA(isA<FacilitySettingsConflict>()));
    expect(db.records['orgs/o']!['displayName'], 'Existing facility');
  });
  testWidgets(
      'General settings saves and reloads the real port without operational controls',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FacilitySettingsRepository>.value(value: repo),
          RepositoryProvider<ComplianceDocumentRepository>.value(
              value: _Compliance()),
        ],
        child: MaterialApp(
            theme: AppTheme.build(),
            home: const SystemSettingsScreen(live: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Existing facility');
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Changed facility');
    await tester.tap(find.text('Save facility name'));
    await tester.pumpAndSettle();
    expect(find.text('Facility name saved.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Unsaved change');
    await tester.tap(find.text('Reload facility name'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Changed facility');
    expect(db.records['orgs/o']!['timezone'], 'protected-policy');
  });
  testWidgets('Mock Mode retains the full General preferences prototype',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(), home: const SystemSettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Deploy changes'), findsOneWidget);
  });
}
