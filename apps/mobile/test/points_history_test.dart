import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/points_history_screen.dart';

class HistoryRepo extends VerifiedRewardsRepository {
  @override
  bool get connected => false;
  @override
  bool current = true;
  bool fail = false;
  @override
  Future<PointsHistorySnapshot> pointsHistory() async {
    if (fail) throw const FormatException('unavailable');
    return const PointsHistorySnapshot(
        balance: 9520,
        demoBalance: 0,
        demoReconciled: true,
        reconciled: true,
        entries: [
          PointsHistoryEntry(
              id: 'game',
              source: 'mini_game_participation',
              title: 'Move & Catch participation',
              points: 20,
              occurredAtMillis: 3000,
              wallet: 'spendable'),
          PointsHistoryEntry(
              id: 'credit',
              source: 'manual_credit',
              title: 'Manual points credit',
              points: 10000,
              occurredAtMillis: 2000),
          PointsHistoryEntry(
              id: 'spent',
              source: 'redemption',
              title: 'Protein Powder',
              points: -500,
              occurredAtMillis: 1000,
              redemptionId: 'voucher')
        ]);
  }

  @override
  Future<VerifiedRewardsSnapshot> overview() => throw UnimplementedError();
  @override
  Future<void> award(String id) => throw UnimplementedError();
  @override
  Future<VerifiedRewardRedemption> redeem(
          {required String itemId,
          required String requestId,
          int? expectedPointCost,
          int? expectedItemRevision}) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('history fits a small screen with large text', (t) async {
    t.view.physicalSize = const Size(320, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: PointsHistoryScreen(repository: HistoryRepo())));
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, -600));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('history filters confirmed earned and spent entries', (t) async {
    final r = HistoryRepo();
    await t.pumpWidget(MaterialApp(home: PointsHistoryScreen(repository: r)));
    await t.pumpAndSettle();
    expect(find.text('9520 points'), findsOneWidget);
    expect(find.text('+10000'), findsOneWidget);
    expect(find.text('-500'), findsOneWidget);
    await t.tap(find.text('Earned'));
    await t.pumpAndSettle();
    expect(find.text('Protein Powder'), findsNothing);
    await t.tap(find.text('Spent'));
    await t.pumpAndSettle();
    expect(find.text('Manual points credit'), findsNothing);
    expect(find.text('Protein Powder'), findsOneWidget);
  });
  testWidgets('one history filters mini-game earnings by source', (t) async {
    await t.pumpWidget(
        MaterialApp(home: PointsHistoryScreen(repository: HistoryRepo())));
    await t.pumpAndSettle();
    expect(find.textContaining('demo'), findsNothing);
    expect(find.text('Move & Catch participation'), findsOneWidget);
    await t.tap(find.byKey(const Key('history-source-filter')));
    await t.pumpAndSettle();
    await t.tap(find.text('Mini-games').last);
    await t.pumpAndSettle();
    expect(find.text('Move & Catch participation'), findsOneWidget);
    expect(find.text('Manual points credit'), findsNothing);
    await t.tap(find.text('Spent'));
    await t.pumpAndSettle();
    expect(find.text('No transactions in this filter.'), findsOneWidget);
    expect(find.text('Demo points cannot be spent in the reward shop.'),
        findsNothing);
  });
  test(
      'unified parser reconciles separately and rejects a demo entry disguised as spendable',
      () {
    final data = <String, dynamic>{
      'schemaVersion': 2,
      'organizationId': 'o',
      'memberId': 'm',
      'balance': 50,
      'demoBalance': 20,
      'reconciled': true,
      'demoReconciled': true,
      'resolvedAtMillis': 2000,
      'entries': [
        {
          'id': 'participation:one',
          'source': 'mini_game_participation',
          'title': 'Move & Catch participation',
          'points': 20,
          'occurredAtMillis': 1500,
          'redemptionId': null,
          'wallet': 'demo'
        },
        {
          'id': 'claims:one',
          'source': 'app_check_in',
          'title': 'Daily check-in',
          'points': 50,
          'occurredAtMillis': 1000,
          'redemptionId': null,
          'wallet': 'spendable'
        }
      ]
    };
    final parsed = PointsHistorySnapshot.fromJson(data,
        organizationId: 'o', memberId: 'm');
    expect(parsed.demoBalance, 20);
    expect(parsed.entries.first.wallet, 'demo');
    (data['entries'] as List).first['wallet'] = 'spendable';
    expect(
        () => PointsHistorySnapshot.fromJson(data,
            organizationId: 'o', memberId: 'm'),
        throwsFormatException);
  });
  testWidgets(
      'history error retries and session invalidation hides private entries',
      (t) async {
    final r = HistoryRepo()..fail = true;
    await t.pumpWidget(MaterialApp(home: PointsHistoryScreen(repository: r)));
    await t.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    r.fail = false;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('+10000'), findsOneWidget);
    r.current = false;
    await t.pumpWidget(MaterialApp(home: PointsHistoryScreen(repository: r)));
    expect(find.text('+10000'), findsNothing);
  });
  test('parser rejects foreign ownership and wrong signed transaction', () {
    final d = {
      'schemaVersion': 1,
      'organizationId': 'o',
      'memberId': 'm',
      'balance': 50,
      'reconciled': true,
      'resolvedAtMillis': 2000,
      'entries': [
        {
          'id': 'claims:one',
          'source': 'app_check_in',
          'title': 'Daily check-in',
          'points': 50,
          'occurredAtMillis': 1000,
          'redemptionId': null
        }
      ]
    };
    expect(
        PointsHistorySnapshot.fromJson(d, organizationId: 'o', memberId: 'm')
            .entries
            .single
            .points,
        50);
    expect(
        () => PointsHistorySnapshot.fromJson(d,
            organizationId: 'o', memberId: 'other'),
        throwsFormatException);
  });
}
