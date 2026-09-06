import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/identity/data/in_memory/in_memory_member_profile_repository.dart';

void main() {
  test('InMemoryMemberProfileRepository serves seed data', () {
    final repo = InMemoryMemberProfileRepository();
    expect(repo.memberTrainingFocus, isNotEmpty);
  });
}
