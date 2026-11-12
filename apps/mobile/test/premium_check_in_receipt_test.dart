import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'app_check_in_test.dart' as fixture;

void main() {
  final scope = SessionScope(organizationId: 'gainpath', userId: 'member');
  test('configured bonus receipt keeps total and base provenance', () {
    final raw = fixture.snapshotJson(scope, claimed: true);
    final c =
        Map<String, dynamic>.from((raw['recentClaims'] as List).first as Map);
    raw['recentClaims'] = [c];
    c.addAll({
      'points': 67,
      'basePoints': 50,
      'premiumBonusPoints': 17,
      'premiumBonusPolicyVersion': 'test-only-v1'
    });
    raw['balance'] = 67;
    final claim = AppCheckInSnapshot.fromJson(raw, scope).recentClaims.single;
    expect(claim.points, 67);
  });
  test('unproven extra check-in points are rejected', () {
    final raw = fixture.snapshotJson(scope, claimed: true);
    ((raw['recentClaims'] as List).first as Map)['points'] = 67;
    expect(
        () => AppCheckInSnapshot.fromJson(raw, scope), throwsFormatException);
  });
}
