import 'package:test/test.dart';
import 'package:gainpath_data/src/identity/in_memory/in_memory_user_account_repository.dart';

void main() {
  test('InMemoryUserAccountRepository serves seed data', () {
    final repo = InMemoryUserAccountRepository();
    expect(repo.users, isNotEmpty);
    expect(repo.branches, isNotEmpty);
  });
}
