import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_data/workout.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test('mock create and edit keep prototype fields and session isolation',
      () async {
    final session = MockDataSession();
    final repository = InMemoryTutorialRepository(session: session);
    final shared = InMemoryTutorialRepository(session: session);
    final isolated = InMemoryTutorialRepository();
    final count = repository.tutorials.length;
    final created = await repository.save(TutorialVideo(
        title: 'Fixture tutorial',
        category: 'Core',
        status: TutorialStatus.draft,
        videoUrl: 'https://example.test/mock.mp4',
        description: 'Prototype',
        difficulty: 'Advanced',
        durationMin: 7,
        coversExercise: 'Fixture'));
    expect(created.id, isNotEmpty);
    expect(repository.tutorials.length, count + 1);
    expect(shared.tutorials.last.id, created.id);
    expect(isolated.tutorials.any((item) => item.id == created.id), isFalse);
    created.title = 'Edited fixture';
    created.status = TutorialStatus.active;
    await repository.save(created);
    expect(repository.tutorials.length, count + 1);
    final saved = shared.tutorials.last;
    expect(saved.title, 'Edited fixture');
    expect(saved.description, 'Prototype');
    expect(saved.difficulty, 'Advanced');
    expect(saved.durationMin, 7);
    expect(saved.coversExercise, 'Fixture');
    expect(saved.status, TutorialStatus.active);
    expect(saved.editBaseline, isNull);
    expect(repository.requiresCatalogSelection, isFalse);
  });
}
