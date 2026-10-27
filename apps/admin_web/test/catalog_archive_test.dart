import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/workout.dart';
import 'exercise_catalog_concurrency_test.dart' show MemoryStore;

void main() {
  late MemoryStore store;
  late FirebaseExerciseCatalogRepository repository;
  setUp(() {
    store = MemoryStore();
    repository = FirebaseExerciseCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        store: store,
        isSessionCurrent: () => true);
  });
  test('archive retains exercise data and deactivates it', () async {
    final item = (await repository.load()).single;
    await repository.archive(item);
    expect(store.record!['archived'], true);
    expect(store.record!['isActive'], false);
    expect(store.record!['exerciseName'], 'Squat');
    expect((await repository.load()).single.archived, true);
  });
  test('archive rejects concurrent changes', () async {
    final item = (await repository.load()).single;
    store.record!['exerciseName'] = 'Changed';
    await expectLater(
        repository.archive(item), throwsA(isA<TutorialEditConflict>()));
    expect(store.patch, isNull);
  });
  test('archive rejects changed authority', () async {
    final item = (await repository.load()).single;
    store.membership!['role'] = 'member';
    await expectLater(repository.archive(item),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(store.patch, isNull);
  });
}
