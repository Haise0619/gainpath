import 'package:flutter/material.dart';
import 'package:gainpath_mobile/features/gamification/application/move_and_catch_controller.dart';
import 'package:gainpath_mobile/features/gamification/application/mini_game_round_coordinator.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_and_catch.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_catch_ports.dart';
import 'mini_game_round_coordinator_test.dart' show Repo;
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/application/reach_tap_controller.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap_ports.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/move_catch_result_panel.dart';
import 'reach_tap_controller_test.dart' show TapCamera, TapHistory;

class FinishedEngine extends Fake implements ReachTapEngine {
  @override
  ReachTapPhase phase = ReachTapPhase.finished;
  @override
  int score = 30;
  @override
  int hits = 3;
  @override
  int activeMicros = 40000000;
  @override
  void resume(int now) {}
  @override
  void tick(int now) {}
  @override
  void pause(int now) {}
  @override
  void restart(int now) {
    phase = ReachTapPhase.calibrating;
    score = 0;
    hits = 0;
  }
}

class PriorHistory extends TapHistory {
  PriorHistory(this.prior);
  final int? prior;
  @override
  Future<ReachTapHistory> load(SessionScope scope) async {
    if (prior == null) throw StateError('unknown');
    return ReachTapHistory(bestScore: prior!);
  }
}

class FinishedMove extends Fake implements MoveCatchEngine {
  @override
  MoveCatchPhase phase = MoveCatchPhase.finished;
  @override
  int score = 30;
  @override
  double remainingSeconds = 0;
  @override
  int durationMicros = 40000000;
  @override
  void tick(int now) {}
  @override
  void pause(int now) {}
  @override
  void restart(int now) {
    phase = MoveCatchPhase.calibrating;
    score = 0;
  }
}

class MoveCamera extends MoveCatchCamera {
  @override
  bool tracking = true;
  @override
  String? error;
  @override
  Future<void> start(void Function(MoveCatchTorsoSample) sample) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> close() async {}
}

class MoveStore implements MoveCatchBestScoreStore {
  bool fail = true;
  int writes = 0;
  @override
  Future<int> load(SessionScope scope) async => 10;
  @override
  Future<int> record(SessionScope scope, int score,
      {required bool Function() isCurrent}) async {
    writes++;
    if (fail) throw StateError('disk');
    if (!isCurrent()) throw StateError('scope');
    return score;
  }
}

void main() {
  test('Move save retry celebrates only after persistence and clears on replay',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final store = MoveStore();
    final c = MoveAndCatchController(
        scope: scope,
        activeScope: () => scope,
        camera: MoveCamera(),
        bestScores: store,
        engine: FinishedMove(),
        autoTick: false);
    addTearDown(c.dispose);
    await c.startCamera(consented: true);
    c.tick();
    await Future<void>.delayed(Duration.zero);
    expect(c.scoreSaveFailed, true);
    expect(c.newPersonalBest, false);
    store.fail = false;
    await Future.wait([c.retrySave(), c.retrySave()]);
    expect(store.writes, 2);
    expect(c.newPersonalBest, true);
    await c.restart();
    expect(c.newPersonalBest, false);
  });
  test(
      'earning eligibility recheck fails closed while camera fun play remains available',
      () async {
    final repo = Repo();
    final scope = repo.scope;
    final c = MoveAndCatchController(
        scope: scope,
        activeScope: () => scope,
        camera: MoveCamera(),
        bestScores: MoveStore(),
        roundTiming: MiniGameRoundCoordinator(repository: repo),
        earningAvailable: () async => false,
        engine: FinishedMove(),
        autoTick: false);
    addTearDown(c.dispose);
    c.setRoundTimingConsent(true);
    await c.startCamera(consented: true);
    expect(c.roundTimingConsent, false);
    expect(c.earningUnavailable, true);
    expect(c.hasConsent, true);
  });

  for (final prior in [0, 30, 50, null]) {
    test('record celebration requires known smaller previous PB ($prior)',
        () async {
      final scope = SessionScope(userId: 'a', organizationId: 'gym');
      final history = PriorHistory(prior);
      final c = ReachTapController(
          scope: scope,
          activeScope: () => scope,
          camera: TapCamera(),
          history: history,
          clockMicros: () => 1,
          engine: FinishedEngine(),
          autoTick: false);
      addTearDown(c.dispose);
      await c.startCamera(consented: true);
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(c.newPersonalBest, prior != null && prior < 30);
      await c.restart();
      expect(c.newPersonalBest, false);
    });
  }
  testWidgets('results celebrates saved record with hits only', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: MoveCatchResultPanel(
                score: 30,
                caught: 3,
                missed: 0,
                obstacles: 0,
                bestScore: 30,
                bestScoreAvailable: true,
                bestSaved: true,
                scoreSaveFailed: false,
                newPersonalBest: true,
                gameTitle: 'Reach & Tap',
                hitsOnly: true,
                onReplay: () {},
                onExit: () {}))));
    expect(find.text('New personal best!'), findsOneWidget);
    expect(find.text('Targets hit'), findsOneWidget);
    expect(find.text('Missed'), findsNothing);
    expect(find.text('Reward points'), findsOneWidget);
    await tester.ensureVisible(find.text('Play again'));
    expect(tester.takeException(), isNull);
  });
}
