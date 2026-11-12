import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/rewards_check_in_page.dart';
import 'reward_journey_test.dart' as rewards;
import 'app_check_in_test.dart' as check;

final rewardsNow = DateTime.utc(2026, 10, 26, 4);
final rewardsScope = SessionScope(userId: 'member', organizationId: 'gainpath');

class ConsumerReceipts extends rewards.JourneyRewards {
  int reads = 0;
  bool fails = false, historyFails = false;
  Completer<PointsHistorySnapshot>? delayed;
  PointsHistorySnapshot data =
      PointsHistorySnapshot(balance: 125, reconciled: false, entries: [
    PointsHistoryEntry(
        id: 'earned',
        source: 'app_check_in',
        title: 'Daily check-in',
        points: 50,
        occurredAtMillis: rewardsNow.millisecondsSinceEpoch),
    PointsHistoryEntry(
        id: 'spent',
        source: 'redemption',
        title: 'Training towel',
        points: -25,
        occurredAtMillis: rewardsNow.millisecondsSinceEpoch,
        redemptionId: 'towel'),
    PointsHistoryEntry(
        id: 'demo',
        source: 'mini_game_participation',
        title: 'Demo participation',
        wallet: 'demo',
        points: 999,
        occurredAtMillis: rewardsNow.millisecondsSinceEpoch),
    PointsHistoryEntry(
        id: 'old',
        source: 'manual_credit',
        title: 'Earlier credit',
        points: 200,
        occurredAtMillis: rewardsNow
            .subtract(const Duration(days: 40))
            .millisecondsSinceEpoch),
  ]);
  @override
  Future<PointsHistorySnapshot> pointsHistory() async {
    reads++;
    if (delayed != null) return delayed!.future;
    if (fails || historyFails) throw StateError('offline');
    return data;
  }

  @override
  Future<VerifiedRewardsSnapshot> overview() async {
    if (fails) throw StateError('offline');
    return super.overview();
  }
}

AppCheckInState consumerCheckIn(
        {bool claimed = false,
        AppCheckInStatus status = AppCheckInStatus.ready}) =>
    AppCheckInState(
        status: status,
        snapshot: AppCheckInSnapshot.fromJson(
            check.snapshotJson(rewardsScope, claimed: claimed), rewardsScope));
Widget consumerPage(ConsumerReceipts repo,
        {AppCheckInState? state,
        Future<void> Function()? claim,
        Future<void> Function()? refresh,
        Key? pageKey}) =>
    MaterialApp(
        home: RewardsCheckInPage(
            key: pageKey,
            repository: repo,
            checkIn: state ?? consumerCheckIn(),
            now: () => rewardsNow,
            claimCheckIn: claim ?? () async {},
            refreshCheckIn: refresh ?? () async {}));

void main() {
  testWidgets(
      'receipt endpoint failure retains independent confirmed wallet balance',
      (t) async {
    final repo = ConsumerReceipts()..historyFails = true;
    await t.pumpWidget(consumerPage(repo));
    await t.pumpAndSettle();
    expect(find.text('100'), findsOneWidget);
    expect(
        find.textContaining('balance is confirmed separately'), findsOneWidget);
    await t.scrollUntilVisible(
        find.text('Reward receipts unavailable. Retry to load your activity.'),
        200);
    expect(find.text('Recorded earnings: +0 points'), findsNothing);
  });
  testWidgets('available balance, earned and spent are distinct real receipts',
      (t) async {
    final repo = ConsumerReceipts();
    await t.pumpWidget(consumerPage(repo));
    await t.pumpAndSettle();
    expect(find.text('Rewards & Check-in'), findsOneWidget);
    expect(find.text('125'), findsOneWidget);
    expect(find.text('Check-in streak: 0 days'), findsOneWidget);
    expect(repo.redemptions, 0);
    await t.scrollUntilVisible(find.text('Recorded earnings: +50 points'), 200);
    expect(find.text('Recorded spending: 25 points'), findsOneWidget);
    expect(find.textContaining('history is incomplete'), findsOneWidget);
    expect(find.text('Demo participation'), findsNothing);
    expect(find.text('Earlier credit'), findsNothing);
    expect(repo.reads, 1);
  });
  testWidgets(
      'loading and offline retry never invent zero; refresh preserves data',
      (t) async {
    final repo = ConsumerReceipts()..fails = true;
    await t.pumpWidget(consumerPage(repo));
    await t.pumpAndSettle();
    expect(find.text('125'), findsNothing);
    expect(find.text('—'), findsOneWidget);
    repo.fails = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('125'), findsOneWidget);
    repo.fails = true;
    await t.tap(find.byTooltip('Refresh rewards and check-in'));
    await t.pumpAndSettle();
    expect(find.text('125'), findsOneWidget);
    expect(find.textContaining('Showing your last loaded balance'),
        findsOneWidget);
  });
  testWidgets(
      'concurrent pull refresh coalesces receipt reads and keeps loading state',
      (t) async {
    final repo = ConsumerReceipts()
      ..delayed = Completer<PointsHistorySnapshot>();
    await t.pumpWidget(consumerPage(repo));
    await t.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final refresh =
        t.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh;
    final a = refresh(), b = refresh();
    await t.pump();
    expect(repo.reads, 1);
    repo.delayed!.complete(repo.data);
    await a;
    await b;
    await t.pumpAndSettle();
    expect(find.text('125'), findsOneWidget);
  });
  testWidgets(
      'claim is explicit, repeated taps only submit once; completed state disables claim',
      (t) async {
    final repo = ConsumerReceipts(), wait = Completer<void>();
    var claims = 0;
    await t.pumpWidget(consumerPage(repo, claim: () async {
      claims++;
      await wait.future;
    }));
    await t.pumpAndSettle();
    expect(claims, 0);
    final button = find.text('Check in · 50 points');
    await t.tap(button);
    await t.tap(button);
    await t.pump();
    expect(claims, 1);
    wait.complete();
    await t.pumpAndSettle();
    await t
        .pumpWidget(consumerPage(repo, state: consumerCheckIn(claimed: true)));
    await t.pumpAndSettle();
    expect(find.textContaining('Checked in today'), findsOneWidget);
    expect(button, findsNothing);
  });
  testWidgets('history destination returns to refreshed receipts', (t) async {
    final repo = ConsumerReceipts();
    await t.pumpWidget(consumerPage(repo));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('View reward history'), 250);
    await t.tap(find.text('View reward history'));
    await t.pumpAndSettle();
    expect(find.text('Points History'), findsOneWidget);
    expect(repo.reads, 2);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(repo.reads, 3);
    expect(find.text('Rewards & Check-in'), findsOneWidget);
  });
  testWidgets(
      'account-key replacement discards late response and captured balance',
      (t) async {
    final first = ConsumerReceipts()
      ..delayed = Completer<PointsHistorySnapshot>();
    await t.pumpWidget(consumerPage(first, pageKey: const ValueKey('first')));
    await t.pump();
    first.active = false;
    final second = ConsumerReceipts()
      ..data = const PointsHistorySnapshot(
          balance: 7, entries: [], reconciled: false);
    await t.pumpWidget(consumerPage(second, pageKey: const ValueKey('second')));
    await t.pumpAndSettle();
    first.delayed!.complete(first.data);
    await t.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    expect(find.text('125'), findsNothing);
    await t.scrollUntilVisible(
        find.text('Recorded earnings: Unavailable'), 200);
    expect(find.text('Recorded spending: Unavailable'), findsOneWidget);
  });
  testWidgets(
      'background invalidates in-flight response and resume refreshes once',
      (t) async {
    final repo = ConsumerReceipts()
      ..delayed = Completer<PointsHistorySnapshot>();
    await t.pumpWidget(consumerPage(repo));
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repo.delayed!.complete(repo.data);
    await t.pumpAndSettle();
    expect(find.text('125'), findsNothing);
    repo.delayed = null;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(repo.reads, 2);
    expect(find.text('125'), findsOneWidget);
  });
  test('check-in refresh requests share an overview flight', () async {
    final repo = check.FakeCheckIn(rewardsScope)
      ..overviewDelay = Completer<void>();
    final cubit =
        AppCheckInCubit(repository: repo, activeScope: () => rewardsScope);
    final a = cubit.refresh(), b = cubit.refresh();
    expect(identical(a, b), true);
    repo.overviewDelay!.complete();
    await a;
    await b;
    expect(cubit.state.status, AppCheckInStatus.ready);
    await cubit.close();
  });
}
