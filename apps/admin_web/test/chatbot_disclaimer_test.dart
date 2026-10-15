// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/chatbot/presentation/admin/chatbot_disclaimer_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_chatbot_disclaimer_repository.dart';
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
  late FirebaseChatbotDisclaimerRepository repo;
  var current = true;
  const path = 'orgs/o/chatbotDisclaimer/config';
  setUp(() {
    db = _Db();
    current = true;
    repo = FirebaseChatbotDisclaimerRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth());
  });
  test(
      'empty load then create, edit, activate, deactivate and server reload retain history',
      () async {
    final empty = await repo.load();
    expect(empty.current, isNull);
    expect(empty.history, isEmpty);
    final first = await repo.save(empty, text: ' Notice ', isActive: false);
    expect(first.current!.text, 'Notice');
    final createdAt = db.records[path]!['createdAt'];
    final second =
        await repo.save(first, text: 'Edited notice', isActive: true);
    final third =
        await repo.save(second, text: 'Edited notice', isActive: false);
    final reloaded = await repo.load();
    expect(reloaded.current!.revision, 3);
    expect(reloaded.current!.isActive, false);
    expect(third.history.length, 3);
    expect(db.records['$path/versions/1']!['text'], 'Notice');
    expect(db.records['$path/versions/2']!['isActive'], true);
    expect(db.records[path]!['createdAt'], createdAt);
  });
  test('rejects empty/oversize text and active creation without writing',
      () async {
    final original = await repo.load();
    for (final text in ['', '   ', 'x' * 4001]) {
      await expectLater(repo.save(original, text: text, isActive: false),
          throwsFormatException);
    }
    await expectLater(repo.save(original, text: 'Notice', isActive: true),
        throwsFormatException);
    expect(db.records.containsKey(path), false);
  });
  test('rejects stale, deleted, foreign-baseline and concurrent retry writes',
      () async {
    final first =
        await repo.save(await repo.load(), text: 'First', isActive: false);
    db.retry = () => db.records[path]!['text'] = 'Second editor';
    await expectLater(repo.save(first, text: 'Stale', isActive: false),
        throwsA(isA<ChatbotDisclaimerConflict>()));
    expect(db.records[path]!['text'], 'Second editor');
    expect(db.records.containsKey('$path/versions/2'), false);
    db.retry = null;
    db.records.remove(path);
    await expectLater(repo.save(first, text: 'Restore', isActive: false),
        throwsA(isA<ChatbotDisclaimerConflict>()));
    final other = FirebaseChatbotDisclaimerRepository(
        scope: repo.scope, isCurrent: () => true, firestore: db, auth: _Auth());
    await expectLater(other.save(first, text: 'Other session', isActive: false),
        throwsA(isA<ChatbotDisclaimerConflict>()));
  });
  test('initial missing baseline cannot overwrite a concurrent creation',
      () async {
    final missing = await repo.load();
    await repo.save(missing, text: 'First', isActive: false);
    await expectLater(repo.save(missing, text: 'Overwrite', isActive: false),
        throwsA(isA<ChatbotDisclaimerConflict>()));
  });
  test('canonical org and membership changes invalidate authoring', () async {
    final first =
        await repo.save(await repo.load(), text: 'Notice', isActive: false);
    db.records['users/admin']!['organizationId'] = 'other';
    await expectLater(repo.save(first, text: 'Forbidden', isActive: false),
        throwsA(isA<ChatbotDisclaimerSessionChanged>()));
    db.records['users/admin']!['organizationId'] = 'o';
    await expectLater(
        repo.load(), throwsA(isA<ChatbotDisclaimerSessionChanged>()));
  });
  test('account drift stays latched even when the original account returns',
      () async {
    final first = await repo.load();
    current = false;
    await expectLater(repo.save(first, text: 'Forbidden', isActive: false),
        throwsA(isA<ChatbotDisclaimerSessionChanged>()));
    current = true;
    await expectLater(
        repo.load(), throwsA(isA<ChatbotDisclaimerSessionChanged>()));
  });
  testWidgets(
      'existing editor saves, edits, deactivates and reloads without mock history',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        RepositoryProvider<ChatbotDisclaimerRepository>.value(
            value: repo,
            child: MaterialApp(
                theme: AppTheme.build(),
                home: const ChatbotDisclaimerScreen(live: true))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Initial disclaimer at chatbot launch'),
        findsNothing);
    expect(
        find.textContaining('No disclaimer has been saved.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'First notice');
    await tester.tap(find.text('Save new version'));
    await tester.pumpAndSettle();
    expect(db.records[path]!['isActive'], false);
    await tester.enterText(find.byType(TextField), 'Edited notice');
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Save new version'));
    await tester.pumpAndSettle();
    expect(db.records[path]!['text'], 'Edited notice');
    expect(db.records[path]!['isActive'], true);
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Save new version'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved');
    await tester.tap(find.byTooltip('Reload disclaimer'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Edited notice');
    expect(db.records[path]!['isActive'], false);
    expect(find.text('v3 inactive'), findsOneWidget);
  });
  testWidgets(
      'stale editor blocks another save until reload, without a success toast',
      (tester) async {
    await repo.save(await repo.load(), text: 'First', isActive: false);
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        RepositoryProvider<ChatbotDisclaimerRepository>.value(
            value: repo,
            child: MaterialApp(
                theme: AppTheme.build(),
                home: const ChatbotDisclaimerScreen(live: true))));
    await tester.pumpAndSettle();
    db.records[path]!['text'] = 'Another editor';
    db.records[path]!['revision'] = 2;
    await tester.enterText(find.byType(TextField), 'Stale edit');
    await tester.tap(find.text('Save new version'));
    await tester.pumpAndSettle();
    expect(find.text('The disclaimer changed. Reload before saving again.'),
        findsOneWidget);
    expect(find.textContaining(' saved.'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(db.records[path]!['text'], 'Another editor');
    await tester.tap(find.byTooltip('Reload disclaimer'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Another editor');
  });
  testWidgets('mock editor and preview remain available', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(), home: const ChatbotDisclaimerScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Publish new version'), findsOneWidget);
    expect(find.text('v3 live'), findsOneWidget);
  });
}
