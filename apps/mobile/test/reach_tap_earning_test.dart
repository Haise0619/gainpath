import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/application/reach_tap_controller.dart';
import 'package:gainpath_mobile/features/gamification/application/mini_game_round_coordinator.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'reach_tap_controller_test.dart' show TapCamera, TapHistory;
import 'mini_game_round_coordinator_test.dart' show Repo;
import 'support/reach_tap_fixture.dart' as fixture;

class EarningTiming extends MiniGameRoundCoordinator {
  EarningTiming() : super(repository: Repo());
  int starts = 0, finishes = 0, resets = 0, observations = 0;
  @override
  void start() {
    starts++;
  }

  @override
  void observe({required int activeMillis, required bool playing}) {
    observations++;
  }

  @override
  void finish() {
    finishes++;
  }

  @override
  void reset() {
    resets++;
  }
}

void main() {
  final scope = SessionScope(userId: 'a', organizationId: 'gym');
  for (final earning in [false, true]) {
    test(
        'Reach complete round reports timing only with explicit earning choice $earning',
        () async {
      var now = 1000000;
      final camera = TapCamera(), timing = EarningTiming();
      final c = ReachTapController(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          history: TapHistory(),
          clockMicros: () => now,
          autoTick: false,
          roundTiming: timing,
          earningAvailable: () async => true);
      addTearDown(c.dispose);
      c.setRoundTimingConsent(earning);
      await c.startCamera(consented: true);
      for (var i = 0;
          i < 1000 && c.engine.phase != ReachTapPhase.finished;
          i++) {
        now += 50000;
        camera.receive!(fixture.reachTapSample(now));
        c.tick();
      }
      await Future<void>.delayed(Duration.zero);
      expect(c.engine.phase, ReachTapPhase.finished);
      expect(c.saved, true);
      expect(timing.starts, earning ? 1 : 0);
      expect(timing.finishes, earning ? 1 : 0);
      expect(timing.observations > 0, earning);
    });
  }
  test(
      'Reach expired allowance falls back to Fun before camera and remains local',
      () async {
    final camera = TapCamera(), timing = EarningTiming();
    final c = ReachTapController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        history: TapHistory(),
        clockMicros: () => 1000000,
        autoTick: false,
        roundTiming: timing,
        earningAvailable: () async => false);
    addTearDown(c.dispose);
    c.setRoundTimingConsent(true);
    await c.startCamera(consented: true);
    expect(c.roundTimingConsent, false);
    expect(c.earningUnavailable, true);
    expect(camera.starts, 1);
    expect(timing.starts, 0);
  });
  test('Reach late eligibility cannot open camera after account changes',
      () async {
    SessionScope? active = scope;
    final gate = Completer<bool>(), camera = TapCamera();
    final c = ReachTapController(
        scope: scope,
        activeScope: () => active,
        camera: camera,
        history: TapHistory(),
        clockMicros: () => 0,
        autoTick: false,
        roundTiming: EarningTiming(),
        earningAvailable: () => gate.future);
    addTearDown(c.dispose);
    c.setRoundTimingConsent(true);
    final starting = c.startCamera(consented: true);
    active = null;
    gate.complete(true);
    await starting;
    expect(camera.starts, 0);
    expect(c.current, false);
  });
  test(
      'Reach Replay rechecks earned allowance and keeps explicit camera consent',
      () async {
    var now = 1000000, reads = 0;
    final camera = TapCamera(), timing = EarningTiming();
    final c = ReachTapController(
        scope: scope,
        activeScope: () => scope,
        camera: camera,
        history: TapHistory(),
        clockMicros: () => now,
        autoTick: false,
        roundTiming: timing,
        earningAvailable: () async => ++reads == 1);
    addTearDown(c.dispose);
    c.setRoundTimingConsent(true);
    await c.startCamera(consented: true);
    for (var i = 0; i < 1000 && c.engine.phase != ReachTapPhase.finished; i++) {
      now += 50000;
      camera.receive!(fixture.reachTapSample(now));
      c.tick();
    }
    await Future<void>.delayed(Duration.zero);
    await c.restart();
    expect(reads, 2);
    expect(c.roundTimingConsent, false);
    expect(c.earningUnavailable, true);
    expect(c.hasConsent, true);
    expect(camera.resumes, 1);
    expect(c.engine.phase, ReachTapPhase.calibrating);
  });
}
