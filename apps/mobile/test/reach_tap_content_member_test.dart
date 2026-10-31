import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/domain/reach_tap_ports.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_games_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_details_screen.dart';
import 'package:gainpath_mobile/navigation/feature_navigation.dart';
import 'package:gainpath_mobile/features/gamification/application/reach_tap_controller.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reach_tap_view.dart';
import 'reach_tap_controller_test.dart' show TapCamera, TapHistory;

class Reader implements MiniGameContentReader {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  @override
  bool current = true;
  List<MiniGameContent>? rows;
  @override
  Future<List<MiniGameContent>> load() async =>
      rows ??
      [
        MiniGameContent.defaults('gym'),
        reachGuide(),
      ];
}

MiniGameContent reachGuide({String org = 'gym'}) => MiniGameContent(
        organizationId: org,
        gameId: 'reach-tap-v1',
        revision: 3,
        updatedAtMillis: 1234,
        title: 'Reach across the room',
        introduction: 'Your gym hand-target challenge.',
        instructions: const [
          'Take your starting position.',
          'Step to the fixed circles.'
        ]);

class History implements ReachTapHistoryStore {
  final reads = <SessionScope>[];
  Completer<ReachTapHistory>? pending;
  bool fail = false;
  @override
  Future<ReachTapHistory> load(SessionScope scope) async {
    reads.add(scope);
    if (fail) throw StateError('Storage unavailable');
    return pending == null ? ReachTapHistory(bestScore: 230) : pending!.future;
  }

  @override
  Future<ReachTapHistory> record(SessionScope scope, ReachTapRound round,
          {required bool Function() isCurrent}) =>
      throw StateError('Read only');
}

void main() {
  for (final foreign in [false, true]) {
    testWidgets(
        'Reach camera handoff keeps compact reminder and scoped title foreign=$foreign',
        (tester) async {
      final scope = SessionScope(userId: 'member', organizationId: 'gym');
      final camera = TapCamera();
      final c = ReachTapController(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          history: TapHistory(),
          clockMicros: () => 0,
          autoTick: false);
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
          home: ReachTapView(
              controller: c,
              viewport: const SizedBox(key: Key('camera')),
              content: reachGuide(org: foreign ? 'other' : 'gym'))));
      expect(find.text('Reach across the room'),
          foreign ? findsNothing : findsOneWidget);
      expect(find.text('1. Take your starting position.'), findsNothing,
          reason:
              'Authored instructions remain in Details, not repeated at camera consent');
      expect(
          find.textContaining(
              'Keep your shoulders, hips and both hands visible for alignment.'),
          findsOneWidget);
      expect(
          find.textContaining(
              'Camera images and hand positions stay on this device.'),
          findsOneWidget);
      expect(find.text('Play for fun · no Reward Points'), findsOneWidget);
      expect(find.byKey(const Key('camera')), findsNothing);
      expect(camera.starts, 0);
    });
  }

  testWidgets(
      'managed Reach & Tap guide opens matching details then its own route',
      (tester) async {
    final reader = Reader();
    RouteSettings? launched;
    await tester.pumpWidget(MaterialApp(
        home: MiniGamesScreen(connected: true, reader: reader),
        onGenerateRoute: (settings) {
          launched = settings;
          return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Game route')));
        }));
    await tester.pumpAndSettle();
    expect(find.text('Reach across the room'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('View Reach & Tap details'));
    await tester.tap(find.byTooltip('View Reach & Tap details'));
    await tester.pumpAndSettle();
    expect(launched, isNull, reason: 'Details must precede camera consent');
    expect(find.text('Your gym hand-target challenge.'), findsOneWidget);
    expect(find.text('1. Take your starting position.'), findsOneWidget);
    expect(find.text('+10 per confirmed hit'), findsOneWidget);
    expect(find.textContaining('Obstacles subtract'), findsNothing);
    expect(find.text('Reward Points'), findsOneWidget);
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    expect(launched?.name, FeatureNavigation.reachAndTap);
    final content = launched?.arguments as MiniGameContent;
    expect(content.gameId, 'reach-tap-v1');
    expect(content.title, 'Reach across the room');
  });

  testWidgets(
      'Reach & Tap details use Reach history and never Move Catch reward panel',
      (tester) async {
    final reader = Reader(), history = History();
    await tester.pumpWidget(RepositoryProvider<ReachTapHistoryStore>.value(
        value: history,
        child: MaterialApp(
            home: MiniGameDetailsScreen(
                content: reachGuide(),
                reader: reader,
                rewardStatus: const Text('Move Catch reward panel')))));
    await tester.pumpAndSettle();
    expect(find.text('Personal best · 230'), findsOneWidget);
    expect(history.reads.single, reader.scope);
    expect(find.text('Move Catch reward panel'), findsNothing);
    expect(find.text('Reward Points'), findsOneWidget);
  });

  testWidgets('legacy one-game catalog explicitly uses built-in Reach guide',
      (tester) async {
    final reader = Reader()..rows = [MiniGameContent.defaults('gym')];
    await tester.pumpWidget(
        MaterialApp(home: MiniGamesScreen(connected: true, reader: reader)));
    await tester.pumpAndSettle();
    expect(find.text('Built-in game guide · latest content unavailable'),
        findsOneWidget);
    await tester.ensureVisible(find.byTooltip('View Reach & Tap details'));
    await tester.tap(find.byTooltip('View Reach & Tap details'));
    await tester.pumpAndSettle();
    expect(find.text('Reach & Tap'), findsWidgets);
    expect(find.text('+10 per confirmed hit'), findsOneWidget);
  });

  testWidgets(
      'foreign Reach guide never renders and expired reader hides game details',
      (tester) async {
    final reader = Reader()
      ..rows = [MiniGameContent.defaults('gym'), reachGuide(org: 'other')];
    await tester.pumpWidget(
        MaterialApp(home: MiniGamesScreen(connected: true, reader: reader)));
    await tester.pumpAndSettle();
    expect(find.text('Reach across the room'), findsNothing);
    reader.current = false;
    await tester.pumpWidget(MaterialApp(
        home: MiniGameDetailsScreen(content: reachGuide(), reader: reader)));
    await tester.pumpAndSettle();
    expect(find.text('This game guide session has ended.'), findsOneWidget);
    expect(find.text('Start playing'), findsNothing);
  });

  testWidgets(
      'failed local Reach best remains unavailable rather than fabricated zero',
      (tester) async {
    final history = History()..fail = true;
    await tester.pumpWidget(RepositoryProvider<ReachTapHistoryStore>.value(
        value: history,
        child: MaterialApp(
            home: MiniGameDetailsScreen(
                content: reachGuide(), reader: Reader()))));
    await tester.pumpAndSettle();
    expect(history.reads, hasLength(1));
    expect(find.text('Personal best · Unavailable'), findsOneWidget);
    expect(find.text('Personal best · 0'), findsNothing);
  });
}
