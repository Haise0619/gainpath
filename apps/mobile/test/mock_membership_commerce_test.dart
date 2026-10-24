import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/src/membership/in_memory/in_memory_membership_repository.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_mobile/features/membership/data/mock_membership_commerce.dart';

void main() {
  test(
      'mock shares Free/paid contract without a Free payment or unsupported tier',
      () async {
    final repo =
        MockMembershipCommerce.forRepository(InMemoryMembershipRepository());
    final initial = await repo.load();
    expect(MembershipEntitlement.fromOverview(initial).effectiveTier,
        MembershipTier.free);
    expect(initial['transactions'], isEmpty);
    expect((initial['plans'] as List).map((p) => p['planId']).toSet(),
        {'basic', 'premium'});
    await expectLater(repo.quote('free', ''), throwsStateError);
    await expectLater(repo.quote('elite', ''), throwsStateError);
    await repo.checkout('basic', '', 'purchase', renewal: false);
    expect(MembershipEntitlement.fromOverview(await repo.load()).effectiveTier,
        MembershipTier.free);
    await repo.simulate('purchase');
    final paid = MembershipEntitlement.fromOverview(await repo.load());
    expect(paid.effectiveTier, MembershipTier.basic);
    expect(paid.paidStatus, PaidMembershipStatus.active);
    await repo.simulate('purchase');
    expect(
        MembershipEntitlement.fromOverview(await repo.load())
            .paidExpiresAtMillis,
        paid.paidExpiresAtMillis);
    await repo.checkout('basic', '', 'renewal', renewal: true);
    await repo.simulate('renewal');
    expect(
        MembershipEntitlement.fromOverview(await repo.load())
            .paidExpiresAtMillis,
        paid.paidExpiresAtMillis! + const Duration(days: 30).inMilliseconds);
  });
}
