// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/content/presentation/admin/announcements_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_announcement_repository.dart';
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

Announcement draft() => Announcement(
    id: '',
    title: 'Hours',
    body: 'Development fixture',
    validFrom: DateTime.now().subtract(const Duration(days: 1)),
    validTo: DateTime.now().add(const Duration(days: 7)),
    status: AnnouncementStatus.draft);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _Db db;
  late FirebaseAnnouncementRepository repo;
  bool current = true;
  setUp(() {
    db = _Db();
    current = true;
    repo = FirebaseAnnouncementRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth());
  });
  test(
      'create/read/edit preserves unchanged fields and writes only intentional changes',
      () async {
    final created = await repo.saveAnnouncement(draft());
    final before = Map.of(db.records['orgs/o/announcements/created']!);
    final loaded = (await repo.loadAnnouncements()).items.single;
    final saved =
        await repo.saveAnnouncement(loaded.copyWith(title: 'New hours'));
    expect(saved.id, created.id);
    expect(saved.revision, 2);
    expect(db.patch!.keys,
        unorderedEquals(['title', 'revision', 'updatedAt', 'updatedBy']));
    expect(db.records['orgs/o/announcements/created']!['createdAt'],
        before['createdAt']);
    expect(saved.body, created.body);
  });
  test('retry cannot adopt concurrent changes; deleted documents conflict',
      () async {
    final original = await repo.saveAnnouncement(draft());
    db.retry = () =>
        db.records['orgs/o/announcements/created']!['body'] = 'Second editor';
    await expectLater(repo.saveAnnouncement(original.copyWith(title: 'Stale')),
        throwsA(isA<AnnouncementConflict>()));
    expect(db.records['orgs/o/announcements/created']!['title'], 'Hours');
    db.retry = null;
    db.records.remove('orgs/o/announcements/created');
    await expectLater(
        repo.saveAnnouncement(original), throwsA(isA<AnnouncementConflict>()));
  });
  test('latched account drift and server membership changes reject edits',
      () async {
    final original = await repo.saveAnnouncement(draft());
    db.records['orgs/o/members/admin']!['role'] = 'member';
    await expectLater(
        repo.saveAnnouncement(original.copyWith(title: 'Forbidden')),
        throwsA(isA<AnnouncementSessionChanged>()));
    db.records['orgs/o/members/admin']!['role'] = 'admin';
    await expectLater(
        repo.loadAnnouncements(), throwsA(isA<AnnouncementSessionChanged>()));
    current = false;
  });
  test(
      'session change during an edit remains blocked after the session returns',
      () async {
    final original = await repo.saveAnnouncement(draft());
    current = false;
    await expectLater(
        repo.saveAnnouncement(original.copyWith(title: 'Stale account')),
        throwsA(isA<AnnouncementSessionChanged>()));
    current = true;
    await expectLater(
        repo.loadAnnouncements(), throwsA(isA<AnnouncementSessionChanged>()));
    expect(db.records['orgs/o/announcements/created']!['title'], 'Hours');
  });
  testWidgets(
      'actual Admin UI and repository create draft, publish, edit, deactivate and reload',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepositoryProvider<ContentRepository>.value(
        value: repo,
        child: MaterialApp(
            theme: AppTheme.build(), home: const AnnouncementsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New announcement'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Hours');
    await tester.enterText(find.byType(TextField).last, 'Development fixture');
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(db.records['orgs/o/announcements/created']!['status'], 'draft');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Updated hours');
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    expect(db.records['orgs/o/announcements/created']!['status'], 'published');
    expect(
        db.records['orgs/o/announcements/created']!['title'], 'Updated hours');
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(db.records['orgs/o/announcements/created']!['status'], 'inactive');
    await tester.tap(find.byTooltip('Refresh announcements'));
    await tester.pumpAndSettle();
    expect(find.text('inactive'), findsOneWidget);
  });
}
