// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/content/presentation/admin/system_settings_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_compliance_document_repository.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

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

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _Db db;
  late FirebaseComplianceDocumentRepository repo;
  var current = true;
  const path = 'orgs/o/complianceDocuments/config';
  setUp(() {
    db = _Db();
    current = true;
    repo = FirebaseComplianceDocumentRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth());
  });
  test(
      'empty load then create, edit, archive, restore and server reload retain history',
      () async {
    final empty = await repo.load();
    expect(empty.current, isNull);
    expect(empty.history, isEmpty);
    final first = await repo.save(empty, text: ' Notice ', isArchived: false);
    expect(first.current!.text, 'Notice');
    final createdAt = db.records[path]!['createdAt'];
    final second =
        await repo.save(first, text: 'Edited notice', isArchived: true);
    final third =
        await repo.save(second, text: 'Edited notice', isArchived: false);
    final reloaded = await repo.load();
    expect(reloaded.current!.revision, 3);
    expect(reloaded.current!.isArchived, false);
    expect(third.history.length, 3);
    expect(db.records['$path/versions/1']!['text'], 'Notice');
    expect(db.records['$path/versions/2']!['status'], 'archived');
    expect(db.records[path]!['createdAt'], createdAt);
  });
  test('rejects empty/oversize text and archived creation without writing',
      () async {
    final original = await repo.load();
    for (final text in ['', '   ', 'x' * 12001]) {
      await expectLater(repo.save(original, text: text, isArchived: false),
          throwsFormatException);
    }
    await expectLater(repo.save(original, text: 'Notice', isArchived: true),
        throwsFormatException);
    expect(db.records.containsKey(path), false);
  });
  test('rejects stale, deleted, foreign-baseline and concurrent retry writes',
      () async {
    final first =
        await repo.save(await repo.load(), text: 'First', isArchived: false);
    db.retry = () => db.records[path]!['text'] = 'Second editor';
    await expectLater(repo.save(first, text: 'Stale', isArchived: false),
        throwsA(isA<ComplianceDocumentConflict>()));
    expect(db.records[path]!['text'], 'Second editor');
    expect(db.records.containsKey('$path/versions/2'), false);
    db.retry = null;
    db.records.remove(path);
    await expectLater(repo.save(first, text: 'Restore', isArchived: false),
        throwsA(isA<ComplianceDocumentConflict>()));
    final other = FirebaseComplianceDocumentRepository(
        scope: repo.scope, isCurrent: () => true, firestore: db, auth: _Auth());
    await expectLater(
        other.save(first, text: 'Other session', isArchived: false),
        throwsA(isA<ComplianceDocumentConflict>()));
  });
  test('initial missing baseline cannot overwrite a concurrent creation',
      () async {
    final missing = await repo.load();
    await repo.save(missing, text: 'First', isArchived: false);
    await expectLater(repo.save(missing, text: 'Overwrite', isArchived: false),
        throwsA(isA<ComplianceDocumentConflict>()));
  });
  test('canonical org and membership changes invalidate authoring', () async {
    final first =
        await repo.save(await repo.load(), text: 'Notice', isArchived: false);
    db.records['users/admin']!['organizationId'] = 'other';
    await expectLater(repo.save(first, text: 'Forbidden', isArchived: false),
        throwsA(isA<ComplianceDocumentSessionChanged>()));
    db.records['users/admin']!['organizationId'] = 'o';
    await expectLater(
        repo.load(), throwsA(isA<ComplianceDocumentSessionChanged>()));
  });
  test('account drift stays latched even when the original account returns',
      () async {
    final first = await repo.load();
    current = false;
    await expectLater(repo.save(first, text: 'Forbidden', isArchived: false),
        throwsA(isA<ComplianceDocumentSessionChanged>()));
    current = true;
    await expectLater(
        repo.load(), throwsA(isA<ComplianceDocumentSessionChanged>()));
  });

  testWidgets(
      'settings saves draft, edits, archives, restores and reloads without publication',
      (tester) async {
    tester.view.physicalSize = const Size(1450, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        RepositoryProvider<ComplianceDocumentRepository>.value(
            value: repo,
            child: MaterialApp(
                theme: AppTheme.build(),
                home: const SystemSettingsScreen(live: true))));
    await tester.pumpAndSettle();
    expect(find.text('Publish new version'), findsNothing);
    expect(find.textContaining('No compliance draft has been saved.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), 'First compliance draft');
    await tester.tap(find.text('Save draft version'));
    await tester.pumpAndSettle();
    expect(db.records[path]!['status'], 'draft');
    await tester.enterText(find.byType(TextField), 'Edited compliance draft');
    await tester.tap(find.text('Save draft version'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive draft'));
    await tester.pumpAndSettle();
    expect(db.records[path]!['status'], 'archived');
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    await tester.tap(find.text('Restore draft'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved edit');
    await tester.tap(find.byTooltip('Reload compliance draft'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Edited compliance draft');
    expect(find.text('v4 draft'), findsOneWidget);
    expect(
        db.records.keys.every((key) =>
            key == 'users/admin' ||
            key == 'orgs/o/members/admin' ||
            key == path ||
            key.startsWith('$path/versions/')),
        true);
    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    expect(find.text('General preferences are not connected to Firebase yet.'),
        findsOneWidget);
    await tester.tap(find.text('Reward conversion'));
    await tester.pumpAndSettle();
    expect(find.text('Reward conversion is not connected to Firebase yet.'),
        findsOneWidget);
    expect(find.text('Save conversion rate'), findsNothing);
  });
  testWidgets('stale draft save is blocked until reload without false success',
      (tester) async {
    await repo.save(await repo.load(), text: 'Original', isArchived: false);
    tester.view.physicalSize = const Size(1450, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        RepositoryProvider<ComplianceDocumentRepository>.value(
            value: repo,
            child: MaterialApp(
                theme: AppTheme.build(),
                home: const SystemSettingsScreen(live: true))));
    await tester.pumpAndSettle();
    db.records[path]!['text'] = 'Another editor';
    db.records[path]!['revision'] = 2;
    await tester.enterText(find.byType(TextField), 'Stale');
    await tester.tap(find.text('Save draft version'));
    await tester.pumpAndSettle();
    expect(
        find.text('The compliance draft changed. Reload before saving again.'),
        findsOneWidget);
    expect(find.textContaining(' saved.'), findsNothing);
    expect(db.records[path]!['text'], 'Another editor');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.byTooltip('Reload compliance draft'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Another editor');
  });
  testWidgets('mock settings retain all three prototype tabs', (tester) async {
    tester.view.physicalSize = const Size(1450, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(), home: const SystemSettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Deploy changes'), findsOneWidget);
    await tester.tap(find.text('Reward conversion'));
    await tester.pumpAndSettle();
    expect(find.text('Save conversion rate'), findsOneWidget);
    await tester.tap(find.text('Legal & compliance'));
    await tester.pumpAndSettle();
    expect(find.text('Publish new version'), findsOneWidget);
    expect(find.text('v5 live'), findsOneWidget);
  });
}
