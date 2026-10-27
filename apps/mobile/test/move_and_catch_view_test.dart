import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/application/move_and_catch_controller.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/move_and_catch_view.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_and_catch.dart';
import 'package:gainpath_mobile/features/gamification/application/mini_game_round_coordinator.dart';

class _Engine extends Fake implements MoveCatchEngine {
  @override
  MoveCatchPhase phase = MoveCatchPhase.calibrating;
  @override
  int score = 30, caught = 3, obstaclesHit = 1, missed = 2;
  @override
  double remainingSeconds = 40, calibrationProgress = .5, playerX = .5;
  @override
  int countdownSeconds = 3;
  @override
  bool trackingReady = true;
  @override
  bool inTrackingGrace = false;
  @override
  int trackingGraceSeconds = 0;
  @override
  List<MoveCatchObject> objects = [];
}

class _Controller extends ChangeNotifier implements MoveAndCatchController {
  @override
  MiniGameRoundCoordinator? get roundTiming => null;
  @override
  final _Engine engine = _Engine();
  int starts = 0, pauses = 0, resumes = 0, replays = 0;
  @override
  void startRound() {
    starts++;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<void> restart() async {
    replays++;
  }

  @override
  bool hasConsent = false;
  @override
  bool current = true;
  @override
  bool loading = false;
  @override
  String? error;
  @override
  int bestScore = 0;
  @override
  bool bestSaved = false;
  @override
  bool scoreSaveFailed = false;
  @override
  bool bestScoreAvailable = false;
  int cameraCalls = 0;
  @override
  Future<void> startCamera({required bool consented}) async {
    cameraCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('tracking warning counts down without replacing play with Resume',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _Controller()..hasConsent = true;
    c.engine.phase = MoveCatchPhase.playing;
    c.engine.inTrackingGrace = true;
    c.engine.trackingGraceSeconds = 2;
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: MoveAndCatchView(
            controller: c, viewport: const ColoredBox(color: Colors.black))));
    expect(find.text('Pausing in 2s · move into view'), findsOneWidget);
    await tester.ensureVisible(find.text('Pause'));
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'active countdown tracking-loss and result controls scroll at large text',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = _Controller()..hasConsent = true;
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: MoveAndCatchView(controller: c, viewport: const _Viewport())));
    for (final phase in [
      MoveCatchPhase.ready,
      MoveCatchPhase.countdown,
      MoveCatchPhase.playing,
      MoveCatchPhase.trackingLost,
      MoveCatchPhase.finished
    ]) {
      c.engine.phase = phase;
      c.notifyListeners();
      await tester.pump();
      await tester.ensureVisible(find
          .text(phase == MoveCatchPhase.finished ? 'Back to games' : 'Exit'));
      expect(tester.takeException(), null);
    }
    c.bestScoreAvailable = true;
    c.bestScore = 90;
    c.bestSaved = true;
    c.notifyListeners();
    await tester.pump();
    expect(find.text('Personal best: 90'), findsOneWidget);
  });
  testWidgets(
      'state controls preserve viewport while showing real round results',
      (tester) async {
    final c = _Controller()..hasConsent = true;
    const viewport = _Viewport();
    await tester.pumpWidget(
        MaterialApp(home: MoveAndCatchView(controller: c, viewport: viewport)));
    final state = tester.state(find.byType(_Viewport));
    expect(find.text('Find your starting position'), findsOneWidget);
    c.engine.phase = MoveCatchPhase.ready;
    c.notifyListeners();
    await tester.pump();
    await tester.ensureVisible(find.text('Start round'));
    await tester.tap(find.text('Start round'));
    expect(c.starts, 1);
    c.engine.phase = MoveCatchPhase.playing;
    c.notifyListeners();
    await tester.pump();
    await tester.ensureVisible(find.text('Pause'));
    await tester.tap(find.text('Pause'));
    expect(c.pauses, 1);
    c.engine.phase = MoveCatchPhase.paused;
    c.engine.trackingReady = false;
    c.notifyListeners();
    await tester.pump();
    await tester.ensureVisible(find.text('Resume'));
    await tester.tap(find.text('Resume'));
    expect(c.resumes, 1);
    c.engine.phase = MoveCatchPhase.trackingLost;
    c.notifyListeners();
    await tester.pump();
    expect(find.text('Step back into view'), findsOneWidget);
    c.engine.phase = MoveCatchPhase.finished;
    c.notifyListeners();
    await tester.pump();
    expect(find.bySemanticsLabel('Game score 30'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Personal best unavailable'), findsOneWidget);
    expect(find.text('No reward points are awarded for this game.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Play again'));
    await tester.tap(find.text('Play again'));
    expect(c.replays, 1);
    expect(identical(tester.state(find.byType(_Viewport)), state), true);
  });
  testWidgets('camera needs explicit consent and explains local scores',
      (tester) async {
    final controller = _Controller();
    await tester.pumpWidget(MaterialApp(
        home: MoveAndCatchView(
            controller: controller,
            viewport: const SizedBox(key: Key('viewport')))));
    expect(controller.cameraCalls, 0);
    expect(find.byKey(const Key('viewport')), findsNothing);
    expect(find.textContaining('Game scores are not reward points.'),
        findsOneWidget);
    await tester.tap(find.text('Enable camera'));
    await tester.pump();
    expect(controller.cameraCalls, 1);
  });
  testWidgets('consent fits large text and hides on session change',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _Controller();
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: MoveAndCatchView(
            controller: controller, viewport: const SizedBox())));
    await tester.ensureVisible(find.text('Enable camera'));
    expect(tester.takeException(), null);
    controller.current = false;
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('Enable camera'), findsNothing);
  });
}

class _Viewport extends StatefulWidget {
  const _Viewport();
  @override
  State<_Viewport> createState() => _ViewportState();
}

class _ViewportState extends State<_Viewport> {
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}
