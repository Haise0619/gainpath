// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/equipment_catalog_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_equipment_repository.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'dart:convert';

class _Picker implements EquipmentImagePicker {
  bool fail = false;
  @override
  Future<EquipmentImage?> pick() async {
    if (fail) throw const FormatException('Choose a valid replacement image.');
    return EquipmentImage(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a/eUAAAAASUVORK5CYII='));
  }
}

class _Images implements EquipmentImageStore {
  int uploads = 0;
  bool fail = false;
  void Function()? duringUpload;
  @override
  Future<String> upload(EquipmentImage image) async {
    uploads++;
    if (fail) throw const EquipmentImageUploadFailed();
    duringUpload?.call();
    return 'https://example.test/equipment-image.png';
  }
}

class _VideoPicker implements EquipmentVideoPicker {
  @override
  Future<EquipmentVideo?> pick() async => EquipmentVideo(
      Uint8List.fromList([0, 0, 0, 20, 102, 116, 121, 112, 109, 112, 52, 50]),
      name: 'tutorial.mp4');
}

class _Videos implements EquipmentVideoStore {
  int uploads = 0;
  bool fail = false;
  void Function()? duringUpload;
  @override
  Future<String> upload(EquipmentVideo video,
      {void Function(double)? onProgress}) async {
    uploads++;
    if (fail) throw const EquipmentVideoUploadFailed();
    onProgress?.call(1);
    duringUpload?.call();
    return 'https://example.test/tutorial.mp4';
  }
}

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

GymEquipment equipment() => GymEquipment(
    id: '',
    name: 'Fixture equipment',
    category: 'Legs',
    muscleGroup: 'Legs',
    description: 'Fixture description',
    imageUrl: '',
    howToUse: ['Adjust first'],
    safetyTips: [],
    isActive: false);
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _Db db;
  late FirebaseEquipmentRepository repo;
  bool current = true;
  setUp(() => {
        db = _Db(),
        current = true,
        repo = FirebaseEquipmentRepository(
            scope: SessionScope(userId: 'admin', organizationId: 'o'),
            isCurrent: () => current,
            firestore: db,
            auth: _Auth())
      });
  test(
      'equipment create/edit/read-back preserves identity and unchanged fields',
      () async {
    final created = await repo.saveEquipment(equipment());
    final before = Map.of(db.records['orgs/o/gymEquipment/created']!);
    final loaded = (await repo.loadEquipment()).items.single;
    final saved =
        await repo.saveEquipment(loaded.copyWith()..name = 'Edited equipment');
    expect(saved.id, created.id);
    expect(saved.revision, 2);
    expect(db.patch!.keys,
        unorderedEquals(['name', 'revision', 'updatedAt', 'updatedBy']));
    expect(db.records['orgs/o/gymEquipment/created']!['createdAt'],
        before['createdAt']);
    expect(saved.howToUse, created.howToUse);
  });
  test(
      'transaction retry keeps original baseline; deletion and session drift reject saves',
      () async {
    final original = await repo.saveEquipment(equipment());
    db.retry =
        () => db.records['orgs/o/gymEquipment/created']!['isActive'] = true;
    await expectLater(repo.saveEquipment(original.copyWith()..name = 'Stale'),
        throwsA(isA<EquipmentConflict>()));
    expect(db.records['orgs/o/gymEquipment/created']!['name'],
        'Fixture equipment');
    db.retry = null;
    db.records.remove('orgs/o/gymEquipment/created');
    await expectLater(
        repo.saveEquipment(original), throwsA(isA<EquipmentConflict>()));
    current = false;
    await expectLater(
        repo.saveEquipment(original), throwsA(isA<EquipmentSessionChanged>()));
    current = true;
    await expectLater(
        repo.loadEquipment(), throwsA(isA<EquipmentSessionChanged>()));
  });
  test(
      'image upload saves its URL only after authorization; stale edits remain rejected',
      () async {
    final images = _Images();
    repo = FirebaseEquipmentRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth(),
        imageStore: images);
    final image = EquipmentImage(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]));
    final created = await repo.saveEquipment(equipment(), image: image);
    expect(images.uploads, 1);
    expect(created.imageUrl, 'https://example.test/equipment-image.png');
    db.records['orgs/o/gymEquipment/created']!['name'] = 'Concurrent edit';
    await expectLater(repo.saveEquipment(created, image: image),
        throwsA(isA<EquipmentConflict>()));
    expect(images.uploads, 1);
    final fresh = (await repo.loadEquipment()).items.single;
    images.duringUpload = () => current = false;
    await expectLater(repo.saveEquipment(fresh, image: image),
        throwsA(isA<EquipmentSessionChanged>()));
    expect(
        db.records['orgs/o/gymEquipment/created']!['name'], 'Concurrent edit');
    expect(db.records['orgs/o/gymEquipment/created']!['revision'], 1);
  });
  test(
      'video replacement and removal persist; failed uploads and stale sessions do not save',
      () async {
    final videos = _Videos();
    repo = FirebaseEquipmentRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth(),
        videoStore: videos);
    final video = EquipmentVideo(
        Uint8List.fromList([0, 0, 0, 20, 102, 116, 121, 112, 109, 112, 52, 50]),
        name: 'tutorial.mp4');
    final created = await repo.saveEquipment(equipment(), video: video);
    expect(created.tutorialVideoUrl, 'https://example.test/tutorial.mp4');
    videos.fail = true;
    await expectLater(repo.saveEquipment(created, video: video),
        throwsA(isA<EquipmentVideoUploadFailed>()));
    expect(db.records['orgs/o/gymEquipment/created']!['revision'], 1);
    videos.fail = false;
    final removed =
        await repo.saveEquipment(created.copyWith()..tutorialVideoUrl = '');
    expect(removed.tutorialVideoUrl, '');
    await expectLater(repo.saveEquipment(created, video: video),
        throwsA(isA<EquipmentConflict>()));
    videos.duringUpload = () => current = false;
    await expectLater(repo.saveEquipment(removed, video: video),
        throwsA(isA<EquipmentSessionChanged>()));
    expect(db.records['orgs/o/gymEquipment/created']!['tutorialVideoUrl'], '');
    expect(db.records['orgs/o/gymEquipment/created']!['revision'], 2);
  });
  testWidgets(
      'existing Admin UI creates, edits, activates, deactivates and reloads persisted equipment',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final images = _Images();
    final videos = _Videos();
    final picker = _Picker();
    repo = FirebaseEquipmentRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth(),
        imageStore: images,
        videoStore: videos);
    await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<EquipmentRepository>.value(value: repo),
          RepositoryProvider<EquipmentVideoPicker>.value(value: _VideoPicker()),
          RepositoryProvider<EquipmentImagePicker>.value(value: picker),
        ],
        child: MaterialApp(
            theme: AppTheme.build(), home: const EquipmentCatalogScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add equipment'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Fixture equipment');
    await tester.enterText(find.byType(TextFormField).at(1), 'Legs');
    await tester.enterText(find.byType(TextFormField).at(2), 'Legs');
    await tester.enterText(
        find.byType(TextFormField).at(3), 'Fixture description');
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    expect(find.text('Discard selected image'), findsOneWidget);
    images.fail = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Add equipment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Image upload failed.'), findsOneWidget);
    expect(db.records.containsKey('orgs/o/gymEquipment/created'), false);
    images.fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Add equipment'));
    await tester.pumpAndSettle();
    expect(db.records['orgs/o/gymEquipment/created']!['isActive'], false);
    expect(db.records['orgs/o/gymEquipment/created']!['imageUrl'],
        'https://example.test/equipment-image.png');
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final uploadsBeforeReplacement = images.uploads;
    await tester.tap(find.text('Choose tutorial video'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selected: tutorial.mp4'), findsOneWidget);
    expect(videos.uploads, 0);
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    expect(find.text('New image selected. Save changes to apply it.'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('equipment-selected-image-preview')),
        findsOneWidget);
    expect(images.uploads, uploadsBeforeReplacement);
    picker.fail = true;
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('equipment-image-error')), findsOneWidget);
    expect(find.text('Choose a valid replacement image.'), findsOneWidget);
    expect(find.byKey(const ValueKey('equipment-selected-image-preview')),
        findsOneWidget);
    expect(images.uploads, uploadsBeforeReplacement);
    picker.fail = false;
    await tester.enterText(
        find.byType(TextFormField).first, 'Edited equipment');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(images.uploads, uploadsBeforeReplacement + 1);
    expect(videos.uploads, 1);
    expect(db.records['orgs/o/gymEquipment/created']!['tutorialVideoUrl'],
        'https://example.test/tutorial.mp4');
    expect(
        db.records['orgs/o/gymEquipment/created']!['name'], 'Edited equipment');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(db.records['orgs/o/gymEquipment/created']!['isActive'], true);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh equipment'));
    await tester.pumpAndSettle();
    expect(db.records['orgs/o/gymEquipment/created']!['isActive'], false);
    expect(find.text('Hidden'), findsOneWidget);
  });
}
