import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/domain/reward_goal.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_goal_card.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_details.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'reward_journey_test.dart' show JourneyRewards;
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import '../../../test_support/fyp_render_support.dart';

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
  setUpAll(loadDemoRenderFonts);
  final scope = SessionScope(userId: 'a', organizationId: 'gainpath');
  VerifiedRewardsSnapshot wallet(int balance, {int stock = 2}) =>
      VerifiedRewardsSnapshot(
        available: true,
        balance: balance,
        effectiveTier: 'basic',
        canRedeem: true,
        redemptions: const [],
        items: [
          VerifiedRewardItem(
              itemId: 'item',
              title: 'Training towel and recovery kit',
              pointCost: 500,
              stock: stock,
              premiumOnly: false),
          const VerifiedRewardItem(
              itemId: 'second',
              title: 'Training bottle',
              pointCost: 350,
              stock: 0,
              premiumOnly: false),
        ],
      );
  Future<void> show(WidgetTester t, GoalRewards r, Goals g,
      {double scale = 1,
      Future<void> Function()? onViewPlans,
      VoidCallback? onShop}) async {
    await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
            data:
                MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: RewardGoalCard(
                    repository: r,
                    scope: scope,
                    store: g,
                    onViewPlans: onViewPlans,
                    onShop: onShop ?? () {})))));
    await t.pumpAndSettle();
  }

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('goal and selector fit ${width.toInt()}dp at ${scale}x',
          (t) async {
        t.view.physicalSize = Size(width, 850);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await show(
            t, GoalRewards()..data = wallet(320), Goals()..selected = 'item',
            scale: scale);
        expect(find.text('320 / 500 points'), findsOneWidget);
        expect(find.text('180 points to go'), findsOneWidget);
        expect(
            t
                .widget<LinearProgressIndicator>(
                    find.byType(LinearProgressIndicator))
                .value,
            .64);
        expect(find.byType(RewardCover), findsOneWidget);
        await t.ensureVisible(find.text('Change goal'));
        await t.tap(find.text('Change goal'));
        await t.pumpAndSettle();
        expect(find.byTooltip('Close goal selector'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        await t.scrollUntilVisible(find.textContaining('Out of stock'), 120,
            scrollable: find.byType(Scrollable).last);
        expect(find.textContaining('Out of stock'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('exact threshold opens the existing review without redeeming',
      (t) async {
    final repo = GoalRewards()..data = wallet(500);
    await show(t, repo, Goals()..selected = 'item');
    expect(find.text('Goal reached'), findsOneWidget);
    await t.tap(find.text('View reward'));
    await t.pumpAndSettle();
    expect(find.byType(RewardDetailsScreen), findsOneWidget);
    await t.scrollUntilVisible(find.text('Confirm redemption'), 160,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Confirm redemption'), findsOneWidget);
    expect(repo.redemptions, 0);
  });

  testWidgets('out of stock and failed removal preserve the saved selection',
      (t) async {
    final repo = GoalRewards()..data = wallet(1000, stock: 0);
    final store = Goals()
      ..selected = 'item'
      ..fail = true;
    await show(t, repo, store);
    expect(find.text('Goal reached'), findsNothing);
    expect(find.text('Currently out of stock'), findsOneWidget);
    await t.tap(find.text('Change goal'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove goal'));
    await t.pumpAndSettle();
    expect(store.selected, 'item');
    expect(find.text('Could not save your goal. Retry.'), findsOneWidget);
    store.fail = false;
    await t.tap(find.text('Change goal'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remove goal'));
    await t.pumpAndSettle();
    expect(store.selected, isNull);
    expect(find.text('Choose your reward goal'), findsOneWidget);
  });

  testWidgets('render wallet goals and selector with test catalog data',
      (t) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    addTearDown(t.view.reset);

    Future<void> capture(GlobalKey key, String name) async {
      final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../../build/reward-wallet-redesign/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final (name, balance, selection) in [
      ('reached', 9970, 'item'),
      ('incomplete', 320, 'item'),
      ('no-goal', 320, null),
    ]) {
      final key = GlobalKey();
      final repo = GoalRewards()..data = wallet(balance);
      await t.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildMemberTypographyTheme(),
          home: AppCheckInDashboard(
            state: const AppCheckInState(status: AppCheckInStatus.unavailable),
            onClaim: () async {},
            onRefresh: () async {},
            gamesSection: const SizedBox.shrink(),
            weeklyRankSection: const SizedBox.shrink(),
            rewardGoalSection: RewardGoalCard(
                repository: repo,
                scope: scope,
                store: Goals()..selected = selection,
                onShop: () {}),
          ),
        ),
      ));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Points & vouchers'));
      await t.pumpAndSettle();
      await capture(key, name);
      if (name == 'reached') {
        await t.ensureVisible(find.text('Change goal'));
        await t.tap(find.text('Change goal'));
        await t.pumpAndSettle();
        await capture(key, 'selector');
        await t.tap(find.byTooltip('Close goal selector'));
        await t.pumpAndSettle();
      }
    }
  });

  testWidgets('Free sees a published product preview with locked redemption',
      (t) async {
    var plans = 0, shops = 0;
    final r = GoalRewards()
      ..data = const VerifiedRewardsSnapshot(
          available: true,
          balance: 0,
          effectiveTier: 'free',
          canRedeem: false,
          items: [
            VerifiedRewardItem(
                itemId: 'bottle',
                title: 'Training bottle',
                pointCost: 250,
                stock: 3,
                premiumOnly: false)
          ],
          redemptions: []);
    final g = Goals();
    await show(t, r, g, onViewPlans: () async {
      plans++;
    }, onShop: () {
      shops++;
    });
    expect(find.text('My Reward Goal'), findsOneWidget);
    expect(find.text('Training bottle'), findsOneWidget);
    expect(find.text('250 points'), findsOneWidget);
    expect(find.text('Choose goal'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await t.ensureVisible(find.text('View membership plans'));
    await t.tap(find.text('View membership plans'));
    expect(plans, 1);
    await t.ensureVisible(find.text('Browse rewards'));
    await t.tap(find.text('Browse rewards'));
    expect(shops, 1);
    expect(r.redemptions, 0);
    expect(g.selected, isNull);
  });

  testWidgets(
      'Free empty catalog stays honest and unknown tier is not treated as Free',
      (t) async {
    for (final tier in ['free', null]) {
      final r = GoalRewards()
        ..data = VerifiedRewardsSnapshot(
            available: true,
            balance: null,
            effectiveTier: tier,
            canRedeem: false,
            items: const [],
            redemptions: const []);
      await show(t, r, Goals());
      expect(find.text('View membership plans'),
          tier == 'free' ? findsOneWidget : findsNothing);
      expect(find.text('Find your next reward'),
          tier == 'free' ? findsOneWidget : findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(r.redemptions, 0);
    }
  });
  testWidgets(
      'Free Premium-only product preview does not promise Basic redemption',
      (t) async {
    final r = GoalRewards()
      ..data = const VerifiedRewardsSnapshot(
          available: true,
          balance: 100,
          effectiveTier: 'free',
          canRedeem: false,
          items: [
            VerifiedRewardItem(
                itemId: 'premium',
                title: 'Premium bottle',
                pointCost: 400,
                stock: 1,
                premiumOnly: true)
          ],
          redemptions: []);
    await show(t, r, Goals());
    expect(find.text('Premium Exclusive'), findsOneWidget);
    expect(
        find.text(
            'Keep saving your points. This reward is exclusive to Premium members.'),
        findsOneWidget);
    expect(find.textContaining('redemption with Basic'), findsNothing);
  });
  testWidgets(
      'choose published reward and show confirmed balance without reserving stock',
      (t) async {
    final r = GoalRewards(), g = Goals();
    await show(t, r, g);
    await t.tap(find.text('Browse rewards'));
    await t.pumpAndSettle();
    await t.tap(find.text('Gym towel'));
    await t.pumpAndSettle();
    expect(g.selected, 'item');
    expect(find.text('Goal reached'), findsOneWidget);
    expect(find.text('Verified balance · 100 pts'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
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
    await t.tap(find.text('Browse rewards'));
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
