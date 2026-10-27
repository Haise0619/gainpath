import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_reward_status_panel.dart';

class Reader implements MiniGameRewardStatusReader {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  @override
  bool current = true;
  bool fail = false;
  @override
  Future<MiniGameRewardStatus> overview() async {
    if (fail) throw StateError('unavailable');
    return MiniGameRewardStatus(
        scope: scope,
        today: '2026-10-27',
        policy: MiniGameRewardPolicy(),
        earnedPoints: 20,
        remainingPoints: 40,
        issuanceActive: false,
        games: const [
          MiniGameRewardEligibility(
              gameId: MiniGameContent.supportedId,
              claimsToday: 1,
              eligible: false,
              reason: 'not-active')
        ]);
  }
}

void main() {
  testWidgets(
      'server-earned and shared remaining totals stay separate from game score',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MiniGameRewardStatusPanel(reader: Reader()))));
    await tester.pumpAndSettle();
    expect(find.text('20 pts earned today'), findsOneWidget);
    expect(find.text('40 pts remaining'), findsOneWidget);
    expect(find.text('Not active'), findsOneWidget);
    expect(find.textContaining('60'), findsWidgets);
    expect(find.textContaining('Claim reward'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing status never invents earned or remaining balances',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MiniGameRewardStatusPanel(reader: Reader()..fail = true))));
    await tester.pumpAndSettle();
    expect(find.text('— pts earned today'), findsOneWidget);
    expect(find.text('— pts remaining'), findsOneWidget);
    expect(find.textContaining('unavailable'), findsWidgets);
    expect(find.text('0 pts earned today'), findsNothing);
  });
  testWidgets(
      'reward status wraps on320px double-text and hides a stale session',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reader = Reader();
    Widget app() => MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: MiniGameRewardStatusPanel(reader: reader))));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    reader.current = false;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('20 pts earned today'), findsNothing);
  });
}
