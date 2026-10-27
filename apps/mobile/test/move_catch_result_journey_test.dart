import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/gamification/application/move_and_catch_controller.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_and_catch.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_catch_ports.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/move_and_catch_view.dart';

class _ResultEngine extends Fake implements MoveCatchEngine {
  @override
  MoveCatchPhase phase = MoveCatchPhase.finished;
  @override
  int score = 75, caught = 8, missed = 3, obstaclesHit = 1;
  @override
  double playerX = .5, remainingSeconds = 0, calibrationProgress = 0;
  @override
  int countdownSeconds = 0, trackingGraceSeconds = 0;
  @override
  bool inTrackingGrace = false;
  @override
  List<MoveCatchObject> objects = [];
  @override
  void restart(int nowMicros) => phase = MoveCatchPhase.calibrating;
  @override
  void pause(int nowMicros) {}
}

class _Camera extends MoveCatchCamera {
  int resumes = 0, closes = 0;
  @override
  bool get tracking => true;
  @override
  String? get error => null;
  @override
  Future<void> start(void Function(MoveCatchTorsoSample) onSample) async {}
  @override
  Future<void> resume() async => resumes++;
  @override
  Future<void> pause() async {}
  @override
  Future<void> close() async => closes++;
}

class _BestScores implements MoveCatchBestScoreStore {
  @override
  Future<int> load(SessionScope scope) async => 90;
  @override
  Future<int> record(SessionScope scope, int score,
          {required bool Function() isCurrent}) async =>
      90;
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

void main() {
  late _ResultEngine engine;
  late _Camera camera;
  late MoveAndCatchController controller;
  setUp(() {
    engine = _ResultEngine();
    camera = _Camera();
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    controller = MoveAndCatchController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        bestScores: _BestScores(),
        engine: engine,
        autoTick: false)
      ..hasConsent = true;
  });
  tearDown(() => controller.dispose());

  Future<void> show(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: MoveAndCatchView(
            controller: controller, viewport: const _Viewport())));
  }

  testWidgets(
      'completed result separates actual game stats from inactive rewards',
      (tester) async {
    controller
      ..bestScoreAvailable = true
      ..bestScore = 90
      ..bestSaved = true;
    await show(tester);
    expect(find.text('Round complete'), findsOneWidget);
    expect(find.bySemanticsLabel('Game score 75'), findsOneWidget);
    expect(find.text('75'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Caught'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Obstacles'), findsOneWidget);
    expect(find.text('Personal best: 90'), findsOneWidget);
    expect(find.text('Personal best saved on this device.'), findsOneWidget);
    expect(find.text('Reward points'), findsOneWidget);
    expect(find.text('Not active'), findsOneWidget);
    expect(find.text('No reward points are awarded for this game.'),
        findsOneWidget);
    expect(find.textContaining('New record'), findsNothing);
    expect(find.textContaining('+0'), findsNothing);
    expect(find.text('Back to games'), findsOneWidget);
  });

  testWidgets('unavailable personal best and save failure still allow replay',
      (tester) async {
    controller.scoreSaveFailed = true;
    await show(tester);
    expect(find.text('Personal best unavailable'), findsOneWidget);
    expect(find.text('Personal best saved on this device.'), findsNothing);
    expect(
        find.text(
            'Personal best could not be saved. This round is still complete.'),
        findsOneWidget);
    final viewportState = tester.state(find.byType(_Viewport));
    await tester.ensureVisible(find.text('Play again'));
    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(engine.phase, MoveCatchPhase.calibrating);
    expect(camera.resumes, 1);
    expect(find.text('Find your starting position'), findsOneWidget);
    expect(
        identical(tester.state(find.byType(_Viewport)), viewportState), isTrue);
  });

  testWidgets('result loading prevents duplicate replay', (tester) async {
    controller.loading = true;
    await show(tester);
    await tester.ensureVisible(find.text('Play again'));
    final replay = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Play again'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton)));
    expect(replay.onPressed, isNull);
    expect(camera.resumes, 0);
  });

  testWidgets('completed result exit delegates to route-owned navigation',
      (tester) async {
    var exits = 0;
    await tester.pumpWidget(MaterialApp(
        home: MoveAndCatchView(
            controller: controller,
            viewport: const _Viewport(),
            onExit: () async => exits++)));
    await tester.ensureVisible(find.text('Back to games'));
    await tester.tap(find.text('Back to games'));
    await tester.pump();
    expect(exits, 1);
    expect(camera.closes, 0);
  });

  testWidgets('small result scrolls at twice text size with reachable actions',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await show(tester, textScale: 2);
    for (final label in ['Play again', 'Back to games']) {
      final finder = find.text(label);
      await tester.ensureVisible(finder);
      final button = find.ancestor(
          of: finder,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    }
  });
}
