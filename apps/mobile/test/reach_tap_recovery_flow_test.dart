import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/application/reach_tap_controller.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/reach_tap_view.dart';
import 'reach_tap_controller_test.dart' show TapCamera, TapHistory;
import 'support/reach_tap_fixture.dart' as fixture;

class RecoveryCamera extends TapCamera {
  void interrupt() {
    tracking = false;
    notifyListeners();
  }
}

class RecoveryHarness {
  RecoveryHarness() {
    active = scope;
    controller = ReachTapController(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        history: TapHistory(),
        clockMicros: () => now,
        autoTick: false,
        engine: ReachTapEngine(random: Random(45)));
  }
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  late SessionScope? active;
  final camera = RecoveryCamera();
  late final ReachTapController controller;
  int now = 1000000;
  void frame({bool missing = false}) {
    now += 50000;
    camera.receive!(missing ? null : fixture.reachTapSample(now));
    controller.tick();
  }

  Future<void> start() async {
    await controller.startCamera(consented: true);
    for (var i = 0;
        i < 130 && controller.engine.phase != ReachTapPhase.playing;
        i++) {
      frame();
    }
    expect(controller.engine.phase, ReachTapPhase.playing);
  }
}

void main() {
  test('one-second hand loss freezes then restores the same target hands-free',
      () async {
    final h = RecoveryHarness();
    addTearDown(h.controller.dispose);
    await h.start();
    final e = h.controller.engine, target = e.target, active = e.activeMicros;
    for (var i = 0; i < 20; i++) {
      h.frame(missing: true);
    }
    expect(e.phase.name, 'recovering');
    expect(e.target, target);
    expect(e.score, 0);
    expect(e.activeMicros, active);
    for (var i = 0; i < 8; i++) {
      h.frame();
    }
    expect(e.phase.name, 'recovering');
    expect(e.activeMicros, active);
    expect(e.score, 0);
    h.frame();
    expect(e.phase, ReachTapPhase.playing);
    expect(e.target, target);
    expect(e.activeMicros, active);
    expect(e.score, 0);
    expect(h.camera.starts, 1);
    expect(h.camera.resumes, 0);
    expect(h.camera.pauses, 0);
  });
  test(
      'prolonged loss restarts alignment automatically without crediting the loss',
      () async {
    final h = RecoveryHarness();
    addTearDown(h.controller.dispose);
    await h.start();
    final e = h.controller.engine, active = e.activeMicros;
    for (var i = 0; i < 80; i++) {
      h.frame(missing: true);
    }
    expect(e.activeMicros, active);
    expect(e.score, 0);
    h.frame();
    expect(e.phase, ReachTapPhase.calibrating);
    for (var i = 0; i < 130 && e.phase != ReachTapPhase.playing; i++) {
      h.frame();
    }
    expect(e.phase, ReachTapPhase.playing);
    expect(e.activeMicros, active);
    expect(e.score, 0);
    expect(h.camera.resumes, 0);
  });
  test('background during recovery cannot resume itself on fresh hands',
      () async {
    final h = RecoveryHarness();
    addTearDown(h.controller.dispose);
    await h.start();
    h.frame(missing: true);
    await h.controller.background();
    h.controller.foreground();
    for (var i = 0; i < 50; i++) {
      h.frame();
    }
    expect(h.controller.engine.phase, ReachTapPhase.paused);
    expect(h.controller.engine.score, 0);
    await h.controller.resume();
    expect(h.camera.resumes, 1);
    expect(h.controller.engine.phase, ReachTapPhase.calibrating);
  });
  test(
      'camera hardware interruption requires explicit Resume rather than pose recovery',
      () async {
    final h = RecoveryHarness();
    addTearDown(h.controller.dispose);
    await h.start();
    h.frame(missing: true);
    h.camera.interrupt();
    for (var i = 0; i < 50; i++) {
      h.frame();
    }
    expect(h.controller.engine.phase, ReachTapPhase.paused);
    expect(h.controller.error, isNotNull);
    expect(h.controller.engine.score, 0);
    h.camera.tracking = true;
    await h.controller.resume();
    expect(h.camera.resumes, 1);
    expect(h.controller.engine.phase, ReachTapPhase.calibrating);
  });
  testWidgets(
      'compact recovery feedback needs no tap; manual pause retains Resume',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = RecoveryHarness();
    addTearDown(h.controller.dispose);
    await h.start();
    h.frame(missing: true);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: ReachTapView(
            controller: h.controller,
            viewport: const ColoredBox(color: Colors.black))));
    expect(find.text('Show your body and a hand to continue automatically'),
        findsOneWidget);
    final board = tester.getRect(find.byKey(const ValueKey('reach-tap-board')));
    final cue = tester.getRect(
        find.text('Show your body and a hand to continue automatically'));
    expect(cue.top, greaterThanOrEqualTo(board.top));
    expect(cue.bottom, lessThanOrEqualTo(board.bottom));
    expect(find.text('Resume'), findsNothing);
    expect(tester.takeException(), isNull);
    await h.controller.pause();
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('automatic recovery overlay never replays a previous hit effect',
      (tester) async {
    final h = RecoveryHarness();
    addTearDown(h.controller.dispose);
    await h.start();
    await tester.pumpWidget(MaterialApp(
        home: ReachTapView(
            controller: h.controller,
            viewport: const ColoredBox(color: Colors.black))));
    final target = h.controller.engine.target!;
    for (var i = 0; i < 16 && h.controller.engine.hits == 0; i++) {
      h.now += 50000;
      h.camera.receive!(fixture.reachTapSample(h.now, leftHand: target));
      h.controller.tick();
      await tester.pump();
    }
    expect(h.controller.engine.hits, 1);
    await tester.pump(const Duration(milliseconds: 600));
    double hitOpacity() => tester
        .widget<Opacity>(find
            .ancestor(of: find.text('+10'), matching: find.byType(Opacity))
            .first)
        .opacity;
    expect(hitOpacity(), 0);
    h.frame(missing: true);
    await tester.pump();
    expect(h.controller.engine.phase, ReachTapPhase.recovering);
    expect(hitOpacity(), 0);
    for (var i = 0; i < 9; i++) {
      h.frame();
      await tester.pump();
    }
    expect(h.controller.engine.phase, ReachTapPhase.playing);
    expect(h.controller.engine.hits, 1);
    expect(hitOpacity(), 0);
  });
}
