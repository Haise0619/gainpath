import 'package:test/test.dart';
import 'package:gainpath_domain/src/recommendation/policies/risk_policy.dart';

void main() {
  const policy = RiskPolicy(thresholdPct: 70);

  test('below threshold is High', () => expect(policy.tierFor(69), 'High'));
  test('within 12 points above threshold is Moderate', () {
    expect(policy.tierFor(70), 'Moderate');
    expect(policy.tierFor(81), 'Moderate');
  });
  test('12 or more points above threshold is Low', () => expect(policy.tierFor(82), 'Low'));
}
