import 'package:gainpath_data/membership.dart';
import 'package:test/test.dart';

void main() {
  test('changing a default membership cannot change another scope', () {
    final first = InMemoryMembershipRepository();
    final second = InMemoryMembershipRepository();

    first.currentPlanId = 'elite';
    first.autoRenew = false;

    expect(second.currentPlanId, 'premium');
    expect(second.autoRenew, isTrue);
    expect(InMemoryMembershipRepository().currentPlanId, 'premium');
  });
}
