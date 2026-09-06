import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/content/data/in_memory/in_memory_content_repository.dart';

void main() {
  test('InMemoryContentRepository serves seed data', () {
    final repo = InMemoryContentRepository();
    expect(repo.announcements, isNotEmpty);
  });
}
