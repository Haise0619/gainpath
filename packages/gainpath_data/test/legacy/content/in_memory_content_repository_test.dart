import 'package:test/test.dart';
import 'package:gainpath_data/src/content/in_memory/in_memory_content_repository.dart';

void main() {
  test('InMemoryContentRepository serves seed data', () {
    final repo = InMemoryContentRepository();
    expect(repo.announcements, isNotEmpty);
  });
}
