import 'dart:async';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/fitness_arcade_rank.dart';

EarnedPointsLeaderboard result({int? rank = 7, int points = 150}) =>
    EarnedPointsLeaderboard(
        period: 'week',
        entries: const [],
        you: EarnedPointsRank(
            rank: rank, displayName: 'You', points: points, isYou: true),
        totalParticipants: 20,
        resolvedAtMillis: 1234);

class Repo extends VerifiedRewardsRepository {
  @override
  bool current = true;
  @override
  bool get connected => false;
  int calls = 0;
  bool fail = false;
  EarnedPointsLeaderboard data = result();
  Completer<EarnedPointsLeaderboard>? pending;
  @override
  Future<EarnedPointsLeaderboard> leaderboard({String period = 'week'}) async {
    if (period != 'week') throw StateError('weekly only');
    calls++;
    if (fail) throw StateError('offline');
    return pending?.future ?? data;
  }

  @override
  Future<VerifiedRewardsSnapshot> overview() => throw StateError('rank only');
  @override
  Future<void> award(String eventId) => throw StateError('read only');
  @override
  Future<VerifiedRewardRedemption> redeem(
          {required String itemId,
          required String requestId,
          int? expectedPointCost,
          int? expectedItemRevision}) =>
      throw StateError('read only');
}

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));
void main() {
  testWidgets(
      'heading remains dark with unspecified titleSmall and white inherited text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light().copyWith(textTheme: const TextTheme()),
        home: Scaffold(
            body: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: FitnessArcadeRank(repository: Repo(), onTap: () {})))));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('Earned-points weekly rank'));
    expect(text.style?.color, AppColors.ink);
    expect(text.style?.fontSize, greaterThanOrEqualTo(14));
    expect(tester.takeException(), isNull);
  });

  testWidgets('isolated rank host is honest and does not initialize Firebase',
      (tester) async {
    await tester.pumpWidget(host(FitnessArcadeRankHost(onTap: () {})));
    expect(find.text('Earned-points weekly rank'), findsOneWidget);
    expect(find.textContaining('Unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'weekly rank uses confirmed own rank and points and opens full standings',
      (tester) async {
    final repo = Repo();
    var tapped = 0;
    final widget = FitnessArcadeRank(
        repository: repo,
        onTap: () {
          tapped++;
        });
    await tester.pumpWidget(host(widget));
    await tester.pumpAndSettle();
    expect(find.textContaining('#7'), findsOneWidget);
    expect(find.textContaining('You · #7'), findsOneWidget);
    expect(find.textContaining('150 earned points'), findsOneWidget);
    await tester.tap(find.byKey(const Key('arcade-weekly-rank')));
    expect(tapped, 1);
    await tester.pumpWidget(host(widget));
    expect(repo.calls, 1);
  });
  testWidgets('unranked zero is confirmed and different from unknown',
      (tester) async {
    await tester.pumpWidget(host(FitnessArcadeRank(
        repository: Repo()..data = result(rank: null, points: 0),
        onTap: () {})));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unranked'), findsOneWidget);
    expect(find.textContaining('0 earned points'), findsOneWidget);
  });
  testWidgets('failed rank can retry and old session reply is discarded',
      (tester) async {
    final repo = Repo()..fail = true;
    await tester
        .pumpWidget(host(FitnessArcadeRank(repository: repo, onTap: () {})));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unavailable'), findsOneWidget);
    repo.fail = false;
    repo.pending = Completer();
    expect(find.byTooltip('Refresh weekly rank'), findsNothing);
    await tester.pumpWidget(host(FitnessArcadeRank(
        key: const ValueKey('reloaded'), repository: repo, onTap: () {})));
    await tester.pump();
    expect(find.textContaining('Loading'), findsOneWidget);
    repo.current = false;
    repo.pending!.complete(result());
    await tester.pumpAndSettle();
    expect(find.textContaining('150 earned points'), findsNothing);
  });
  testWidgets('rank adapts to 320px and double text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: FitnessArcadeRank(repository: Repo(), onTap: () {}))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('replacing repository discards the prior account reply',
      (tester) async {
    final oldRepo = Repo()..pending = Completer();
    await tester
        .pumpWidget(host(FitnessArcadeRank(repository: oldRepo, onTap: () {})));
    await tester.pumpWidget(host(FitnessArcadeRank(
        repository: Repo()..data = result(rank: 3, points: 75), onTap: () {})));
    oldRepo.pending!.complete(result());
    await tester.pumpAndSettle();
    expect(find.textContaining('#3 · 75 earned points'), findsOneWidget);
    expect(find.textContaining('150 earned points'), findsNothing);
  });
}
