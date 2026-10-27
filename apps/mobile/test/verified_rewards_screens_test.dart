import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_shop_screen.dart';

class RewardsFake extends VerifiedRewardsRepository {
  @override
  bool get current => true;
  @override
  bool get connected => false;
  bool fail = false;
  final requests = <String>[];
  VerifiedRewardRedemption? saved;
  @override
  Future<VerifiedRewardRedemption> voucher(String redemptionId) async => saved!;
  VerifiedRewardsSnapshot value = const VerifiedRewardsSnapshot(
      available: false,
      balance: null,
      effectiveTier: 'free',
      canRedeem: false,
      items: [],
      redemptions: []);
  @override
  Future<VerifiedRewardsSnapshot> overview() async => value;
  @override
  Future<void> award(String eventId) async {}
  @override
  Future<VerifiedRewardRedemption> redeem(
      {required String itemId,
      required String requestId,
      int? expectedPointCost,
      int? expectedItemRevision}) async {
    requests.add(requestId);
    if (fail) throw StateError('Synthetic failure');
    return saved = const VerifiedRewardRedemption(
        redemptionId: 'trusted-server-voucher',
        itemId: 'item',
        title: 'Synthetic reward',
        points: 5,
        status: 'issued',
        issuedAtMillis: 1800000000000);
  }
}

void main() {
  const item = VerifiedRewardItem(
      itemId: 'item',
      title: 'Synthetic reward',
      pointCost: 5,
      stock: 1,
      premiumOnly: false);
  testWidgets(
      'unconfigured rewards show actual unavailable state without fake points or products',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RewardShopScreen(connected: true, repository: RewardsFake())));
    await tester.pumpAndSettle();
    expect(find.text('Rewards unavailable'), findsOneWidget);
    expect(find.text('No verified balance yet.'), findsOneWidget);
    expect(find.text('Redeem'), findsNothing);
    expect(find.text('-'), findsNothing);
  });
  testWidgets('Free retains verified points but has no enabled redemption',
      (tester) async {
    final repo = RewardsFake()
      ..value = const VerifiedRewardsSnapshot(
          available: true,
          balance: 25,
          effectiveTier: 'free',
          canRedeem: false,
          items: [item],
          redemptions: []);
    await tester.pumpWidget(
        MaterialApp(home: RewardShopScreen(connected: true, repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('25 verified points'), findsOneWidget);
    expect(find.textContaining('Basic or Premium'), findsWidgets);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Redeem'))
            .onPressed,
        isNull);
  });
  testWidgets(
      'failed redemption shows no invented voucher and retries the same request',
      (tester) async {
    final repo = RewardsFake()..fail = true;
    repo.value = const VerifiedRewardsSnapshot(
        available: true,
        balance: 5,
        effectiveTier: 'basic',
        canRedeem: true,
        items: [item],
        redemptions: []);
    await tester.pumpWidget(
        MaterialApp(home: RewardShopScreen(connected: true, repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Redeem'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Confirm redemption'), 300);
    await tester.tap(find.text('Confirm redemption'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Redemption could not be confirmed'),
        findsOneWidget);
    expect(find.text('GP-4K7M-92XA'), findsNothing);
    repo.fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Redeem'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Confirm redemption'), 300);
    await tester.tap(find.text('Confirm redemption'));
    await tester.pumpAndSettle();
    expect(repo.requests.length, 2);
    expect(repo.requests[0], repo.requests[1]);
    expect(find.text('trusted-server-voucher'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2_rounded), findsNothing);
  });
}
