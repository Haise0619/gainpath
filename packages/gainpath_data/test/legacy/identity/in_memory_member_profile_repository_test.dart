import 'package:test/test.dart';
import 'package:gainpath_data/src/identity/in_memory/in_memory_member_profile_repository.dart';

void main() {
  test('InMemoryMemberProfileRepository serves seed data', () {
    final repo = InMemoryMemberProfileRepository();
    expect(repo.memberTrainingFocus, isNotEmpty);
  });
}
