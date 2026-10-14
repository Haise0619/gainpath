import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/exercise_catalog_store.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/workout.dart';

class MemoryStore implements ExerciseCatalogStore, ExerciseCatalogTransaction {
  Map<String, dynamic>? record = {
    'schemaVersion': 1,
    'exerciseName': 'Squat',
    'muscleCategory': 'Compound Lower-Body',
    'isActive': true,
    'videoUrl': 'https://example.test/original.mp4',
    'createdAt': 1,
    'updatedAt': 2,
    'futureField': {
      'preserve': [1, 2]
    },
  };
  Map<String, dynamic>? membership = {
    'role': 'admin',
    'status': 'active',
    'organizationId': 'o'
  };
  Map<String, dynamic>? assignment = {'organizationId': 'o'};
  Map<String, Object?>? patch;
  void Function()? beforeRetry;
  void Function()? afterRead;
  int attempts = 0;
  int creates = 0;
  Object? failure;
  Object? loadFailure;
  @override
  Future<Map<String, Map<String, dynamic>>> load() async {
    if (loadFailure != null) throw loadFailure!;
    return record == null ? {} : {'exercise': Map.of(record!)};
  }

  @override
  Future<Map<String, dynamic>?> readMembership() async =>
      membership == null ? null : Map.of(membership!);
  @override
  Future<Map<String, dynamic>?> readAssignment() async =>
      assignment == null ? null : Map.of(assignment!);
  @override
  Future<Map<String, dynamic>?> readExercise(String id) async {
    final value = record == null ? null : Map<String, dynamic>.of(record!);
    afterRead?.call();
    return value;
  }

  @override
  void update(String id, Map<String, Object?> fields) => patch = fields;
  @override
  Future<void> transaction(
      Future<void> Function(ExerciseCatalogTransaction) action) async {
    if (failure != null) throw failure!;
    attempts++;
    await action(this);
    if (beforeRetry != null) {
      patch = null; // First attempt did not commit.
      beforeRetry!();
      attempts++;
      await action(this);
    }
    if (patch != null) record!.addAll({...patch!, 'updatedAt': 3});
  }

  @override
  Future<String> create(Map<String, Object?> fields) async {
    creates++;
    record = {...fields, 'createdAt': 1, 'updatedAt': 2};
    return 'created';
  }
}

TutorialVideo edited(TutorialVideo original, {String title = 'Edited'}) =>
    TutorialVideo(
        id: original.id,
        title: title,
        category: original.category,
        status: original.status,
        videoUrl: original.videoUrl,
        editBaseline: original.editBaseline);

void main() {
  late MemoryStore store;
  late FirebaseExerciseCatalogRepository repository;
  late bool authorized;
  setUp(() {
    store = MemoryStore();
    authorized = true;
    repository = FirebaseExerciseCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        store: store,
        isSessionCurrent: () => authorized);
  });
  test('non-conflicting save patches only edited fields and preserves metadata',
      () async {
    final original = (await repository.load()).single;
    await repository.save(edited(original));
    expect(store.patch, {'exerciseName': 'Edited'});
    expect(store.record!['createdAt'], 1);
    expect(store.record!['schemaVersion'], 1);
    expect(store.record!['muscleCategory'], 'Compound Lower-Body');
    expect(store.record!['isActive'], true);
    expect(store.record!['videoUrl'], 'https://example.test/original.mp4');
    expect(store.record!['futureField'], {
      'preserve': [1, 2]
    });
  });
  for (final change in {
    'exerciseName': 'Concurrent',
    'videoUrl': 'https://example.test/new.mp4',
    'muscleCategory': 'Core',
    'isActive': false,
    'updatedAt': 9,
  }.entries) {
    test('rejects concurrent ${change.key} even when editor changes only name',
        () async {
      final original = (await repository.load()).single;
      store.record![change.key] = change.value;
      await expectLater(repository.save(edited(original)),
          throwsA(isA<TutorialEditConflict>()));
      expect(store.patch, isNull);
      expect(store.record![change.key], change.value);
    });
  }
  test('retains original baseline on transaction retry', () async {
    final original = (await repository.load()).single;
    store.beforeRetry = () => store.record!['exerciseName'] = 'Concurrent';
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditConflict>()));
    expect(store.attempts, 2);
    expect(store.patch, isNull);
    expect(store.record!['exerciseName'], 'Concurrent');
  });
  test('unchanged retry succeeds without broadening patch', () async {
    final original = (await repository.load()).single;
    store.beforeRetry = () {};
    await repository.save(edited(original));
    expect(store.attempts, 2);
    expect(store.patch, {'exerciseName': 'Edited'});
  });
  test('normalization alone does not write unchanged original fields',
      () async {
    store.record!['exerciseName'] = ' Squat ';
    store.record!['videoUrl'] = ' https://example.test/original.mp4 ';
    final original = (await repository.load()).single;
    await repository.save(edited(original, title: original.title));
    expect(store.patch, isNull);
    expect(store.record!['exerciseName'], ' Squat ');
    expect(store.record!['videoUrl'], ' https://example.test/original.mp4 ');
    expect(store.record!['updatedAt'], 2);
  });
  test('video-only edit preserves name, category and active status', () async {
    final original = (await repository.load()).single;
    final changed = edited(original, title: original.title)
      ..videoUrl = 'https://example.test/edited.mp4';
    await repository.save(changed);
    expect(store.patch, {'videoUrl': 'https://example.test/edited.mp4'});
  });
  test('membership change on retry never becomes a newer authorized baseline',
      () async {
    final original = (await repository.load()).single;
    store.beforeRetry = () => store.membership!['role'] = 'staff';
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(store.patch, isNull);
  });
  test('baseline independent of mutable loaded entity and nested snapshot',
      () async {
    final original = (await repository.load()).single;
    original.title = 'Changed in memory';
    (store.record!['futureField'] as Map)['preserve'] = [3];
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditConflict>()));
  });
  test('missing or deleted record never recreated', () async {
    final original = (await repository.load()).single;
    store.record = null;
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditConflict>()));
    expect(store.creates, 0);
  });
  test('existing record without original baseline is rejected', () async {
    await expectLater(
        repository.save(TutorialVideo(
            id: 'exercise',
            title: 'X',
            category: 'Core',
            status: TutorialStatus.active)),
        throwsA(isA<TutorialEditConflict>()));
  });
  test('account or organization lifetime change prevents save', () async {
    final original = (await repository.load()).single;
    authorized = false;
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(store.attempts, 0);
  });
  test('session change after transaction reads prevents patch', () async {
    final original = (await repository.load()).single;
    store.afterRead = () => authorized = false;
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(store.patch, isNull);
  });
  for (final membership in [
    {'role': 'staff', 'status': 'active'},
    {'role': 'member', 'status': 'active'},
    {'role': 'admin', 'status': 'suspended'},
    null,
  ]) {
    test('membership change $membership prevents save', () async {
      final original = (await repository.load()).single;
      store.membership = membership;
      await expectLater(repository.save(edited(original)),
          throwsA(isA<TutorialEditAuthorizationChanged>()));
      expect(store.patch, isNull);
    });
  }
  test('baseline cannot be replayed in a different repository lifetime',
      () async {
    final original = (await repository.load()).single;
    final other = FirebaseExerciseCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        store: store,
        isSessionCurrent: () => true);
    await expectLater(
        other.save(edited(original)), throwsA(isA<TutorialEditConflict>()));
  });
  test('create still uses original schema and generated ID', () async {
    final saved = await repository.save(TutorialVideo(
        title: 'New',
        category: 'Core',
        status: TutorialStatus.active,
        videoUrl: 'https://example.test/new.mp4'));
    expect(saved.id, 'created');
    expect(store.creates, 1);
    expect(store.record!['schemaVersion'], 1);
  });
  test('repository transport failure contains no raw media detail', () async {
    final original = (await repository.load()).single;
    store.failure = StateError('private-media-credential-sentinel');
    await expectLater(
        repository.save(edited(original)),
        throwsA(predicate((Object error) =>
            !error.toString().contains('private-media-credential-sentinel'))));
  });
  test(
      'server assignment switch blocks edit with old active membership retained',
      () async {
    final original = (await repository.load()).single;
    store.assignment!['organizationId'] = 'other';
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(store.patch, isNull);
  });
  test(
      'server permission rejection during reload permanently invalidates old edit',
      () async {
    final original = (await repository.load()).single;
    store.loadFailure =
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    await expectLater(
        repository.load(), throwsA(isA<TutorialEditAuthorizationChanged>()));
    store.loadFailure = null;
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(store.patch, isNull);
  });
  test('deleted server assignment blocks edit', () async {
    final original = (await repository.load()).single;
    store.assignment = null;
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(store.patch, isNull);
  });
  test('observed authorization drift cannot be replayed after role restoration',
      () async {
    final original = (await repository.load()).single;
    store.membership!['role'] = 'staff';
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    store.membership!['role'] = 'admin';
    await expectLater(repository.save(edited(original)),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    await expectLater(
        repository.load(), throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(store.patch, isNull);
  });
}
