import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_admin_web/features/gamification/reward_fulfilment_repository.dart';
import 'package:gainpath_admin_web/features/gamification/presentation/admin/reward_fulfilment_panel.dart';

class _Repo implements RewardFulfilmentRepository {
  int writes = 0;
  @override
  bool current = true;
  @override
  Future<AdminRewardVoucher> inspect(String id) async => AdminRewardVoucher(
      memberId: 'member',
      redemption: VerifiedRewardRedemption(
          redemptionId: id,
          itemId: 'real-item',
          title: 'Configured item',
          points: 50,
          status: writes == 0 ? 'issued' : 'fulfilled',
          issuedAtMillis: 1800000000000));
  @override
  Future<AdminRewardVoucher> fulfil(String id) async {
    writes++;
    return inspect(id);
  }
}

void main() {
  testWidgets(
      'inspection never fulfils; explicit action updates issued voucher once',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RewardFulfilmentPanel(repository: repo))));
    await tester.enterText(find.byType(TextField), 'voucher-id');
    await tester.tap(find.text('Check reward voucher'));
    await tester.pumpAndSettle();
    expect(find.text('Configured item'), findsOneWidget);
    expect(repo.writes, 0);
    await tester.tap(find.text('Record fulfilment'));
    await tester.pumpAndSettle();
    expect(repo.writes, 1);
    expect(find.text('Already fulfilled · do not issue again'), findsOneWidget);
    expect(find.text('Record fulfilment'), findsNothing);
  });
  testWidgets('session invalidation hides prior reward details',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RewardFulfilmentPanel(repository: repo))));
    await tester.enterText(find.byType(TextField), 'voucher-id');
    await tester.tap(find.text('Check reward voucher'));
    await tester.pumpAndSettle();
    repo.current = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RewardFulfilmentPanel(repository: repo))));
    await tester.pump();
    expect(find.text('Configured item'), findsNothing);
    expect(find.text('Reward fulfilment unavailable for this session.'),
        findsOneWidget);
  });
}
