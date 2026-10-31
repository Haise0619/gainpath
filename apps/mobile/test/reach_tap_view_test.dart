import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reach_tap_exit_guard.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap_ports.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'support/reach_tap_fixture.dart' as fixture;
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/application/reach_tap_controller.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reach_tap_view.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_games_screen.dart';
import 'package:gainpath_mobile/navigation/feature_navigation.dart';
import 'reach_tap_controller_test.dart' show TapCamera, TapHistory;

class DelayedFailHistory extends TapHistory {
  final gate = Completer<void>();
  @override
  Future<ReachTapHistory> record(SessionScope scope, ReachTapRound round,
      {required bool Function() isCurrent}) async {
    await gate.future;
    throw StateError('disk failed after exit');
  }
}

void main() {
  testWidgets('separate supported challenge opens only Reach & Tap route',
      (tester) async {
    String? launched;
    await tester.pumpWidget(MaterialApp(
        home: const MiniGamesScreen(connected: true),
        onGenerateRoute: (s) {
          launched = s.name;
          return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Reach camera route')));
        }));
    await tester.pumpAndSettle();
    expect(find.text('Move & Catch'), findsNWidgets(2));
    await tester.ensureVisible(find.byTooltip('View Reach & Tap details'));
    await tester.tap(find.byTooltip('View Reach & Tap details'));
    await tester.pumpAndSettle();
    expect(launched, isNull);
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    expect(launched, FeatureNavigation.reachAndTap);
  });
  testWidgets(
      'compact enlarged-text consent is scrollable and no camera opens without permission',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final camera = TapCamera();
    final scope = SessionScope(userId: 'a', organizationId: 'org');
    final c = ReachTapController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        history: TapHistory(),
        clockMicros: () => 0,
        autoTick: false);
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: ReachTapView(
            controller: c, viewport: const ColoredBox(color: Colors.black))));
    expect(camera.starts, 0);
    expect(find.text('Game Score is separate from Reward Points.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Start camera'));
    await tester.tap(find.text('Start camera'));
    await tester.pumpAndSettle();
    expect(camera.starts, 1);
    expect(find.byKey(const ValueKey('reach-tap-board')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'exit waits for pending save and asks before losing a failed completed result',
      (tester) async {
    var now = 1000000;
    final camera = TapCamera(), history = DelayedFailHistory();
    final scope = SessionScope(userId: 'a', organizationId: 'org');
    final c = ReachTapController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        history: history,
        clockMicros: () => now,
        autoTick: false);
    addTearDown(c.dispose);
    await c.startCamera(consented: true);
    for (var i = 0; i < 1100 && c.engine.phase != ReachTapPhase.finished; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
    }
    await tester.pump();
    expect(c.saving, true);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push<bool>(
                        context,
                        MaterialPageRoute<bool>(
                            builder: (_) => ReachTapExitGuard(
                                controller: c,
                                builder: (exit) => ReachTapView(
                                    controller: c,
                                    viewport:
                                        const ColoredBox(color: Colors.black),
                                    onExit: exit)))),
                    child: const Text('Open game'))))));
    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to games'));
    await tester.pump();
    history.gate.complete();
    await tester.pumpAndSettle();
    expect(
        find.text(
            'This completed result has not been saved. Leave without saving?'),
        findsOneWidget);
    expect(c.current, true);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Retry saving'), findsOneWidget);
    expect(c.current, true);
  });
  testWidgets('resume does not replay an old +10 hit effect', (tester) async {
    var now = 1000000;
    final camera = TapCamera(),
        scope = SessionScope(userId: 'a', organizationId: 'org');
    final c = ReachTapController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        history: TapHistory(),
        clockMicros: () => now,
        autoTick: false,
        engine: ReachTapEngine(random: Random(4)));
    addTearDown(c.dispose);
    await c.startCamera(consented: true);
    await tester.pumpWidget(MaterialApp(
        home: ReachTapView(
            controller: c, viewport: const ColoredBox(color: Colors.black))));
    for (var i = 0; i < 130 && c.engine.phase != ReachTapPhase.playing; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
      await tester.pump();
    }
    final target = c.engine.target!;
    for (var i = 0; i < 12 && c.engine.hits == 0; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now, leftHand: target));
      c.tick();
      await tester.pump();
    }
    expect(c.engine.hits, 1);
    await tester.pump(const Duration(milliseconds: 600));
    await c.pause();
    await tester.pump();
    await c.resume();
    for (var i = 0; i < 130 && c.engine.phase != ReachTapPhase.playing; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
      await tester.pump();
    }
    expect(c.engine.hits, 1);
    final opacity = tester.widget<Opacity>(find
        .ancestor(of: find.text('+10'), matching: find.byType(Opacity))
        .first);
    expect(opacity.opacity, 0);
  });
}
