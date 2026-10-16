// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/gamification/presentation/admin/reward_catalog_screen.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_reward_catalog_repository.dart';

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

class _MockRewards extends Fake implements GamificationRepository {
  @override
  List<RewardItem> get rewards => [];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _Db db;
  late FirebaseRewardCatalogRepository repo;
  var current = true;
  setUp(() {
    db = _Db();
    current = true;
    repo = FirebaseRewardCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth());
  });
  test(
      'creates metadata draft, edits, archives and reloads with stable identity',
      () async {
    final created =
        await repo.save(repo.beginCreate().copyWith(title: 'Draft towel'));
    expect(created.revision, 1);
    expect(created.isArchived, false);
    final loaded = (await repo.loadPage()).items.single;
    final changed =
        await repo.save(loaded.copyWith(description: 'Cotton towel'));
    expect(changed.id, created.id);
    expect(changed.revision, 2);
    final archived = await repo.save(changed.copyWith(isArchived: true));
    expect((await repo.loadPage()).items.single.isArchived, true);
    expect(archived.revision, 3);
    expect(
        db.records.keys.where((p) => p.contains('/rewardCatalog/')).length, 1);
    expect(db.patch!.keys,
        containsAll(['title', 'description', 'status', 'revision']));
    expect(db.patch!.containsKey('points'), false);
    expect(db.patch!.containsKey('stock'), false);
  });
  test('stale edits cannot overwrite newer metadata', () async {
    final created =
        await repo.save(repo.beginCreate().copyWith(title: 'Draft towel'));
    await repo.save(created.copyWith(title: 'New title'));
    await expectLater(repo.save(created.copyWith(title: 'Stale title')),
        throwsA(isA<RewardCatalogConflict>()));
    expect((await repo.loadPage()).items.single.title, 'New title');
  });
  test('retry does not rebase a stale edit and cannot duplicate a creation',
      () async {
    final fresh = repo.beginCreate().copyWith(title: 'Draft towel');
    final first = await repo.save(fresh);
    await expectLater(repo.save(fresh), throwsA(isA<RewardCatalogConflict>()));
    db.retry =
        () => db.records['orgs/o/rewardCatalog/${first.id}']!['revision'] = 7;
    await expectLater(repo.save(first.copyWith(title: 'Changed')),
        throwsA(isA<RewardCatalogConflict>()));
  });
  test('rejects wrong roles, organization and expired sessions', () async {
    db.records['orgs/o/members/admin']!['role'] = 'staff';
    await expectLater(
        repo.loadPage(), throwsA(isA<RewardCatalogSessionChanged>()));
    db.records['orgs/o/members/admin']!['role'] = 'admin';
    await expectLater(
        repo.loadPage(), throwsA(isA<RewardCatalogSessionChanged>()));
  });
  test('rejects another repository baseline and invalid metadata', () async {
    final draft = repo.beginCreate().copyWith(title: 'Draft');
    final other = FirebaseRewardCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => true,
        firestore: db,
        auth: _Auth());
    await expectLater(other.save(draft), throwsA(isA<RewardCatalogConflict>()));
    await expectLater(
        repo.save(draft.copyWith(imageUrl: 'http://example.test/image.png')),
        throwsFormatException);
    current = false;
    await expectLater(
        repo.save(draft), throwsA(isA<RewardCatalogSessionChanged>()));
  });
  testWidgets(
      'existing editor saves, reloads and archives metadata without operational fields',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepositoryProvider<RewardCatalogRepository>.value(
        value: repo,
        child: MaterialApp(
            theme: AppTheme.build(),
            home: const RewardCatalogScreen(live: true))));
    await tester.pumpAndSettle();
    expect(find.text('No reward drafts yet. Add a draft to get started.'),
        findsOneWidget);
    await tester.tap(find.text('Add draft'));
    await tester.pumpAndSettle();
    expect(find.text('Points cost'), findsNothing);
    expect(find.text('Stock'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'Fixture draft');
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Fixture draft'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Fixture draft'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Edited description');
    await tester.tap(find.text('Archive draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsOneWidget);
    final persisted = (await repo.loadPage()).items.single;
    expect(persisted.description, 'Edited description');
    expect(persisted.revision, 2);
    expect(persisted.isArchived, true);
  });
  testWidgets('Mock Mode retains its complete reward editor', (tester) async {
    tester.view.physicalSize = const Size(1500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepositoryProvider<GamificationRepository>.value(
        value: _MockRewards(),
        child: MaterialApp(
            theme: AppTheme.build(), home: const RewardCatalogScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    expect(find.text('Points cost'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Redemption limit / member (optional)'), findsOneWidget);
  });
}
