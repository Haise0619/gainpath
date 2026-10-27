import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_and_catch.dart';
import 'move_and_catch_engine_test.dart' show Driver;

void main() {
  test(
      'a fresh frame at the grace boundary cannot bypass timeout before the next tick',
      () {
    for (final gap in [3000000, 3010000]) {
      final d = Driver()..play();
      d.now += gap;
      d.engine.updateTorso(
          centerX: .5,
          shoulderWidth: .3,
          capturedAtMicros: d.now,
          nowMicros: d.now);
      expect(d.engine.phase, MoveCatchPhase.trackingLost);
      expect(d.engine.trackingReady, isTrue);
      d.engine.resume(d.now);
      expect(d.engine.phase, MoveCatchPhase.countdown);
    }
  });
  test('partial torso cannot bypass full calibration', () {
    final engine = MoveCatchEngine();
    for (var now = 50000; now <= 2000000; now += 50000) {
      engine.updateTorso(
          centerX: .5,
          shoulderWidth: .3,
          capturedAtMicros: now,
          nowMicros: now,
          fullTorso: false);
      engine.tick(now);
    }
    expect(engine.phase, MoveCatchPhase.calibrating);
    expect(engine.calibrationProgress, 0);
    expect(engine.trackingReady, isFalse);
  });
  test('one fresh movement reaches near the edge without several frames of lag',
      () {
    final d = Driver()..play();
    d.step(center: 0);
    expect(d.engine.playerX, lessThan(.15));
    final left = d.engine.playerX;
    d.run(1000000, frame: false);
    expect(d.engine.playerX, left);
  });
  test(
      'brief tracking loss warns but continues at held position and recovers automatically',
      () {
    final d = Driver()..play();
    d.step(center: 0);
    final left = d.engine.playerX, remaining = d.engine.remainingSeconds;
    d.run(600000, frame: false);
    expect(d.engine.phase, MoveCatchPhase.playing);
    expect(d.engine.inTrackingGrace, isTrue);
    expect(d.engine.trackingGraceSeconds, 3);
    expect(d.engine.playerX, left);
    expect(d.engine.remainingSeconds, lessThan(remaining));
    d.step(center: .5);
    expect(d.engine.phase, MoveCatchPhase.playing);
    expect(d.engine.inTrackingGrace, isFalse);
    expect(d.engine.playerX, greaterThan(left));
  });
  test(
      'three-second loss pauses; late and duplicate frames cannot extend grace',
      () {
    final d = Driver()..play();
    final capture = d.now;
    d.run(2000000, frame: false);
    expect(d.engine.trackingGraceSeconds, 1);
    d.engine.updateTorso(
        centerX: 1,
        shoulderWidth: .3,
        capturedAtMicros: capture,
        nowMicros: d.now);
    d.run(1000000, frame: false);
    expect(d.engine.phase, MoveCatchPhase.trackingLost);
    final remaining = d.engine.remainingSeconds;
    d.run(500000, frame: false);
    expect(d.engine.remainingSeconds, remaining);
    d.step();
    expect(d.engine.phase, MoveCatchPhase.trackingLost);
    d.engine.resume(d.now);
    expect(d.engine.phase, MoveCatchPhase.countdown);
  });
}
