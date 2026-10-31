import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_shop_screen.dart';
import 'reward_journey_test.dart' show JourneyRewards;

void main() {
  testWidgets(
      'redemption review shows confirmed balance stock cost before single confirmation',
      (t) async {
    final repo = JourneyRewards();
    await t.pumpWidget(MaterialApp(home: RewardShopScreen(repository: repo)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('View details'), 300);
    await t.tap(find.text('View details'));
    await t.pumpAndSettle();
    expect(find.text('100 points available'), findsOneWidget);
    expect(find.text('2 available · stock checked at confirmation'),
        findsOneWidget);
    expect(find.text('50 points after redemption'), findsOneWidget);
    expect(repo.redemptions, 0);
    await t.scrollUntilVisible(find.text('Confirm redemption'), 250);
    await t.tap(find.text('Confirm redemption'));
    await t.pumpAndSettle();
    expect(repo.redemptions, 1);
    expect(repo.acceptedCost, 50);
    expect(repo.acceptedRevision, 1);
  });
}
