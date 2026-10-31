import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/workout.dart';
import 'exercise_catalog_concurrency_test.dart' show MemoryStore, edited;

class StatusStore extends MemoryStore {
  void Function()? afterCommit;
  @override
  Future<void> transaction(action) async {
    await super.transaction(action);
    afterCommit?.call();
  }
}

void main() {
  late StatusStore store;
  late FirebaseExerciseCatalogRepository repository;
  late bool authorized;
  setUp(() {
    store = StatusStore();
    authorized = true;
    repository = FirebaseExerciseCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        store: store,
        isSessionCurrent: () => authorized);
  });

  for (final from in ExerciseCatalogStatus.values) {
    for (final target in ExerciseCatalogStatus.values) {
      test('$from to $target preserves content and metadata', () async {
        store.record!.addAll({
          'archived': from == ExerciseCatalogStatus.archived,
          'isActive': from == ExerciseCatalogStatus.active,
          'createdBy': 'original-author',
          'updatedBy': 'cli-author',
          'aiSupported': true,
        });
        final original = Map<String, dynamic>.of(store.record!);
        final item = (await repository.load()).single;
        expect(item.catalogStatus, from);
        final saved = await repository.setCatalogStatus(item, target);
        expect(saved.id, 'exercise');
        expect(saved.catalogStatus, target);
        expect(store.patch, {
          'archived': target == ExerciseCatalogStatus.archived,
          'isActive': target == ExerciseCatalogStatus.active,
        });
        for (final key in original.keys.where(
            (key) => !['archived', 'isActive', 'updatedAt'].contains(key))) {
          expect(store.record![key], original[key], reason: key);
        }
      });
    }
  }
  test('archived overrides malformed legacy active flag for display', () async {
    store.record!['archived'] = true;
    expect((await repository.load()).single.catalogStatus,
        ExerciseCatalogStatus.archived);
  });
  test('archived content cannot be saved or implicitly restored', () async {
    store.record!['archived'] = true;
    store.record!['isActive'] = false;
    final item = (await repository.load()).single;
    await expectLater(
        repository.save(edited(item)), throwsA(isA<TutorialEditConflict>()));
    expect(store.patch, isNull);
  });
  test('status transition retains original baseline across retries', () async {
    final item = (await repository.load()).single;
    store.beforeRetry = () => store.record!['videoUrl'] = 'concurrent';
    await expectLater(
        repository.setCatalogStatus(item, ExerciseCatalogStatus.archived),
        throwsA(isA<TutorialEditConflict>()));
    expect(store.patch, isNull);
  });
  test('unchanged transaction retry succeeds', () async {
    final item = (await repository.load()).single;
    store.beforeRetry = () {};
    await repository.setCatalogStatus(item, ExerciseCatalogStatus.inactive);
    expect(store.attempts, 2);
    expect(store.record!['isActive'], false);
  });
  for (final change in [
    'role',
    'organization',
    'session',
    'missing',
    'changed'
  ]) {
    test('$change drift prevents status transition', () async {
      final item = (await repository.load()).single;
      if (change == 'role') store.membership!['role'] = 'staff';
      if (change == 'organization') {
        store.assignment!['organizationId'] = 'other';
      }
      if (change == 'session') authorized = false;
      if (change == 'missing') store.record = null;
      if (change == 'changed') store.record!['updatedAt'] = 99;
      await expectLater(
          repository.setCatalogStatus(item, ExerciseCatalogStatus.archived),
          throwsA(change == 'missing' || change == 'changed'
              ? isA<TutorialEditConflict>()
              : isA<TutorialEditAuthorizationChanged>()));
      expect(store.patch, isNull);
    });
  }
  test('foreign and missing baseline cannot transition status', () async {
    final item = (await repository.load()).single;
    final other = FirebaseExerciseCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        store: store,
        isSessionCurrent: () => true);
    await expectLater(
        other.setCatalogStatus(item, ExerciseCatalogStatus.active),
        throwsA(isA<TutorialEditConflict>()));
    await expectLater(
        repository.setCatalogStatus(
            edited(TutorialVideo(
                id: 'exercise',
                title: 'X',
                category: 'Core',
                status: TutorialStatus.active)),
            ExerciseCatalogStatus.active),
        throwsA(isA<TutorialEditConflict>()));
    expect(store.patch, isNull);
  });
  for (final change in [
    'role',
    'assignment',
    'session',
    'readback',
    'wrong-status'
  ]) {
    test('$change after commit prevents reporting status success', () async {
      final item = (await repository.load()).single;
      store.afterCommit = () {
        if (change == 'role') store.membership!['role'] = 'staff';
        if (change == 'assignment') {
          store.assignment!['organizationId'] = 'elsewhere';
        }
        if (change == 'session') authorized = false;
        if (change == 'readback') store.failReadBack = true;
        if (change == 'wrong-status') store.record!['isActive'] = true;
      };
      await expectLater(
          repository.setCatalogStatus(item, ExerciseCatalogStatus.inactive),
          throwsA(change == 'readback' || change == 'wrong-status'
              ? isA<TutorialCatalogSaveFailed>()
              : isA<TutorialEditAuthorizationChanged>()));
    });
  }
  test('permission denied invalidates the repository for later replay',
      () async {
    final item = (await repository.load()).single;
    store.failure =
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    await expectLater(
        repository.setCatalogStatus(item, ExerciseCatalogStatus.archived),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    store.failure = null;
    await expectLater(
        repository.setCatalogStatus(item, ExerciseCatalogStatus.archived),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(store.patch, isNull);
  });
}
