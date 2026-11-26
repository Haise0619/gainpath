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

class ConfigurableRankingsRepo extends CompetitionRepo {
  ConfigurableRankingsRepo({
    this.entries = const [],
    this.you = const MiniGameScoreRank(
        rank: null, displayName: 'You', score: null, isYou: true),
    this.totalParticipants = 0,
  });

  final List<MiniGameScoreRank> entries;
  final MiniGameScoreRank you;
  final int totalParticipants;

  @override
  Future<MiniGameScoreLeaderboard> leaderboard(
      {required String gameId, required String period}) async {
    return MiniGameScoreLeaderboard(
      scope: scope,
      gameId: gameId,
      period: period,
      periodKey: '2026-10-26',
      entries: entries,
      you: you,
      totalParticipants: totalParticipants,
      resolvedAtMillis: 1234,
    );
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

  testWidgets('adaptive empty state shows No Rankings Yet when 0 players',
      (tester) async {
    final repo = ConfigurableRankingsRepo(
      entries: const [],
      you: const MiniGameScoreRank(
          rank: null, displayName: 'You', score: null, isYou: true),
      totalParticipants: 0,
    );
    await tester.pumpWidget(MaterialApp(
        home: GameLeaderboardScreen(repository: repo, gameId: 'move-catch-v1')));
    await tester.pumpAndSettle();

    expect(find.text('No Rankings Yet'), findsOneWidget);
    expect(find.textContaining('No accepted scores yet'), findsOneWidget);
    expect(find.text('Unranked'), findsOneWidget);
    expect(find.text('Top 3'), findsNothing);
  });

  testWidgets(
      'adaptive compact list shows Rankings (1) or (2) without podium for <3 players',
      (tester) async {
    final repo = ConfigurableRankingsRepo(
      entries: const [
        MiniGameScoreRank(
            rank: 1, displayName: 'Jordan', score: 380, isYou: false),
        MiniGameScoreRank(
            rank: 2, displayName: 'Sam', score: 310, isYou: true),
      ],
      you: const MiniGameScoreRank(
          rank: 2, displayName: 'Sam', score: 310, isYou: true),
      totalParticipants: 2,
    );
    await tester.pumpWidget(MaterialApp(
        home: GameLeaderboardScreen(repository: repo, gameId: 'move-catch-v1')));
    await tester.pumpAndSettle();

    expect(find.text('Rankings (2)'), findsOneWidget);
    expect(find.text('Jordan'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Top 3'), findsNothing);
    expect(find.text('YOU'), findsOneWidget);
  });

  testWidgets(
      'adaptive podium and remaining list displays 5 players without duplicating Top 3',
      (tester) async {
    tester.view.physicalSize = const Size(393, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = ConfigurableRankingsRepo(
      entries: const [
        MiniGameScoreRank(
            rank: 1, displayName: 'Alex', score: 500, isYou: false),
        MiniGameScoreRank(
            rank: 2, displayName: 'Sam', score: 450, isYou: false),
        MiniGameScoreRank(
            rank: 3, displayName: 'Kai', score: 400, isYou: false),
        MiniGameScoreRank(
            rank: 4, displayName: 'Taylor', score: 350, isYou: false),
        MiniGameScoreRank(
            rank: 5, displayName: 'Jordan', score: 300, isYou: false),
      ],
      you: const MiniGameScoreRank(
          rank: 1, displayName: 'Alex', score: 500, isYou: true),
      totalParticipants: 5,
    );
    await tester.pumpWidget(MaterialApp(
        home: GameLeaderboardScreen(repository: repo, gameId: 'move-catch-v1')));
    await tester.pumpAndSettle();

    expect(find.text('Top 3'), findsOneWidget);
    expect(find.textContaining('Rankings (4'), findsOneWidget);

    // Podium contestants appear in podium
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Kai'), findsOneWidget);

    // Runner-up contestants appear in list
    expect(find.text('Taylor'), findsOneWidget);
    expect(find.text('Jordan'), findsOneWidget);
  });

  testWidgets('current member in Top 3 displays highlight on podium',
      (tester) async {
    final repo = ConfigurableRankingsRepo(
      entries: const [
        MiniGameScoreRank(
            rank: 1, displayName: 'Alex', score: 500, isYou: true),
        MiniGameScoreRank(
            rank: 2, displayName: 'Sam', score: 450, isYou: false),
        MiniGameScoreRank(
            rank: 3, displayName: 'Kai', score: 400, isYou: false),
      ],
      you: const MiniGameScoreRank(
          rank: 1, displayName: 'Alex', score: 500, isYou: true),
      totalParticipants: 3,
    );
    await tester.pumpWidget(MaterialApp(
        home: GameLeaderboardScreen(repository: repo, gameId: 'move-catch-v1')));
    await tester.pumpAndSettle();

    expect(find.text('Alex · You'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    testWidgets('responsive layout at width ${width.toInt()} at 1.0x and 2.0x text scale',
        (tester) async {
      final repo = Rankings();
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: w!,
          ),
          home: GameLeaderboardScreen(repository: repo, gameId: 'move-catch-v1'),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
