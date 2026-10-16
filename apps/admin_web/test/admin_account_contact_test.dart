// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/admin_settings_screens.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_auth_gateway.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_account_contact_repository.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class _PhotoStore implements AccountPhotoStore {
  int uploads = 0, reads = 0;
  bool failUpload = false;
  final images = <String, Uint8List>{};
  @override
  Future<String> upload(AccountPhoto photo) async {
    uploads++;
    if (failUpload) throw const AccountPhotoUnavailable();
    final path =
        'orgs/o/profilePhotos/admin/${uploads.toRadixString(16).padLeft(32, '0')}';
    images[path] = photo.bytes;
    return path;
  }

  @override
  Future<Uint8List> read(String path) async {
    reads++;
    return images[path]!;
  }
}

class _PhotoPicker implements AccountPhotoPicker {
  _PhotoPicker(this.photo);
  final AccountPhoto photo;
  @override
  Future<AccountPhoto?> pick() async => photo;
}

Future<AccountPhoto> _fixturePhoto() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xff8844cc), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return AccountPhoto(bytes);
}
late AccountPhoto _sharedPhoto;

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  Future<UserCredential> signInWithEmailAndPassword(
          {required String email, required String password}) async =>
      _Credential();
}

class _Credential extends Fake implements UserCredential {
  @override
  User get user => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'admin';
  @override
  String get email => 'admin@example.test';
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
    if (options != null) expect(options.source, Source.server);
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
    if (options != null) expect(options.source, Source.server);
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
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    _sharedPhoto = await _fixturePhoto();
  });
  late _Db db;
  late FirebaseAdminAccountContactRepository repo;
  var current = true;
  final session = AuthSession(
      userId: 'admin',
      organizationId: 'o',
      role: AppRole.admin,
      email: 'admin@example.test',
      branchIds: const ['main']);
  setUp(() {
    db = _Db();
    current = true;
    repo = FirebaseAdminAccountContactRepository(
        scope: session.scope,
        isCurrent: () => current,
        firestore: db,
        auth: _Auth());
  });
  test('Admin authentication resolves the saved canonical account name',
      () async {
    db.records['users/admin']!['displayName'] = 'Existing Administrator';
    final gateway = FlutterFirebaseAuthGateway(auth: _Auth(), firestore: db);
    final user = await gateway.signIn(
        email: 'admin@example.test', password: 'local-test');
    expect(user.displayName, 'Existing Administrator');
  });
  test(
      'create/read/update/clear only own name and timestamp, preserving assignment and unrelated data',
      () async {
    db.records['users/admin']!['avatarPath'] = 'existing-avatar';
    final memberBefore = Map.of(db.records['orgs/o/members/admin']!);
    final empty = await repo.load();
    expect(empty.displayName, '');
    final saved = await repo.save(empty, displayName: ' Administrator ');
    expect(saved.displayName, 'Administrator');
    expect(saved.email, 'admin@example.test');
    expect(db.patch!.keys, unorderedEquals(['displayName', 'updatedAtMillis']));
    final reopened = FirebaseAdminAccountContactRepository(
        scope: session.scope,
        isCurrent: () => current,
        firestore: db,
        auth: _Auth());
    final loaded = await reopened.load();
    expect(loaded.displayName, 'Administrator');
    final edited = await reopened.save(loaded, displayName: 'Edited name');
    final cleared = await reopened.save(edited, displayName: '   ');
    expect(cleared.displayName, '');
    expect(db.records['users/admin']!['avatarPath'], 'existing-avatar');
    expect(db.records['orgs/o/members/admin'], memberBefore);
    expect(db.records.keys,
        unorderedEquals(['users/admin', 'orgs/o/members/admin']));
  });
  test('rejects excessive and control characters without writing', () async {
    final original = await repo.load();
    for (final name in ['x' * 81, 'Line\nbreak', 'Control\u0001character']) {
      await expectLater(
          repo.save(original, displayName: name), throwsFormatException);
    }
    expect(db.patch, isNull);
  });
  test(
      'concurrent changes and transaction retries cannot overwrite the original baseline',
      () async {
    final original = await repo.load();
    db.retry =
        () => db.records['users/admin']!['displayName'] = 'Second editor';
    await expectLater(repo.save(original, displayName: 'Stale'),
        throwsA(isA<AdminAccountContactConflict>()));
    expect(db.records['users/admin']!['displayName'], 'Second editor');
    expect(db.patch, isNull);
    db.retry = null;
    final other = FirebaseAdminAccountContactRepository(
        scope: session.scope,
        isCurrent: () => true,
        firestore: db,
        auth: _Auth());
    await expectLater(other.save(original, displayName: 'Foreign baseline'),
        throwsA(isA<AdminAccountContactConflict>()));
    db.records.remove('users/admin');
    await expectLater(repo.save(original, displayName: 'Recreate'),
        throwsA(isA<AdminAccountContactSessionChanged>()));
  });
  test(
      'role, membership organization, canonical assignment and inactive status reject authoring',
      () async {
    for (final change in [
      ['orgs/o/members/admin', 'role', 'member'],
      ['orgs/o/members/admin', 'status', 'suspended'],
      ['orgs/o/members/admin', 'organizationId', 'other'],
      ['users/admin', 'organizationId', 'other'],
    ]) {
      final isolated = _Db();
      final account = FirebaseAdminAccountContactRepository(
          scope: session.scope,
          isCurrent: () => true,
          firestore: isolated,
          auth: _Auth());
      final original = await account.load();
      isolated.records[change[0]]![change[1]] = change[2];
      await expectLater(account.save(original, displayName: 'Forbidden'),
          throwsA(isA<AdminAccountContactSessionChanged>()));
      expect(isolated.patch, isNull);
    }
  });
  test('account drift stays latched after the original account returns',
      () async {
    final original = await repo.load();
    current = false;
    await expectLater(repo.save(original, displayName: 'Wrong session'),
        throwsA(isA<AdminAccountContactSessionChanged>()));
    current = true;
    await expectLater(
        repo.load(), throwsA(isA<AdminAccountContactSessionChanged>()));
  });
  testWidgets(
      'existing account screen saves, reloads and clears; credentials and unsupported controls stay read-only',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        RepositoryProvider<AdminAccountContactRepository>.value(
            value: repo,
            child: MaterialApp(
                theme: AppTheme.build(),
                home: AdminSettingsScreen(liveSession: session))));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).last).readOnly, true);
    expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'admin@example.test');
    for (final control
        in tester.widgetList<SwitchListTile>(find.byType(SwitchListTile))) {
      expect(control.onChanged, isNull);
    }
    await tester.enterText(find.byType(TextField).first, 'New Admin Name');
    await tester.tap(find.text('Save modifications'));
    await tester.pumpAndSettle();
    expect(db.records['users/admin']!['displayName'], 'New Admin Name');
    await tester.enterText(find.byType(TextField).first, 'Unsaved');
    await tester.tap(find.byTooltip('Reload account'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'New Admin Name');
    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('Save modifications'));
    await tester.pumpAndSettle();
    expect(db.records['users/admin']!['displayName'], '');
  });
  testWidgets(
      'verified account save closes the editor and requests the shared session refresh',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var refreshes = 0;
    await tester.pumpWidget(
        RepositoryProvider<AdminAccountContactRepository>.value(
            value: repo,
            child: MaterialApp(
                theme: AppTheme.build(),
                home: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AdminSettingsScreen(
                                    liveSession: session,
                                    onSaved: () => refreshes++))),
                        child: const Text('Open account'))))));
    await tester.tap(find.text('Open account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Saved administrator');
    await tester.tap(find.text('Save modifications'));
    await tester.pumpAndSettle();
    expect(find.text('Open account'), findsOneWidget);
    expect(find.byType(AdminSettingsScreen), findsNothing);
    expect(db.records['users/admin']!['displayName'], 'Saved administrator');
    expect(refreshes, 1);
  });
  testWidgets('stale account editor requires reload and never reports success',
      (tester) async {
    await tester.pumpWidget(
        RepositoryProvider<AdminAccountContactRepository>.value(
            value: repo,
            child: MaterialApp(
                theme: AppTheme.build(),
                home: AdminSettingsScreen(liveSession: session))));
    await tester.pumpAndSettle();
    db.records['users/admin']!['displayName'] = 'Another editor';
    await tester.enterText(find.byType(TextField).first, 'Stale edit');
    await tester.ensureVisible(find.text('Save modifications'));
    await tester.tap(find.text('Save modifications'));
    await tester.pumpAndSettle();
    expect(find.text('Your account changed. Reload before saving again.'),
        findsOneWidget);
    expect(find.text('Account name saved.'), findsNothing);
    expect(db.records['users/admin']!['displayName'], 'Another editor');
  });
  test(
      'photo upload, replacement, authenticated read and removal preserve immutable old objects',
      () async {
    final store = _PhotoStore(), photo = _sharedPhoto;
    final account = FirebaseAdminAccountContactRepository(
        scope: session.scope,
        isCurrent: () => current,
        firestore: db,
        auth: _Auth(),
        photoStore: store);
    final saved =
        await account.save(await account.load(), displayName: '', photo: photo);
    expect(saved.avatarPath,
        'orgs/o/profilePhotos/admin/00000000000000000000000000000001');
    expect(await account.readPhoto(saved), photo.bytes);
    final replaced = await account.save(saved, displayName: '', photo: photo);
    expect(replaced.avatarPath,
        'orgs/o/profilePhotos/admin/00000000000000000000000000000002');
    expect(store.images.length, 2);
    final removed =
        await account.save(replaced, displayName: '', removePhoto: true);
    expect(removed.avatarPath, '');
    expect(await account.readPhoto(removed), isNull);
    expect(store.images.length, 2);
  });
  test(
      'stale photo edits reject before upload; upload failures never claim a persisted attachment',
      () async {
    final store = _PhotoStore(), photo = _sharedPhoto;
    final account = FirebaseAdminAccountContactRepository(
        scope: session.scope,
        isCurrent: () => current,
        firestore: db,
        auth: _Auth(),
        photoStore: store);
    final original = await account.load();
    db.records['users/admin']!['displayName'] = 'Changed';
    await expectLater(account.save(original, displayName: '', photo: photo),
        throwsA(isA<AdminAccountContactConflict>()));
    expect(store.uploads, 0);
    store.failUpload = true;
    await expectLater(
        account.save(await account.load(),
            displayName: 'Changed', photo: photo),
        throwsA(isA<AccountPhotoUnavailable>()));
    expect(db.records['users/admin']!.containsKey('avatarPath'), false);
  });
  testWidgets(
      'photo selection uploads only on Save, reloads real bytes and removes the reference',
      (tester) async {
    final store = _PhotoStore(), photo = _sharedPhoto;
    final account = FirebaseAdminAccountContactRepository(
        scope: session.scope,
        isCurrent: () => current,
        firestore: db,
        auth: _Auth(),
        photoStore: store);
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AdminAccountContactRepository>.value(
              value: account),
          RepositoryProvider<AccountPhotoPicker>.value(
              value: _PhotoPicker(photo)),
        ],
        child: MaterialApp(
            theme: AppTheme.build(),
            home: AdminSettingsScreen(liveSession: session))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(store.uploads, 0);
    expect(find.textContaining('New photo selected.'), findsOneWidget);
    await tester.tap(find.text('Save modifications'));
    await tester.pumpAndSettle();
    expect(store.uploads, 1);
    await tester.tap(find.byTooltip('Reload account'));
    await tester.pumpAndSettle();
    expect(find.text('Your saved private photo.'), findsOneWidget);
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save modifications'));
    await tester.pumpAndSettle();
    expect(db.records['users/admin']!['avatarPath'], '');
    expect(find.text('No profile photo saved.'), findsOneWidget);
  });
  testWidgets(
      'mock account controls preserve entered text during notification changes',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepositoryProvider<UserAccountRepository>(
        create: (_) => InMemoryUserAccountRepository(),
        child: MaterialApp(
            theme: AppTheme.build(), home: const AdminSettingsScreen())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Edited mock name');
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Edited mock name');
  });
}
