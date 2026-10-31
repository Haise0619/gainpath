import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'support/reach_tap_fixture.dart';

int start(ReachTapEngine engine) {
  for (var t = 1000000; t < 8000000; t += 50000) {
    engine.update(reachTapSample(t), nowMicros: t);
    if (engine.phase == ReachTapPhase.playing) return t;
  }
  fail('Fresh stable alignment must start play');
}

void main() {
  test('one-second both-hand dropout returns hands-free to the same target',
      () {
    final engine = ReachTapEngine(random: Random(4));
    final t = start(engine);
    final target = engine.target;
    final active = engine.activeMicros;
    engine.update(reachTapSample(t + 50000, missingBothHands: true),
        nowMicros: t + 50000);
    expect(engine.phase.name, 'recovering');
    expect(engine.leftHand, isNull);
    expect(engine.rightHand, isNull);
    for (var time = t + 100000; time <= t + 1000000; time += 50000) {
      engine.unavailable(time);
    }
    for (var time = t + 1050000; time <= t + 1450000; time += 50000) {
      engine.update(reachTapSample(time, leftHand: target), nowMicros: time);
    }
    expect(engine.phase, ReachTapPhase.playing);
    expect(engine.target, target);
    expect(engine.activeMicros, active);
    expect(engine.hits, 0);
  });

  test('interrupted returning hold restarts without extending loss deadline',
      () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 50000);
    for (var n = 100000; n <= 350000; n += 50000) {
      e.update(reachTapSample(t + n), nowMicros: t + n);
    }
    expect(e.recoveryProgress, closeTo(.625, .001));
    e.unavailable(t + 400000);
    expect(e.recoveryProgress, 0);
    for (var n = 450000; n <= 800000; n += 50000) {
      e.update(reachTapSample(t + n), nowMicros: t + n);
    }
    expect(e.phase.name, 'recovering');
    e.update(reachTapSample(t + 850000), nowMicros: t + 850000);
    expect(e.phase, ReachTapPhase.playing);
  });

  test('missing frames cannot extend the fixed three-second recovery window',
      () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 50000);
    for (var n = 100000; n < 3050000; n += 50000) {
      e.unavailable(t + n);
    }
    expect(e.phase.name, 'recovering');
    e.tick(t + 3050000);
    expect(e.phase, ReachTapPhase.trackingLost);
    expect(e.target, isNull);
    expect(e.activeMicros, 0);
    e.update(reachTapSample(t + 3100000), nowMicros: t + 3100000);
    expect(e.phase, ReachTapPhase.calibrating);
    expect(e.calibrationProgress, 0);
    for (var n = 3150000; n <= 5050000; n += 50000) {
      e.update(reachTapSample(t + n), nowMicros: t + n);
    }
    expect(e.phase, ReachTapPhase.calibrating);
    e.update(reachTapSample(t + 5100000), nowMicros: t + 5100000);
    expect(e.phase, ReachTapPhase.ready);
    for (var n = 5150000; n <= 8400000; n += 50000) {
      e.update(reachTapSample(t + n), nowMicros: t + n);
    }
    expect(e.phase, ReachTapPhase.playing);
    expect(e.activeMicros, 0);
  });

  for (final kind in ['geometry', 'body']) {
    test('$kind change requires full fresh hands-free alignment', () {
      final e = ReachTapEngine();
      final t = start(e);
      e.unavailable(t + 50000);
      e.update(
          reachTapSample(t + 100000,
              geometryKey: kind == 'geometry' ? 'rotated' : 'front',
              scale: kind == 'body' ? 1.4 : 1),
          nowMicros: t + 100000);
      expect(e.phase, ReachTapPhase.trackingLost);
      expect(e.target, isNull);
      e.update(
          reachTapSample(t + 150000,
              geometryKey: kind == 'geometry' ? 'rotated' : 'front',
              scale: kind == 'body' ? 1.4 : 1),
          nowMicros: t + 150000);
      expect(e.phase, ReachTapPhase.calibrating);
      expect(e.calibrationProgress, 0);
      expect(e.hits, 0);
    });
  }

  test('timer-only return never completes a recovery hold', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 50000);
    e.update(reachTapSample(t + 100000), nowMicros: t + 100000);
    for (var n = 150000; n <= 1000000; n += 50000) {
      e.tick(t + n);
    }
    expect(e.phase.name, 'recovering');
    expect(e.recoveryProgress, 0);
    expect(e.leftHand, isNull);
    expect(e.activeMicros, 0);
  });

  for (final malformed in ['duplicate', 'future', 'stale', 'backward']) {
    test('$malformed returning sample cannot contribute hold time', () {
      final e = ReachTapEngine();
      final t = start(e);
      e.unavailable(t + 50000);
      for (var n = 100000; n <= 400000; n += 50000) {
        e.update(reachTapSample(t + n), nowMicros: t + n);
      }
      final capture = switch (malformed) {
        'duplicate' => t + 400000,
        'future' => t + 450001,
        'stale' => t + 200000,
        _ => t + 450000,
      };
      e.update(reachTapSample(capture),
          nowMicros: malformed == 'backward' ? t + 399999 : t + 450000);
      expect(e.phase, isNot(ReachTapPhase.playing));
      expect(e.recoveryProgress, 0);
      expect(e.hits, 0);
      expect(e.activeMicros, 0);
      expect(e.leftHand, isNull);
    });
  }

  test('arrival and capture gap freeze time before starting fresh hold', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.update(reachTapSample(t + 1000000), nowMicros: t + 1000000);
    expect(e.phase.name, 'recovering');
    expect(e.recoveryProgress, 0);
    expect(e.activeMicros, 0);
    for (var n = 1050000; n <= 1400000; n += 50000) {
      e.update(reachTapSample(t + n), nowMicros: t + n);
    }
    expect(e.phase, ReachTapPhase.playing);
    expect(e.activeMicros, 0);
  });

  test('old pre-loss frames cannot seed the returning hold', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 150000);
    e.update(reachTapSample(t + 100000), nowMicros: t + 200000);
    expect(e.leftHand, isNull);
    expect(e.recoveryProgress, 0);
    for (var n = 250000; n <= 600000; n += 50000) {
      e.update(reachTapSample(t + n), nowMicros: t + n);
    }
    expect(e.phase.name, 'recovering');
    e.update(reachTapSample(t + 650000), nowMicros: t + 650000);
    expect(e.phase, ReachTapPhase.playing);
  });

  test('returning reaching hands may overlap elbows without recalibrating', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 50000);
    for (var n = 100000; n <= 500000; n += 50000) {
      e.update(
          reachTapSample(t + n,
              leftHand: const Point(.30, .43),
              rightHand: const Point(.70, .43)),
          nowMicros: t + n);
    }
    expect(e.phase, ReachTapPhase.playing);
    expect(e.activeMicros, 0);
  });

  test('manual pause wins during recovery and blocks automatic alignment', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 50000);
    e.pause(t + 100000);
    for (var n = 150000; n < 7000000; n += 50000) {
      e.update(reachTapSample(t + n), nowMicros: t + n);
    }
    expect(e.phase, ReachTapPhase.paused);
    expect(e.target, isNull);
    expect(e.activeMicros, 0);
  });

  test('recovery discards old hit dwell and completion never scores', () {
    final e = ReachTapEngine(random: Random(2));
    var t = start(e);
    final p = e.target!;
    // Establish 80 ms of a hit hold after the smoothed cursor arrives.
    for (var i = 0; i < 15; i++) {
      t += 5000;
      e.update(reachTapSample(t, leftHand: p), nowMicros: t);
    }
    expect(e.hits, 0);
    e.unavailable(t + 5000);
    final frozen = e.activeMicros;
    t += 10000;
    for (var n = 0; n <= 400000; n += 50000) {
      e.update(reachTapSample(t + n, leftHand: p), nowMicros: t + n);
    }
    t += 400000;
    expect(e.phase, ReachTapPhase.playing);
    expect(e.hits, 0);
    expect(e.activeMicros, frozen);
    e.update(reachTapSample(t + 50000, leftHand: p), nowMicros: t + 50000);
    e.update(reachTapSample(t + 100000, leftHand: p), nowMicros: t + 100000);
    expect(e.hits, 0);
    e.update(reachTapSample(t + 150000, leftHand: p), nowMicros: t + 150000);
    expect(e.hits, 1);
    expect(e.score, 10);
    expect(e.activeMicros, frozen + 150000);
  });

  test('hard reacquisition preserves earned score and active time', () {
    final e = ReachTapEngine(random: Random(2));
    var t = start(e);
    final p = e.target!;
    while (e.hits == 0) {
      t += 50000;
      e.update(reachTapSample(t, leftHand: p), nowMicros: t);
    }
    final frozen = e.activeMicros;
    e.update(reachTapSample(t + 50000, geometryKey: 'changed'),
        nowMicros: t + 50000);
    for (var n = 100000; n <= 5400000; n += 50000) {
      e.update(reachTapSample(t + n, geometryKey: 'changed'), nowMicros: t + n);
    }
    expect(e.phase, ReachTapPhase.playing);
    expect(e.hits, 1);
    expect(e.score, 10);
    expect(e.activeMicros, frozen);
  });

  test('batched captures cannot compress the observed 400 ms arrival hold', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 50000);
    e.update(reachTapSample(t + 100000), nowMicros: t + 100000);
    for (var n = 150000; n <= 300000; n += 50000) {
      e.tick(t + n);
    }
    // The capture cadence remains fresh but these frames arrive together.
    for (var n = 250000; n <= 500000; n += 50000) {
      e.update(reachTapSample(t + n), nowMicros: t + 500000);
    }
    expect(e.phase.name, 'recovering');
    expect(e.recoveryProgress, 0);
    expect(e.hits, 0);
    expect(e.activeMicros, 0);
  });

  test('capture gap rejects delayed frame that predates the loss arrival', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.tick(t + 150000);
    e.update(reachTapSample(t + 250000), nowMicros: t + 300000);
    expect(e.phase.name, 'recovering');
    expect(e.leftHand, isNull);
    expect(e.recoveryProgress, 0);
    expect(e.activeMicros, 150000);
  });

  for (final latency in [60000, 100000, 150000]) {
    test('constant $latency us delivery latency cannot chase recovery floor',
        () {
      final e = ReachTapEngine();
      final t = start(e);
      e.unavailable(t + 50000);
      for (var n = 100000; n <= 1000000; n += 50000) {
        e.unavailable(t + n);
      }
      for (var n = 1050000; n <= 1600000; n += 50000) {
        e.update(reachTapSample(t + n - latency), nowMicros: t + n);
      }
      expect(e.phase, ReachTapPhase.playing);
      expect(e.activeMicros, lessThanOrEqualTo(150000));
      expect(e.hits, 0);
    });
  }

  test('long-loss full alignment admits delayed fresh camera observations', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 50000);
    for (var n = 100000; n <= 4000000; n += 50000) {
      e.unavailable(t + n);
    }
    expect(e.phase, ReachTapPhase.trackingLost);
    for (var n = 4050000; n <= 9500000; n += 50000) {
      e.update(reachTapSample(t + n - 150000), nowMicros: t + n);
    }
    expect(e.phase, ReachTapPhase.playing);
    expect(e.activeMicros, lessThanOrEqualTo(200000));
  });

  test('partial alignment interruption admits delayed fresh observations', () {
    final e = ReachTapEngine();
    for (var t = 1000000; t <= 2000000; t += 50000) {
      e.update(reachTapSample(t - 100000), nowMicros: t);
    }
    e.unavailable(2050000);
    e.unavailable(2100000);
    for (var t = 2150000; t <= 7600000; t += 50000) {
      e.update(reachTapSample(t - 100000), nowMicros: t);
    }
    expect(e.phase, ReachTapPhase.playing);
  });
}
