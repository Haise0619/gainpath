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
import 'package:gainpath_domain/workout.dart' show EquipmentImage;
import 'dart:typed_data';
import 'dart:convert';
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

class _DraftOnly implements RewardCatalogRepository {
  _DraftOnly(this.source);
  final RewardCatalogRepository source;
  @override
  RewardCatalogDraft beginCreate() => source.beginCreate();
  @override
  Future<RewardCatalogPage> loadPage({String? afterId}) =>
      source.loadPage(afterId: afterId);
  @override
  Future<RewardCatalogDraft> save(RewardCatalogDraft draft) =>
      source.save(draft);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _Db db;
  late FirebaseRewardCatalogRepository repo;
  late List<Map<String, dynamic>> calls;
  late Map<String, dynamic> response;
  var current = true;
  setUp(() {
    db = _Db();
    calls = [];
    response = {'schemaVersion': 1, 'organizationId': 'o', 'items': []};
    current = true;
    repo = FirebaseRewardCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth(),
        catalogCall: (name, input) async {
          expect(name, 'rewardCatalogCommand');
          calls.add(input);
          return response;
        });
  });
  test('workout draft commands preserve disabled hold and exact save fields',
      () async {
    const draft = WorkoutRewardDraft(revision: 3, version: 'v3');
    response.addAll({
      'hold': true,
      'draft': {
        'schemaVersion': 1,
        'revision': 3,
        'version': 'v3',
        ...draft.toFields(),
        'enabled': false,
        'difficultyMultipliersEnabled': false,
        'eligibilityMode': 'verified_ai_only',
        'timezone': 'Asia/Kuala_Lumpur'
      }
    });
    expect((await repo.loadWorkoutRewardDraft()).revision, 3);
    expect(calls.single, {
      'schemaVersion': 1,
      'organizationId': 'o',
      'action': 'workoutRewardOverview'
    });
    response['confirmed'] = true;
    await repo.saveWorkoutRewardDraft(
        requestId: 'stable', baseRevision: 3, draft: draft);
    expect(calls.last, {
      'schemaVersion': 1,
      'organizationId': 'o',
      'action': 'saveWorkoutRewardDraft',
      'requestId': 'stable',
      'baseRevision': 3,
      ...draft.toFields()
    });
    expect(calls.last.containsKey('enabled'), false);
    expect(calls.last.containsKey('difficultyMultipliersEnabled'), false);
    response['hold'] = false;
    await expectLater(repo.loadWorkoutRewardDraft(), throwsFormatException);
    current = false;
    await expectLater(
        repo.saveWorkoutRewardDraft(
            requestId: 'stable', baseRevision: 3, draft: draft),
        throwsA(isA<RewardCatalogSessionChanged>()));
  });
  test(
      'cover bytes go through the trusted scoped callable rather than Storage client Rules',
      () async {
    response = {
      'schemaVersion': 1,
      'organizationId': 'o',
      'url': 'https://media.example.test/cover'
    };
    final bytes = Uint8List.fromList([255, 216, 255, 0]);
    expect(await repo.uploadRewardCover(EquipmentImage(bytes)),
        'https://media.example.test/cover');
    expect(calls.single.keys.toSet(), {
      'schemaVersion',
      'organizationId',
      'action',
      'uploadId',
      'contentType',
      'dataBase64'
    });
    expect(calls.single['action'], 'uploadCover');
    expect(calls.single['uploadId'], matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(calls.single['dataBase64'], base64Encode(bytes));
    expect(calls.single['contentType'], 'image/jpeg');
  });
  test('points overview parses rewards without monetary fields or policy',
      () async {
    response['items'] = [
      {
        'itemId': 'towel',
        'title': 'Towel',
        'pointCost': 50,
        'stock': 2,
        'revision': 1,
        'active': true,
        'validityDays': 30,
        'conditions': 'In person',
        'collectionInstructions': 'Reception',
        'imageUrl': '',
        'description': 'Cotton'
      }
    ];
    final shop = await repo.shopOverview();
    expect(calls.single, {
      'schemaVersion': 1,
      'organizationId': 'o',
      'action': 'pointsOverview'
    });
    expect(shop.policy, null);
    expect(shop.items.single.pointCost, 50);
    expect(shop.items.single.valueMinor, 0);
    expect(shop.items.single.category, 'Merchandise');
    response['organizationId'] = 'foreign';
    await expectLater(repo.shopOverview(), throwsFormatException);
  });
  test('publication commands use exact saved revision and scoped protocol',
      () async {
    await repo.configureShop(
        requestId: 'stable-config',
        pointsPerUnit: 50,
        unitValueMinor: 100,
        enabled: true);
    expect(calls.single, {
      'schemaVersion': 1,
      'organizationId': 'o',
      'action': 'configure',
      'requestId': 'stable-config',
      'pointsPerUnit': 50,
      'unitValueMinor': 100,
      'enabled': true
    });
    final fresh = repo.beginCreate().copyWith(title: 'Real draft');
    await expectLater(
        repo.publishReward(
            draft: fresh,
            requestId: 'pub',
            pointCost: 50,
            valueMinor: 100,
            stockToAdd: 2,
            validityDays: 30,
            conditions: 'Terms',
            collectionInstructions: 'Reception'),
        throwsA(isA<RewardCatalogConflict>()));
    expect(calls.length, 1);
    final saved = await repo.save(fresh);
    await repo.publishReward(
        draft: saved,
        requestId: 'pub',
        pointCost: 50,
        valueMinor: 100,
        stockToAdd: 2,
        validityDays: 30,
        conditions: 'Terms',
        collectionInstructions: 'Reception',
        baseItemRevision: 3);
    expect(calls.last, {
      'schemaVersion': 1,
      'organizationId': 'o',
      'action': 'publish',
      'requestId': 'pub',
      'itemId': saved.id,
      'draftRevision': 1,
      'baseItemRevision': 3,
      'pointCost': 50,
      'valueMinor': 100,
      'stockToAdd': 2,
      'validityDays': 30,
      'conditions': 'Terms',
      'collectionInstructions': 'Reception'
    });
    await repo.retireReward(
        itemId: saved.id, requestId: 'retire', baseItemRevision: 4);
    expect(calls.last, {
      'schemaVersion': 1,
      'organizationId': 'o',
      'action': 'retirePoints',
      'requestId': 'retire',
      'itemId': saved.id,
      'baseItemRevision': 4
    });
    current = false;
    await expectLater(
        repo.shopOverview(), throwsA(isA<RewardCatalogSessionChanged>()));
    expect(calls.length, 3);
  });
  test(
      'direct save allocates without writing metadata and sends exact scoped fields',
      () async {
    final before = db.records.length;
    final id = repo.newItemId();
    expect(db.records.length, before);
    expect(calls, isEmpty);
    await repo.saveReward(
        requestId: 'stable',
        itemId: id,
        baseItemRevision: 0,
        title: ' Towel ',
        description: ' Cotton ',
        category: 'Apparel',
        imageUrl: 'https://example.test/towel.png',
        pointCost: 50,
        stockToAdd: 2,
        validityDays: 30,
        conditions: ' In person ',
        collectionInstructions: ' Reception ');
    expect(calls.single, {
      'schemaVersion': 1,
      'organizationId': 'o',
      'action': 'savePoints',
      'requestId': 'stable',
      'itemId': id,
      'baseItemRevision': 0,
      'title': 'Towel',
      'description': 'Cotton',
      'category': 'Apparel',
      'imageUrl': 'https://example.test/towel.png',
      'pointCost': 50,
      'stockToAdd': 2,
      'validityDays': 30,
      'conditions': 'In person',
      'collectionInstructions': 'Reception'
    });
    expect(db.records.length, before);
    current = false;
    expect(() => repo.newItemId(), throwsA(isA<RewardCatalogSessionChanged>()));
    await expectLater(
        repo.saveReward(
            requestId: 'stable',
            itemId: id,
            baseItemRevision: 0,
            title: 'Towel',
            description: '',
            category: 'Apparel',
            imageUrl: '',
            pointCost: 50,
            stockToAdd: 2,
            validityDays: 30,
            conditions: 'Terms',
            collectionInstructions: 'Reception'),
        throwsA(isA<RewardCatalogSessionChanged>()));
    expect(calls.length, 1);
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
        value: _DraftOnly(repo),
        child: MaterialApp(
            theme: AppTheme.build(),
            home: const RewardCatalogScreen(live: true))));
    await tester.pumpAndSettle();
    expect(find.text('No rewards yet. Select Add reward to get started.'),
        findsOneWidget);
    await tester.tap(find.text('Add reward'));
    await tester.pumpAndSettle();
    expect(find.text('Points cost'), findsNothing);
    expect(find.text('Stock'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'Fixture draft');
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Fixture draft'), findsOneWidget);
    expect(find.text('Saved details'), findsOneWidget);
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
