import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/identity/data/in_memory/in_memory_coach_repository.dart';

void main() {
  test('InMemoryCoachRepository serves seed data', () {
    final repo = InMemoryCoachRepository();
    expect(repo.coachCertifications, isNotEmpty);
    expect(repo.coaches, isNotEmpty);
  });
}
