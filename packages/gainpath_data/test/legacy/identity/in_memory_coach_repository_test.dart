import 'package:test/test.dart';
import 'package:gainpath_data/src/identity/in_memory/in_memory_coach_repository.dart';

void main() {
  test('InMemoryCoachRepository serves seed data', () {
    final repo = InMemoryCoachRepository();
    expect(repo.coachCertifications, isNotEmpty);
    expect(repo.coaches, isNotEmpty);
  });
}
