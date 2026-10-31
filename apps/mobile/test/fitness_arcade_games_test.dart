import 'dart:async';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/domain/move_catch_ports.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap_ports.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/fitness_arcade_games.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_details_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_games_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reach_tap_challenge_card.dart';
import 'support/mini_game_participation_fixture.dart';

class Reader implements MiniGameContentReader {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  @override
  bool current = true;
  int calls = 0;
  Completer<List<MiniGameContent>>? pending;
  bool fail = false;
  String coverUrl = '';
  @override
  Future<List<MiniGameContent>> load() async {
    calls++;
    if (fail) throw StateError('offline');
    return pending?.future ??
        [
          MiniGameContent.defaults('gainpath')
              .copyWith(title: 'Gym catch', coverUrl: coverUrl),
          MiniGameContent.defaults('gainpath',
                  gameId: MiniGameContent.reachTapId)
              .copyWith(title: 'Gym reach'),
        ];
  }
}

class Best implements MoveCatchBestScoreStore {
  int value = 120;
  Completer<int>? pending;
  @override
  Future<int> load(SessionScope scope) async => pending?.future ?? value;
  @override
  Future<int> record(SessionScope scope, int score,
          {required bool Function() isCurrent}) =>
      throw StateError('read only');
}

class History implements ReachTapHistoryStore {
  @override
  Future<ReachTapHistory> load(SessionScope scope) async =>
      ReachTapHistory(bestScore: 230);
  @override
  Future<ReachTapHistory> record(SessionScope scope, ReachTapRound round,
          {required bool Function() isCurrent}) =>
      throw StateError('read only');
}

class Participation implements MiniGameParticipationRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  @override
  bool current = true;
  Map<String, dynamic> response = participationFixture(active: true);
  Completer<MiniGameParticipation>? pending;
  bool fail = false;
  int calls = 0;
  @override
  Future<MiniGameParticipation> overview() async {
    calls++;
    if (fail) throw StateError('offline');
    return pending?.future ?? MiniGameParticipation.fromJson(response, scope);
  }

  @override
  Future<MiniGameParticipation> claim(String attemptId) =>
      throw StateError('overview only');
}

Widget host(Widget child, {double scale = 1}) => MaterialApp(
      builder: (_, child) => MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  Map<String, dynamic> reachResponse(
      {int claimed = 0, int earned = 0, bool active = true}) {
    final d = participationFixture(active: active, earned: earned);
    d['schemaVersion'] = 3;
    d['gameId'] = 'reach-tap-v1';
    final o = d['overview'] as Map<String, dynamic>;
    o['claimsToday'] = claimed;
    o['policy'] = MiniGameRewardPolicy(
        version: 'reach-tap-participation-v1',
        games: const [MiniGameRewardGame(gameId: 'reach-tap-v1')]).toJson();
    return d;
  }

  testWidgets(
      'Reach card uses independent daily allowance and removes refresh icons',
      (tester) async {
    final move = Participation()
      ..response = participationFixture(active: true, earned: 20);
    final reach = Participation()..response = reachResponse(earned: 20);
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: Reader(),
        participation: move,
        reachParticipation: reach,
        onReturn: () async {})));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const Key('arcade-reach-tap-card')),
            matching: find.text('+20 points')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('arcade-move-catch-card')),
            matching: find.text('Play for fun')),
        findsOneWidget);
    expect(find.byTooltip('Refresh arcade'), findsNothing);
    reach.response = reachResponse(claimed: 1, earned: 40);
    await tester.tap(find.byKey(const Key('arcade-reach-tap-card')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('+20 points'), findsNothing);
  });
  testWidgets('Reach card refuses Move response and shared cap exhaustion',
      (tester) async {
    final reach = Participation();
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: Reader(), reachParticipation: reach, onReturn: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('+20 points'), findsNothing);
    reach.response = reachResponse(earned: 60);
    await tester.pumpWidget(host(FitnessArcadeGames(
        key: const ValueKey('cap'),
        reader: Reader(),
        reachParticipation: reach,
        onReturn: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('+20 points'), findsNothing);
    expect(find.text('Play for fun'), findsNWidgets(2));
  });

  testWidgets(
      'heading remains dark with unspecified titleSmall and white inherited text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light().copyWith(textTheme: const TextTheme()),
        home: Scaffold(
            body: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: FitnessArcadeGames(
                    reader: Reader(), onReturn: () async {})))));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('Gym catch'));
    expect(text.style?.color, AppColors.ink);
    expect(text.style?.fontSize, greaterThanOrEqualTo(14));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two equal columns show only cover title earning and bottom best',
      (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: Reader(),
        bestScoreStore: Best(),
        reachTapHistory: History(),
        participation: Participation(),
        onReturn: () async {})));
    await tester.pumpAndSettle();
    final move =
        tester.getRect(find.byKey(const Key('arcade-move-catch-card')));
    final reach =
        tester.getRect(find.byKey(const Key('arcade-reach-tap-card')));
    expect(move.top, reach.top);
    expect(move.width, reach.width);
    expect(move.right, lessThan(reach.left));
    expect(move.height, lessThan(280));
    expect(find.text('+20 points'), findsOneWidget);
    expect(find.text('Play for fun'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Best: 120')).dy,
        greaterThan(tester.getTopLeft(find.text('+20 points')).dy));
    expect(tester.getRect(find.text('View all')).center.dy,
        closeTo(tester.getRect(find.text('Play Mini-Games')).center.dy, 1));
  });

  testWidgets(
      'View all preserves scoped Reach history through existing catalog and details',
      (tester) async {
    final history = History();
    var returned = 0;
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: Reader(),
        bestScoreStore: Best(),
        reachTapHistory: history,
        participation: Participation(),
        onReturn: () async {
          returned++;
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.byType(MiniGamesScreen), findsOneWidget);
    final catalogContext = tester.element(find.byType(MiniGamesScreen));
    expect(identical(catalogContext.read<ReachTapHistoryStore?>(), history),
        isTrue);
    await tester.ensureVisible(find.byType(ReachTapChallengeCard));
    await tester.tap(find.byType(ReachTapChallengeCard));
    await tester.pumpAndSettle();
    final details = tester
        .widget<MiniGameDetailsScreen>(find.byType(MiniGameDetailsScreen));
    expect(identical(details.reachTapHistory, history), isTrue);
    expect(details.content.gameId, MiniGameContent.reachTapId);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(returned, 1);
  });

  testWidgets(
      'View all keeps its captured reader and hides values after session end',
      (tester) async {
    final reader = Reader();
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: reader, reachTapHistory: History(), onReturn: () async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    reader.current = false;
    await tester.tap(find.byTooltip('Refresh game guide'));
    await tester.pumpAndSettle();
    expect(find.text('This game guide session has ended.'), findsOneWidget);
    expect(find.text('Gym catch'), findsNothing);
  });

  testWidgets(
      'return refreshes personal best without waiting for the initial slow guide',
      (tester) async {
    final reader = Reader()..pending = Completer<List<MiniGameContent>>();
    final best = Best();
    var returned = 0;
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: reader,
        bestScoreStore: best,
        onReturn: () async {
          returned++;
        })));
    await tester.pumpAndSettle();
    expect(find.text('Best: 120'), findsOneWidget);
    await tester.tap(find.byKey(const Key('arcade-move-catch-card')));
    await tester.pumpAndSettle();
    best.value = 180;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(returned, 1);
    expect(find.text('Best: 180'), findsOneWidget);
    reader.pending!.complete([
      MiniGameContent.defaults('gainpath'),
      MiniGameContent.defaults('gainpath', gameId: MiniGameContent.reachTapId)
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Best: 180'), findsOneWidget);
  });
  testWidgets(
      'managed Firebase cover URL renders through the arcade card image',
      (tester) async {
    const url =
        'https://firebasestorage.googleapis.com/v0/b/gainpath-0619.firebasestorage.app/o/orgs%2Fgainpath%2FminiGameMedia%2Fmove-catch-v1%2Fcover%2Fadmin%2F0123456789abcdef0123456789abcdef?alt=media&token=12345678-1234-1234-1234-123456789abc';
    final reader = Reader()..coverUrl = url;
    await tester.pumpWidget(
        host(FitnessArcadeGames(reader: reader, onReturn: () async {})));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image).first);
    expect((image.image as NetworkImage).url, url);
    expect(image.semanticLabel, 'Gym catch cover');
  });
  testWidgets(
      'pending guides do not expose refresh icons or duplicate the batch',
      (tester) async {
    final reader = Reader()..pending = Completer<List<MiniGameContent>>();
    final participation = Participation();
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: reader, participation: participation, onReturn: () async {})));
    await tester.pump();
    expect(find.byTooltip('Refresh arcade'), findsNothing);
    await tester.pump();
    expect(reader.calls, 1);
    expect(participation.calls, 1);
    reader.pending!.complete([
      MiniGameContent.defaults('gainpath'),
      MiniGameContent.defaults('gainpath', gameId: MiniGameContent.reachTapId)
    ]);
    await tester.pumpAndSettle();
  });
  testWidgets(
      'isolated host gives playable built-in guides and honest unknown values',
      (tester) async {
    await tester.pumpWidget(host(FitnessArcadeHost(onReturn: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('Move & Catch'), findsOneWidget);
    expect(find.text('Reach & Tap'), findsOneWidget);
    expect(find.text('Best: —'), findsNWidgets(2));
    expect(find.text('Play for fun'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'independent reads keep cards visible and show game-specific local PBs',
      (tester) async {
    final reader = Reader()..pending = Completer();
    final participation = Participation()..pending = Completer();
    final best = Best();
    final widget = FitnessArcadeGames(
        reader: reader,
        bestScoreStore: best,
        reachTapHistory: History(),
        participation: participation,
        onReturn: () async {});
    await tester.pumpWidget(host(widget));
    await tester.pump();
    expect(find.text('Move & Catch'), findsOneWidget);
    expect(find.text('Best: 120'), findsOneWidget);
    expect(find.text('Best: 230'), findsOneWidget);
    expect(find.text('40 seconds · Camera'), findsNothing);
    reader.pending!.complete([
      MiniGameContent.defaults('gainpath').copyWith(title: 'Authored catch')
    ]);
    participation.pending!.complete(MiniGameParticipation.fromJson(
        participationFixture(active: true), participation.scope));
    await tester.pumpAndSettle();
    expect(find.text('Authored catch'), findsOneWidget);
    expect(find.text('+20 points'), findsOneWidget);
    await tester.pumpWidget(host(widget));
    expect(reader.calls, 1);
    expect(participation.calls, 1);
  });

  for (final scenario in ['inactive', 'claimed', 'cap', 'disabled']) {
    testWidgets(
        'availability distinguishes $scenario without a Reach reward promise',
        (tester) async {
      final p = Participation();
      p.response = participationFixture(
          active: scenario != 'inactive',
          earned: scenario == 'claimed'
              ? 20
              : scenario == 'cap'
                  ? 60
                  : 0);
      if (scenario == 'cap') (p.response['overview'] as Map)['claimsToday'] = 0;
      if (scenario == 'disabled') {
        final policy = (p.response['overview'] as Map)['policy'] as Map;
        (policy['games'] as List).single['points'] = 0;
      }
      await tester.pumpWidget(host(FitnessArcadeGames(
          reader: Reader(), participation: p, onReturn: () async {})));
      await tester.pumpAndSettle();
      expect(find.text('Play for fun'), findsNWidgets(2));
      expect(find.text('+20 points'), findsNothing);
    });
  }

  testWidgets('return from existing details refreshes scoped PB and parent',
      (tester) async {
    final reader = Reader(), best = Best(), history = History();
    var returned = 0;
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: reader,
        bestScoreStore: best,
        reachTapHistory: history,
        onReturn: () async {
          returned++;
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('arcade-reach-tap-card')));
    await tester.pumpAndSettle();
    final details = tester
        .widget<MiniGameDetailsScreen>(find.byType(MiniGameDetailsScreen));
    expect(identical(details.reachTapHistory, history), isTrue);
    expect(details.content.gameId, MiniGameContent.reachTapId);
    best.value = 180;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Best: 180'), findsOneWidget);
    expect(returned, 1);
    expect(reader.calls, 1,
        reason:
            'A game result refreshes PBs and allowance without refetching unchanged guide content');
  });

  testWidgets('session ending discards late content, scores and participation',
      (tester) async {
    final reader = Reader()..pending = Completer();
    final best = Best()..pending = Completer();
    final p = Participation()..pending = Completer();
    final widget = FitnessArcadeGames(
        reader: reader,
        bestScoreStore: best,
        participation: p,
        onReturn: () async {});
    await tester.pumpWidget(host(widget));
    reader.current = false;
    p.current = false;
    reader.pending!.complete([
      MiniGameContent.defaults('gainpath').copyWith(title: 'Private title')
    ]);
    best.pending!.complete(999);
    p.pending!.complete(MiniGameParticipation.fromJson(
        participationFixture(active: true), p.scope));
    await tester.pumpWidget(host(widget));
    await tester.pumpAndSettle();
    expect(find.text('Private title'), findsNothing);
    expect(find.textContaining('999'), findsNothing);
    expect(find.text('+20 points'), findsNothing);
  });

  testWidgets('guide failure retries and rejects foreign organization content',
      (tester) async {
    final reader = Reader()..fail = true;
    await tester.pumpWidget(
        host(FitnessArcadeGames(reader: reader, onReturn: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('Move & Catch'), findsOneWidget);
    expect(find.text('Play for fun'), findsNWidgets(2));
    reader.fail = false;
    reader.pending = Completer()
      ..complete([
        MiniGameContent.defaults('foreign').copyWith(title: 'Foreign title')
      ]);
    await tester.pumpWidget(host(FitnessArcadeGames(
        key: const ValueKey('retry'), reader: reader, onReturn: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('Foreign title'), findsNothing);
    expect(find.text('Move & Catch'), findsOneWidget);
  });

  testWidgets(
      'replacement scope ignores old pending reads and uses latest callbacks',
      (tester) async {
    final oldReader = Reader()..pending = Completer();
    final oldBest = Best()..pending = Completer();
    var oldReturns = 0, newReturns = 0;
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: oldReader,
        bestScoreStore: oldBest,
        onReturn: () async {
          oldReturns++;
        })));
    final reader = Reader();
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: reader,
        bestScoreStore: Best()..value = 80,
        onReturn: () async {
          newReturns++;
        })));
    oldReader.pending!.complete(
        [MiniGameContent.defaults('gainpath').copyWith(title: 'Old guide')]);
    oldBest.pending!.complete(999);
    await tester.pumpAndSettle();
    expect(find.text('Old guide'), findsNothing);
    expect(find.text('Best: 80'), findsOneWidget);
    await tester.tap(find.byKey(const Key('arcade-move-catch-card')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MiniGameDetailsScreen>(find.byType(MiniGameDetailsScreen))
            .content
            .title,
        'Gym catch');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(oldReturns, 0);
    expect(newReturns, 1);
  });

  testWidgets(
      'unavailable participation retries without claiming and keeps local PB',
      (tester) async {
    final p = Participation()..fail = true;
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: Reader(),
        bestScoreStore: Best(),
        participation: p,
        onReturn: () async {})));
    await tester.pumpAndSettle();
    expect(find.text('Play for fun'), findsNWidgets(2));
    expect(find.text('Best: 120'), findsOneWidget);
    p.fail = false;
    await tester.tap(find.byKey(const Key('arcade-move-catch-card')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('+20 points'), findsOneWidget);
  });

  testWidgets('parent callback runs before a slow return refresh finishes',
      (tester) async {
    final reader = Reader();
    var returned = false;
    await tester.pumpWidget(host(FitnessArcadeGames(
        reader: reader,
        onReturn: () async {
          returned = true;
        })));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('arcade-move-catch-card')));
    await tester.pumpAndSettle();
    reader.pending = Completer();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    reader.pending!.complete([]);
    await tester.pumpAndSettle();
  });

  for (final width in [320.0, 375.0]) {
    testWidgets('compact cards remain usable at width $width and double text',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          host(FitnessArcadeGames(onReturn: () async {}), scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester
          .ensureVisible(find.byKey(const Key('arcade-reach-tap-card')));
      await tester.tap(find.byKey(const Key('arcade-reach-tap-card')));
      await tester.pumpAndSettle();
      expect(find.byType(MiniGameDetailsScreen), findsOneWidget);
    });
  }
}
