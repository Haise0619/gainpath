import 'package:test/test.dart';
import 'package:gainpath_data/src/workout/in_memory/in_memory_tutorial_repository.dart';

void main() {
  test('InMemoryTutorialRepository serves seed data', () {
    final repo = InMemoryTutorialRepository();
    expect(repo.tutorials, isNotEmpty);
  });
}
