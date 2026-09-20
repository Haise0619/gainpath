import 'package:test/test.dart';
import 'package:gainpath_data/src/workout/in_memory/in_memory_routine_template_repository.dart';

void main() {
  test('InMemoryRoutineTemplateRepository serves seed data', () {
    final repo = InMemoryRoutineTemplateRepository();
    expect(repo.routineTemplates, isNotEmpty);
  });
}
