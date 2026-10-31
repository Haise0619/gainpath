import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/game_leaderboard_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/game_competition_privacy.dart';
import 'mini_game_competition_coordinator_test.dart'
    show CompetitionRepo, scope;

class FailedPreference extends CompetitionRepo {
  @override
  Future<MiniGameCompetitionPreference> setPreference(
          {required bool enabled}) async =>
      throw StateError('offline');
}

class Rankings extends CompetitionRepo {
  String? requestedGame, requestedPeriod;
  bool error = false;
  @override
  Future<MiniGameScoreLeaderboard> leaderboard(
      {required String gameId, required String period}) async {
    requestedGame = gameId;
    requestedPeriod = period;
    if (error) throw StateError('offline');
    return MiniGameScoreLeaderboard(
        scope: scope,
        gameId: gameId,
        period: period,
        periodKey: '2026-10-26',
        entries: const [
          MiniGameScoreRank(
              rank: 1, displayName: 'Alex', score: 500, isYou: false),
          MiniGameScoreRank(
              rank: 2, displayName: 'Sam', score: 450, isYou: false),
          MiniGameScoreRank(
              rank: 2, displayName: 'Kai', score: 450, isYou: false)
        ],
        you: const MiniGameScoreRank(
            rank: 21, displayName: 'You', score: 200, isYou: true),
        totalParticipants: 21,
        resolvedAtMillis: 1234);
  }
}

void main() {
  testWidgets(
      'separate games and periods show accepted best plus own rank outside top20',
      (tester) async {
    final repo = Rankings();
    await tester.pumpWidget(MaterialApp(
        home: GameLeaderboardScreen(repository: repo, gameId: 'reach-tap-v1')));
    await tester.pumpAndSettle();
    expect(repo.requestedGame, 'reach-tap-v1');
    expect(find.text('Reach & Tap rankings'), findsOneWidget);
    expect(find.textContaining('not physically verified'), findsOneWidget);
    expect(find.text('Top 3'), findsOneWidget);
    expect(find.textContaining('#21'), findsOneWidget);
    expect(find.textContaining('200'), findsOneWidget);
    await tester.tap(find.text('All-time'));
    await tester.pumpAndSettle();
    expect(repo.requestedPeriod, 'all-time');
    await tester.tap(find.text('Move & Catch'));
    await tester.pumpAndSettle();
    expect(repo.requestedGame, 'move-catch-v1');
  });
  testWidgets(
      'privacy optout explains previous scores and confirms server state',
      (tester) async {
    final repo = Rankings();
    await tester.pumpWidget(MaterialApp(
        home:
            GameLeaderboardScreen(repository: repo, gameId: 'move-catch-v1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Ranking privacy'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Ranking privacy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranking privacy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('previously published scores'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(repo.enabled, false);
    expect(find.text('Hidden from game rankings'), findsOneWidget);
  });
  testWidgets(
      'load failure is not unranked and retry can recover at320 doubletext',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = Rankings()..error = true;
    await tester.pumpWidget(MaterialApp(
        builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(2)),
            child: w!),
        home:
            GameLeaderboardScreen(repository: repo, gameId: 'move-catch-v1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Could not load game rankings.'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Could not load game rankings.'), findsOneWidget);
    expect(find.text('Unranked'), findsNothing);
    repo.error = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'failed withdrawal keeps confirmed enabled state and never claims hidden',
      (tester) async {
    final repo = FailedPreference();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: GameCompetitionPrivacy(repository: repo)))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not confirm ranking visibility'),
        findsOneWidget);
    expect(find.text('Hidden from game rankings'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).value, true);
  });
}
