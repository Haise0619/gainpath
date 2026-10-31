import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reward_shop_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/voucher_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/my_rewards_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

class JourneyRewards extends VerifiedRewardsRepository {
  bool active = true, shopFails = false, voucherFails = false, live = false;
  int voucherReads = 0, historyReads = 0, redemptions = 0;
  Completer<VerifiedRewardRedemption>? pending;
  String tier = 'basic';
  String state = 'issued';
  final cursors = <String?>[];
  int? acceptedCost;
  int? acceptedRevision;
  @override
  bool get connected => live;
  @override
  bool get current => active;
  VerifiedRewardRedemption row([String id = 'voucher']) =>
      VerifiedRewardRedemption(
          redemptionId: id,
          itemId: 'item',
          title: 'Gym towel',
          points: 50,
          status: state,
          issuedAtMillis: 1800000000000,
          organizationId: 'gainpath',
          expiresAtMillis: 1802592000000,
          description: 'Soft training towel',
          conditions: 'One towel per voucher.',
          collectionInstructions: 'Collect at reception.');
  @override
  Future<VerifiedRewardsSnapshot> overview() async {
    if (shopFails) throw StateError('Unavailable policy');
    return VerifiedRewardsSnapshot(
        available: true,
        balance: 100,
        effectiveTier: tier,
        canRedeem: tier != 'free',
        items: const [
          VerifiedRewardItem(
              itemId: 'item',
              title: 'Gym towel',
              pointCost: 50,
              stock: 2,
              premiumOnly: false,
              description: 'Soft training towel',
              conditions: 'One towel per voucher.',
              collectionInstructions: 'Collect at reception.',
              validityDays: 30,
              revision: 1)
        ],
        redemptions: []);
  }

  @override
  Future<VerifiedRewardHistoryPage> history({String? afterId}) async {
    historyReads++;
    cursors.add(afterId);
    return VerifiedRewardHistoryPage(
        [row(afterId == null ? 'voucher' : 'voucher2')],
        nextCursor: afterId == null ? 'voucher' : null,
        resolvedAtMillis: 1800000000000);
  }

  @override
  Future<VerifiedRewardRedemption> voucher(String redemptionId) async {
    voucherReads++;
    if (voucherFails) throw StateError('Offline');
    return pending?.future ?? Future.value(row(redemptionId));
  }

  @override
  Future<VerifiedRewardRedemption> redeem(
      {required String itemId,
      required String requestId,
      int? expectedPointCost,
      int? expectedItemRevision}) async {
    redemptions++;
    acceptedCost = expectedPointCost;
    acceptedRevision = expectedItemRevision;
    return row();
  }

  @override
  Future<void> award(String eventId) async {}
}

void main() {
  testWidgets(
      'Used and Expired filters use server status and refresh replaces the loaded page',
      (t) async {
    final repo = JourneyRewards()..state = 'fulfilled';
    await t.pumpWidget(MaterialApp(home: MyRewardsScreen(repository: repo)));
    await t.pumpAndSettle();
    expect(find.text('Gym towel'), findsNothing);
    await t.tap(find.text('Used'));
    await t.pumpAndSettle();
    expect(find.text('Gym towel'), findsOneWidget);
    repo.state = 'expired';
    await t.tap(find.byTooltip('Refresh my rewards'));
    await t.pumpAndSettle();
    expect(find.text('Gym towel'), findsNothing);
    await t.tap(find.text('Expired'));
    await t.pumpAndSettle();
    expect(find.text('Gym towel'), findsOneWidget);
    expect(repo.historyReads, 2);
  });
  testWidgets(
      'failed refresh removes the previously displayed QR and resume revalidates it',
      (t) async {
    final repo = JourneyRewards();
    await t.pumpWidget(MaterialApp(
        home: VoucherScreen(redemption: repo.row(), repository: repo)));
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    repo.voucherFails = true;
    await t.tap(find.byTooltip('Refresh voucher'));
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('could not be confirmed'), findsOneWidget);
    repo.voucherFails = false;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(repo.voucherReads, 3);
    expect(find.byType(QrImageView), findsOneWidget);
  });
  testWidgets(
      'issued voucher remains readable for an effective Free member after paid membership expires',
      (t) async {
    final repo = JourneyRewards()
      ..tier = 'free'
      ..shopFails = true;
    await t.pumpWidget(MaterialApp(home: MyRewardsScreen(repository: repo)));
    await t.pumpAndSettle();
    await t.tap(find.text('Gym towel'));
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    await t.scrollUntilVisible(
        find.textContaining('even if your membership expires'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(
        find.textContaining('even if your membership expires'), findsOneWidget);
    expect(repo.redemptions, 0);
  });
  testWidgets('logout removes voucher content and stops its refresh timer',
      (t) async {
    late AuthBloc auth;
    await t.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final repo = JourneyRewards()..live = true;
    await t.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: VoucherScreen(redemption: repo.row(), repository: repo))));
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    repo.active = false;
    await t.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Gym towel'), findsNothing);
    await t.pump(const Duration(seconds: 61));
    expect(repo.voucherReads, 1);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(auth.close);
  });
  testWidgets(
      'Premium confirmation refreshes the shared balance even if refresh fails',
      (t) async {
    final repo = JourneyRewards()..tier = 'premium';
    var refreshes = 0;
    await t.pumpWidget(MaterialApp(
        home: RewardShopScreen(
            repository: repo,
            onBalanceChanged: () async {
              refreshes++;
              throw StateError('Wallet offline');
            })));
    await t.pumpAndSettle();
    await t.tap(find.text('Redeem'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Confirm redemption'), 300);
    await t.ensureVisible(find.text('Confirm redemption'));
    await t.pumpAndSettle();
    await t.tap(find.text('Confirm redemption'));
    await t.pumpAndSettle();
    expect(repo.redemptions, 1);
    expect(repo.acceptedCost, 50);
    expect(repo.acceptedRevision, 1);
    expect(refreshes, 1);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
        find.textContaining('Redemption could not be confirmed'), findsNothing);
  });
  testWidgets(
      'shop, details and My Rewards support small screens with large text',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repo = JourneyRewards();
    await t.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640), textScaler: TextScaler.linear(2)),
            child: child!),
        home: RewardShopScreen(repository: repo)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('View details'), 250);
    await t.ensureVisible(find.text('View details'));
    await t.pumpAndSettle();
    await t.tap(find.text('View details'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Confirm redemption'), 250);
    await t.ensureVisible(find.text('Confirm redemption'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.text('My Rewards'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Gym towel'), 200);
    expect(t.takeException(), isNull);
  });
  testWidgets('a failed pull-to-refresh stays within shop unavailable UI',
      (t) async {
    final repo = JourneyRewards();
    await t.pumpWidget(MaterialApp(home: RewardShopScreen(repository: repo)));
    await t.pumpAndSettle();
    repo.shopFails = true;
    await t.drag(find.byType(ListView), const Offset(0, 400));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Rewards unavailable'), findsOneWidget);
    expect(find.text('My Rewards'), findsOneWidget);
  });
  testWidgets(
      'My Rewards remains reachable when shop fails and pages independently',
      (t) async {
    final repo = JourneyRewards()..shopFails = true;
    await t.pumpWidget(MaterialApp(home: RewardShopScreen(repository: repo)));
    await t.pumpAndSettle();
    await t.tap(find.text('My Rewards'));
    await t.pumpAndSettle();
    expect(find.text('Gym towel'), findsOneWidget);
    expect(find.text('Available'), findsWidgets);
    await t.tap(find.text('Load more'));
    await t.pumpAndSettle();
    expect(repo.cursors, [null, 'voucher']);
    expect(find.text('Gym towel'), findsNWidgets(2));
  });
  testWidgets(
      'voucher waits for fresh status, renders real scoped QR and refresh hides used QR',
      (t) async {
    final repo = JourneyRewards()
      ..pending = Completer<VerifiedRewardRedemption>();
    await t.pumpWidget(MaterialApp(
        home: VoucherScreen(redemption: repo.row(), repository: repo)));
    await t.pump();
    expect(repo.voucherReads, 1);
    expect(find.byType(QrImageView), findsNothing);
    repo.pending!.complete(repo.row());
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    final qr = t.widget<QrImageView>(find.byType(QrImageView));
    expect(qr.key, const ValueKey('gainpath-reward:v1:gainpath:voucher'));
    expect(qr.backgroundColor, Colors.white);
    expect(find.text('One towel per voucher.'), findsOneWidget);
    repo.pending = null;
    repo.state = 'fulfilled';
    await t.tap(find.byTooltip('Refresh voucher'));
    await t.pumpAndSettle();
    expect(find.text('Used'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });
  testWidgets(
      'expired voucher keeps points spent and never offers collection QR',
      (t) async {
    final repo = JourneyRewards()..state = 'expired';
    await t.pumpWidget(MaterialApp(
        home: VoucherScreen(redemption: repo.row(), repository: repo)));
    await t.pumpAndSettle();
    expect(find.text('Expired'), findsOneWidget);
    expect(find.textContaining('remain spent'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });
  testWidgets('small screen large text voucher and stale session remain safe',
      (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final repo = JourneyRewards();
    await t.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 640), textScaler: TextScaler.linear(2)),
            child: child!),
        home: VoucherScreen(redemption: repo.row(), repository: repo)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    repo.active = false;
    await t.tap(find.byTooltip('Refresh voucher'));
    await t.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Rewards unavailable for this session.'), findsOneWidget);
  });
  testWidgets(
      'Basic reviews exact cost and validity before explicit confirmation',
      (t) async {
    final repo = JourneyRewards();
    await t.pumpWidget(MaterialApp(home: RewardShopScreen(repository: repo)));
    await t.pumpAndSettle();
    await t.tap(find.text('Redeem'));
    await t.pumpAndSettle();
    expect(repo.redemptions, 0);
    expect(find.textContaining('30 days'), findsWidgets);
    await t.scrollUntilVisible(find.textContaining('remain spent'), 200);
    expect(find.textContaining('remain spent'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Confirm redemption'), 300);
    await t.ensureVisible(find.text('Confirm redemption'));
    await t.pumpAndSettle();
    await t.tap(find.text('Confirm redemption'));
    await t.pumpAndSettle();
    expect(repo.redemptions, 1);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
