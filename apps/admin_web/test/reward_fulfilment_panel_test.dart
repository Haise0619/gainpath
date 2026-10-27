import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_admin_web/features/gamification/reward_fulfilment_repository.dart';
import 'package:gainpath_admin_web/features/gamification/presentation/admin/reward_fulfilment_panel.dart';

class _Repo implements RewardFulfilmentRepository {
  int writes = 0;
  String? inspected;
  String status = 'issued';
  @override
  bool current = true;
  @override
  Future<AdminRewardVoucher> inspect(String id) async {
    inspected = id;
    return AdminRewardVoucher(
        memberId: 'member',
        redemption: VerifiedRewardRedemption(
            redemptionId: id,
            itemId: 'real-item',
            title: 'Configured item',
            points: 50,
            status: writes == 0 ? status : 'fulfilled',
            conditions: 'Show this reward at reception',
            issuedAtMillis: 1800000000000));
  }

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
    await tester.ensureVisible(find.text('Confirm collection'));
    await tester.tap(find.text('Confirm collection'));
    await tester.pumpAndSettle();
    expect(repo.writes, 1);
    expect(find.text('Already fulfilled · do not issue again'), findsOneWidget);
    expect(find.text('Confirm collection'), findsNothing);
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
  testWidgets('expired reward cannot be collected and explains spent points',
      (tester) async {
    final repo = _Repo()..status = 'expired';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: RewardFulfilmentPanel(repository: repo))));
    await tester.enterText(find.byType(TextField), 'voucher-id');
    await tester.tap(find.text('Check reward voucher'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm collection'), findsNothing);
    expect(find.textContaining('Points remain spent'), findsOneWidget);
    expect(find.text('Show this reward at reception'), findsOneWidget);
    expect(repo.writes, 0);
  });
  testWidgets('camera starts on demand and detection only inspects once',
      (tester) async {
    final repo = _Repo();
    var builds = 0;
    void Function(String)? detect;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RewardFulfilmentPanel(
      repository: repo,
      scannerBuilder: (_, onDetect) {
        builds++;
        detect = onDetect;
        return const SizedBox(height: 100);
      },
    ))));
    expect(builds, 0);
    await tester.tap(find.text('Scan reward QR'));
    await tester.pump();
    detect!('gainpath-reward:v1:o:voucher-id');
    detect!('gainpath-reward:v1:o:another-id');
    await tester.pumpAndSettle();
    expect(repo.inspected, 'gainpath-reward:v1:o:voucher-id');
    expect(repo.writes, 0);
    expect(find.text('Close camera'), findsNothing);
  });
  testWidgets(
      'camera closes on background and session change without inspecting',
      (tester) async {
    final repo = _Repo();
    Widget app() => MaterialApp(
        home: Scaffold(
            body: RewardFulfilmentPanel(
                repository: repo,
                scannerBuilder: (_, detect) =>
                    const SizedBox(key: Key('camera'), height: 100))));
    await tester.pumpWidget(app());
    await tester.tap(find.text('Scan reward QR'));
    await tester.pump();
    expect(find.byKey(const Key('camera')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(const Key('camera')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('camera')), findsNothing);
    await tester.tap(find.text('Scan reward QR'));
    await tester.pump();
    repo.current = false;
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('camera')), findsNothing);
    expect(repo.inspected, null);
  });
  testWidgets('collection details scroll at small width and large text',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(body: RewardFulfilmentPanel(repository: repo))));
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'voucher');
    await tester.ensureVisible(find.text('Check reward voucher'));
    await tester.tap(find.text('Check reward voucher'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm collection'));
    expect(tester.takeException(), null);
  });
}
