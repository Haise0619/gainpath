import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/identity/data/in_memory/in_memory_user_account_repository.dart';

void main() {
  test('InMemoryUserAccountRepository serves seed data', () {
    final repo = InMemoryUserAccountRepository();
    expect(repo.users, isNotEmpty);
    expect(repo.branches, isNotEmpty);
  });
}
