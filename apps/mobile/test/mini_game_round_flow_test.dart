import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/application/mini_game_round_coordinator.dart';
import 'package:gainpath_mobile/features/gamification/application/move_and_catch_controller.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_and_catch.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/move_and_catch_view.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_round_status_panel.dart';
import 'mini_game_round_coordinator_test.dart' show Repo, settle;
import 'move_and_catch_controller_test.dart' show Camera, Best;

void main() {
  testWidgets(
      'timing consent is separate, optional and unchecked before camera access',
      (tester) async {
    final repo = Repo(), camera = Camera();
    final game = MoveAndCatchController(
        scope: repo.scope,
        activeScope: () => repo.scope,
        camera: camera,
        bestScores: Best(),
        autoTick: false,
        roundTiming: MiniGameRoundCoordinator(repository: repo));
    addTearDown(game.dispose);
    await tester.pumpWidget(MaterialApp(
        home: MoveAndCatchView(controller: game, viewport: const SizedBox())));
    expect(
        find.text('Send round timing for verification checks'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false);
    expect(repo.calls, isEmpty);
    expect(camera.starts, 0);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(game.roundTimingConsent, true);
    expect(repo.calls, isEmpty);
  });
  test('ordinary play never reports rounds without the separate opt-in',
      () async {
    final repo = Repo(), camera = Camera();
    var now = 0;
    final game = MoveAndCatchController(
        scope: repo.scope,
        activeScope: () => repo.scope,
        camera: camera,
        bestScores: Best(),
        autoTick: false,
        clockMicros: () => now,
        roundTiming: MiniGameRoundCoordinator(
            repository: repo, clockMillis: () => now ~/ 1000));
    addTearDown(game.dispose);
    await game.startCamera(consented: true);
    for (var i = 0; i < 30; i++) {
      now += 50000;
      camera.sample(now);
      game.tick();
    }
    game.startRound();
    await settle();
    expect(game.engine.phase, MoveCatchPhase.countdown);
    expect(repo.calls, isEmpty);
  });
  test(
      'reporting failure does not prevent a completed local game or saved best',
      () async {
    final repo = Repo()..beginWait = Completer(),
        camera = Camera(),
        best = Best();
    var now = 0;
    final game = MoveAndCatchController(
        scope: repo.scope,
        activeScope: () => repo.scope,
        camera: camera,
        bestScores: best,
        autoTick: false,
        clockMicros: () => now,
        roundTiming: MiniGameRoundCoordinator(
            repository: repo, clockMillis: () => now ~/ 1000));
    addTearDown(game.dispose);
    game.setRoundTimingConsent(true);
    await game.startCamera(consented: true);
    void steps(int n) {
      for (var i = 0; i < n; i++) {
        now += 50000;
        camera.sample(now);
        game.tick();
      }
    }

    steps(30);
    game.startRound();
    repo.beginWait!.completeError(StateError('offline'));
    await settle();
    steps(860);
    await settle();
    expect(game.engine.phase, MoveCatchPhase.finished);
    expect(best.writes, 1);
    expect(game.bestSaved, true);
    expect(game.roundTiming!.state, MiniGameRoundSyncState.unavailable);
    await game.finishAndClose();
    expect(camera.closes, 1);
  });
  testWidgets(
      'pending result is explicit and fits a small screen at double text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = Repo();
    var now = 0;
    final c = MiniGameRoundCoordinator(
        repository: repo, clockMillis: () => now, requestId: () => 'c' * 32);
    addTearDown(c.dispose);
    c.start();
    await tester.pump();
    for (var i = 1; i <= 20; i++) {
      now = i * 2000;
      c.observe(activeMillis: now, playing: true);
      await tester.pump();
    }
    c.finish();
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: MiniGameRoundStatusPanel(coordinator: c)))));
    expect(find.text('Round timing checked'), findsOneWidget);
    expect(
        find.textContaining('No reward points were awarded'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
