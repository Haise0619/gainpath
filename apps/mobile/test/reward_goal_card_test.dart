import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/domain/reward_goal.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_goal_card.dart';
import 'reward_journey_test.dart' show JourneyRewards;

class Goals implements RewardGoalStore {
  String? selected;
  bool fail = false;
  @override
  Future<String?> load(SessionScope scope) async => selected;
  @override
  Future<void> save(SessionScope scope, String? itemId,
      {required bool Function() isCurrent}) async {
    if (fail) throw StateError('disk');
    if (isCurrent()) selected = itemId;
  }
}

class GoalRewards extends JourneyRewards {
  VerifiedRewardsSnapshot? data;
  Completer<VerifiedRewardsSnapshot>? waiting;
  @override
  Future<VerifiedRewardsSnapshot> overview() =>
      waiting?.future ?? (data == null ? super.overview() : Future.value(data));
}

void main() {
  final scope = SessionScope(userId: 'a', organizationId: 'gainpath');
  Future<void> show(WidgetTester t, GoalRewards r, Goals g,
      {double scale = 1}) async {
    await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
            data:
                MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: RewardGoalCard(
                    repository: r, scope: scope, store: g, onShop: () {})))));
    await t.pumpAndSettle();
  }

  testWidgets(
      'choose published reward and show confirmed balance without reserving stock',
      (t) async {
    final r = GoalRewards(), g = Goals();
    await show(t, r, g);
    await t.tap(find.text('Choose goal'));
    await t.pumpAndSettle();
    await t.tap(find.text('Gym towel'));
    await t.pumpAndSettle();
    expect(g.selected, 'item');
    expect(find.text('100 / 50 points'), findsOneWidget);
    expect(
        find.textContaining('No stock or price reservation'), findsOneWidget);
    expect(r.redemptions, 0);
  });
  testWidgets('retired goal and unknown balance never invent progress',
      (t) async {
    final r = GoalRewards()
      ..data = const VerifiedRewardsSnapshot(
          available: true,
          balance: null,
          effectiveTier: 'basic',
          canRedeem: true,
          items: [],
          redemptions: []);
    await show(t, r, Goals()..selected = 'retired');
    expect(find.text('Selected reward is no longer available'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets(
      'large text remains readable and failed saving retains prior selection',
      (t) async {
    t.view.physicalSize = const Size(320, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final r = GoalRewards(), g = Goals()..fail = true;
    await show(t, r, g, scale: 2);
    await t.tap(find.text('Choose goal'));
    await t.pumpAndSettle();
    await t.tap(find.text('Gym towel'));
    await t.pumpAndSettle();
    expect(g.selected, isNull);
    expect(find.text('Could not save your goal. Retry.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('known goal with unknown balance shows no invented progress',
      (t) async {
    final r = GoalRewards()
      ..data = const VerifiedRewardsSnapshot(
          available: true,
          balance: null,
          effectiveTier: 'basic',
          canRedeem: true,
          items: [
            VerifiedRewardItem(
                itemId: 'item',
                title: 'Gym towel',
                pointCost: 50,
                stock: 0,
                premiumOnly: false)
          ],
          redemptions: []);
    await show(t, r, Goals()..selected = 'item');
    expect(find.textContaining('Balance unavailable'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('0 /'), findsNothing);
  });
  testWidgets(
      'late goal overview after account ends cannot reveal reward progress',
      (t) async {
    final gate = Completer<VerifiedRewardsSnapshot>();
    final r = GoalRewards()..waiting = gate;
    await t.pumpWidget(MaterialApp(
        home: RewardGoalCard(
            repository: r,
            scope: scope,
            store: Goals()..selected = 'item',
            onShop: () {})));
    await t.pump();
    r.active = false;
    gate.complete(const VerifiedRewardsSnapshot(
        available: true,
        balance: 100,
        effectiveTier: 'basic',
        canRedeem: true,
        items: [
          VerifiedRewardItem(
              itemId: 'item',
              title: 'Private selected towel',
              pointCost: 50,
              stock: 1,
              premiumOnly: false)
        ],
        redemptions: []));
    await t.pumpAndSettle();
    expect(find.text('Private selected towel'), findsNothing);
    expect(find.text('100 / 50 points'), findsNothing);
  });
}
