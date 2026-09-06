import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/workout/data/in_memory/in_memory_routine_template_repository.dart';

void main() {
  test('InMemoryRoutineTemplateRepository serves seed data', () {
    final repo = InMemoryRoutineTemplateRepository();
    expect(repo.routineTemplates, isNotEmpty);
  });
}
