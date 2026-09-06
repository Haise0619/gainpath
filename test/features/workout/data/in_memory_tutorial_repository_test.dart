import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/workout/data/in_memory/in_memory_tutorial_repository.dart';

void main() {
  test('InMemoryTutorialRepository serves seed data', () {
    final repo = InMemoryTutorialRepository();
    expect(repo.tutorials, isNotEmpty);
  });
}
