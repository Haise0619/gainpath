import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/membership/data/in_memory/in_memory_membership_repository.dart';

void main() {
  test('InMemoryMembershipRepository serves seed data', () {
    final repo = InMemoryMembershipRepository();
    expect(repo.transactions, isNotEmpty);
    expect(repo.membershipPlans, isNotEmpty);
    expect(repo.refundClaims, isNotEmpty);
  });
}
