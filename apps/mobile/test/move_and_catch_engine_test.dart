import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_and_catch.dart';

class CenterRandom implements Random {
  CenterRandom({this.obstacles = false, this.alternating = false});
  final bool obstacles, alternating;
  int _draw = 0;
  @override
  double nextDouble() {
    final index = _draw++;
    if (index.isEven) return .5;
    return obstacles || (alternating && ((index ~/ 2).isOdd)) ? .99 : .01;
  }

  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

class Driver {
  Driver({Random? random, int durationMicros = 40000000})
      : engine = MoveCatchEngine(
            random: random ?? CenterRandom(), durationMicros: durationMicros);
  final MoveCatchEngine engine;
  int now = 0;
  void step(
      {double center = .5,
      double width = .3,
      bool frame = true,
      int micros = 50000}) {
    now += micros;
    if (frame) {
      engine.updateTorso(
          centerX: center,
          shoulderWidth: width,
          capturedAtMicros: now,
          nowMicros: now);
    }
    engine.tick(now);
  }

  void run(int micros, {double center = .5, bool frame = true}) {
    for (var i = 0; i < micros ~/ 50000; i++) {
      step(center: center, frame: frame);
    }
  }

  void calibrate() {
    run(1500000);
    expect(engine.phase, MoveCatchPhase.ready);
  }

  void play() {
    calibrate();
    engine.start(now);
    run(3000000);
    expect(engine.phase, MoveCatchPhase.playing);
  }
}

void main() {
  test(
      'calibration tolerates small jitter and a short dip without per-frame resets',
      () {
    final d = Driver();
    for (var i = 0; i < 12; i++) {
      d.step(center: .5 + (i.isEven ? .009 : -.009));
    }
    final progress = d.engine.calibrationProgress;
    expect(progress, greaterThan(.3));
    d.step(center: .66);
    expect(d.engine.calibrationProgress, greaterThan(progress * .7));
    for (var i = 0; i < 22; i++) {
      d.step(center: .5 + (i.isEven ? .009 : -.009));
    }
    expect(d.engine.phase, MoveCatchPhase.ready);
    expect(d.engine.calibrationProgress, 1);
    expect(d.engine.trackingReady, isTrue);
  });
  test(
      'bad, stale, duplicate and regressing timestamps never advance calibration',
      () {
    final e = MoveCatchEngine();
    for (final x in [double.nan, double.infinity, -.1, 1.1]) {
      e.updateTorso(
          centerX: x, shoulderWidth: .3, capturedAtMicros: 100, nowMicros: 100);
    }
    e.updateTorso(
        centerX: .5, shoulderWidth: .01, capturedAtMicros: 100, nowMicros: 100);
    for (final width in [double.nan, double.infinity, 0.0, 1.01]) {
      e.updateTorso(
          centerX: .5,
          shoulderWidth: width,
          capturedAtMicros: 100,
          nowMicros: 100);
    }
    e.updateTorso(
        centerX: .5, shoulderWidth: .3, capturedAtMicros: 0, nowMicros: 300001);
    e.updateTorso(
        centerX: .5,
        shoulderWidth: .3,
        capturedAtMicros: 500000,
        nowMicros: 400000);
    expect(e.calibrationProgress, 0);
    expect(e.trackingReady, isFalse);
    e.updateTorso(
        centerX: .5,
        shoulderWidth: .3,
        capturedAtMicros: 500000,
        nowMicros: 500000);
    e.updateTorso(
        centerX: .5,
        shoulderWidth: .3,
        capturedAtMicros: 500000,
        nowMicros: 550000);
    e.updateTorso(
        centerX: .5,
        shoulderWidth: .3,
        capturedAtMicros: 450000,
        nowMicros: 560000);
    e.tick(400000);
    expect(e.calibrationProgress, 0);
    expect(e.playerX, .5);
  });
  test('half-second tracking gap stays playable during the warning', () {
    final d = Driver()..play();
    d.run(500000, frame: false);
    expect(d.engine.phase, MoveCatchPhase.playing);
    expect(d.engine.inTrackingGrace, isTrue);
    expect(d.engine.trackingReady, isFalse);
  });
  test('long calibration gap resets progress; pausing cannot skip calibration',
      () {
    final d = Driver();
    d.run(700000);
    expect(d.engine.calibrationProgress, greaterThan(0));
    d.run(600000, frame: false);
    expect(d.engine.calibrationProgress, 0);
    d.engine.pause(d.now);
    d.step();
    d.engine.resume(d.now);
    expect(d.engine.phase, MoveCatchPhase.calibrating);
    expect(d.engine.remainingSeconds, 40);
    expect(d.engine.objects, isEmpty);
    d.engine.start(d.now);
    expect(d.engine.phase, MoveCatchPhase.calibrating);
  });
  test('sustained calibration movement must establish a new stable baseline',
      () {
    final d = Driver();
    d.run(700000);
    d.run(300000, center: .75);
    expect(d.engine.phase, MoveCatchPhase.calibrating);
    expect(d.engine.calibrationProgress, lessThan(.2));
    d.run(1400000, center: .75);
    expect(d.engine.phase, MoveCatchPhase.ready);
  });
  test('seeded simulation is deterministic and observations alone never score',
      () {
    final a = Driver(random: Random(42))..play(),
        b = Driver(random: Random(42))..play();
    a.run(5000000);
    b.run(5000000);
    expect(a.engine.objects.map((o) => (o.id, o.x, o.y, o.kind)).toList(),
        b.engine.objects.map((o) => (o.id, o.x, o.y, o.kind)).toList());
    expect(a.engine.score, b.engine.score);
    final before = a.engine.remainingSeconds, score = a.engine.score;
    for (var i = 0; i < 100; i++) {
      a.engine.updateTorso(
          centerX: .5,
          shoulderWidth: .3,
          capturedAtMicros: a.now + i + 1,
          nowMicros: a.now + i + 1);
    }
    expect(a.engine.remainingSeconds, before);
    expect(a.engine.score, score);
  });
  test('restart rejects pre-round duplicate captures and a regressing clock',
      () {
    final d = Driver()..play();
    d.run(1000000);
    final remaining = d.engine.remainingSeconds;
    d.engine.restart(d.now - 1);
    expect(d.engine.remainingSeconds, remaining);
    expect(d.engine.phase, MoveCatchPhase.playing);
    d.engine.restart(d.now);
    d.engine.updateTorso(
        centerX: .5,
        shoulderWidth: .3,
        capturedAtMicros: d.now,
        nowMicros: d.now);
    expect(d.engine.trackingReady, isFalse);
    d.step();
    expect(d.engine.trackingReady, isTrue);
    expect(d.engine.phase, MoveCatchPhase.calibrating);
  });
  test(
      'deadzone and smoothing map pre-mirrored lean to bounded player position',
      () {
    final d = Driver()..calibrate();
    d.step(center: .505);
    expect(d.engine.playerX, closeTo(.5, .01));
    d.step(center: .68);
    expect(d.engine.playerX, greaterThan(.5));
    expect(d.engine.playerX, lessThan(.92));
    d.run(1500000, center: 1);
    expect(d.engine.playerX, closeTo(.92, .01));
    d.run(2000000, center: 0);
    expect(d.engine.playerX, closeTo(.08, .01));
  });
  test('only active playing consumes round time; resume has another countdown',
      () {
    final d = Driver()..calibrate();
    expect(d.engine.remainingSeconds, 40);
    d.engine.start(d.now);
    expect(d.engine.countdownSeconds, 3);
    d.run(3000000);
    expect(d.engine.remainingSeconds, 40);
    d.run(1000000);
    final remaining = d.engine.remainingSeconds;
    expect(remaining, closeTo(39, .01));
    d.engine.pause(d.now);
    final objects = d.engine.objects.map((o) => (o.id, o.y)).toList();
    d.run(3000000);
    expect(d.engine.phase, MoveCatchPhase.paused);
    expect(d.engine.remainingSeconds, remaining);
    expect(d.engine.objects.map((o) => (o.id, o.y)).toList(), objects);
    d.engine.resume(d.now);
    expect(d.engine.phase, MoveCatchPhase.countdown);
    d.run(3000000);
    expect(d.engine.remainingSeconds, remaining);
    d.run(1000000);
    expect(d.engine.remainingSeconds, closeTo(remaining - 1, .01));
  });
  test(
      'tracking loss freezes objects and requires fresh pose plus manual resume',
      () {
    final d = Driver()..play();
    d.run(1000000);
    d.run(3000000, frame: false);
    final remaining = d.engine.remainingSeconds;
    final objects = d.engine.objects.map((o) => (o.id, o.y)).toList();
    d.run(1000000, frame: false);
    expect(d.engine.phase, MoveCatchPhase.trackingLost);
    expect(d.engine.remainingSeconds, remaining);
    expect(d.engine.objects.map((o) => (o.id, o.y)).toList(), objects);
    d.engine.resume(d.now);
    expect(d.engine.phase, MoveCatchPhase.trackingLost);
    d.step();
    expect(d.engine.phase, MoveCatchPhase.trackingLost);
    d.engine.resume(d.now);
    expect(d.engine.phase, MoveCatchPhase.countdown);
  });
  test(
      'grace expiration pauses countdown; a held basket can catch during brief dropout',
      () {
    final d = Driver()..calibrate();
    d.engine.start(d.now);
    d.run(3000000, frame: false);
    expect(d.engine.phase, MoveCatchPhase.trackingLost);
    expect(d.engine.remainingSeconds, 40);
    d.step();
    d.engine.resume(d.now);
    d.run(3000000);
    while (d.engine.objects.isEmpty || d.engine.objects.first.y < .68) {
      d.step();
    }
    final score = d.engine.score;
    d.run(1200000, frame: false);
    expect(d.engine.score, greaterThan(score));
    expect(d.engine.phase, MoveCatchPhase.playing);
    d.run(2000000, frame: false);
    expect(d.engine.phase, MoveCatchPhase.trackingLost);
  });
  test('a large clock gap with fresh tracking pauses without offscreen scoring',
      () {
    final d = Driver()..play();
    d.run(1500000);
    final remaining = d.engine.remainingSeconds;
    final objects = d.engine.objects.map((o) => (o.id, o.y)).toList();
    d.step(micros: 500000);
    expect(d.engine.phase, MoveCatchPhase.paused);
    expect(d.engine.remainingSeconds, remaining);
    expect(d.engine.objects.map((o) => (o.id, o.y)).toList(), objects);
    expect(d.engine.score, 0);
  });
  test(
      'deterministic stars use actual collisions; obstacles subtract with a zero floor',
      () {
    final stars = Driver()..play();
    stars.run(10000000);
    expect(stars.engine.caught, greaterThan(0));
    expect(stars.engine.score, stars.engine.caught * 10);
    expect(stars.engine.missed, 0);
    final obstacles = Driver(random: CenterRandom(obstacles: true))..play();
    obstacles.run(10000000);
    expect(obstacles.engine.obstaclesHit, greaterThan(0));
    expect(obstacles.engine.score, 0);
    final mixed = Driver(random: CenterRandom(alternating: true))..play();
    mixed.run(10000000);
    expect(mixed.engine.caught, greaterThan(0));
    expect(mixed.engine.obstaclesHit, greaterThan(0));
    expect(mixed.engine.score,
        mixed.engine.caught * 10 - mixed.engine.obstaclesHit * 5);
  });
  test(
      'missed stars never create synthetic catches and object lists are immutable and bounded',
      () {
    final d = Driver()..play();
    for (var i = 0; i < 250; i++) {
      d.step(center: 0);
      expect(d.engine.objects.length, lessThanOrEqualTo(12));
      for (final o in d.engine.objects) {
        expect(o.x, inInclusiveRange(.08, .92));
        expect(o.y, inInclusiveRange(0, 1.1));
      }
    }
    expect(d.engine.caught, 0);
    expect(d.engine.missed, greaterThan(0));
    expect(d.engine.score, 0);
    expect(() => d.engine.objects.clear(), throwsUnsupportedError);
  });
  test('falling speed increases gradually with active elapsed time', () {
    final d = Driver()..play();
    d.run(800000);
    final early = d.engine.objects.first;
    d.step();
    final earlyDelta =
        d.engine.objects.firstWhere((o) => o.id == early.id).y - early.y;
    d.run(20000000);
    final late = d.engine.objects.last;
    d.step();
    final lateDelta =
        d.engine.objects.firstWhere((o) => o.id == late.id).y - late.y;
    expect(lateDelta, greaterThan(earlyDelta));
    expect(lateDelta, lessThanOrEqualTo(.0251));
  });
  test('finish stops the round and restart clears round stats and recalibrates',
      () {
    final d = Driver(durationMicros: 2000000)..play();
    d.run(2000000);
    expect(d.engine.phase, MoveCatchPhase.finished);
    expect(d.engine.remainingSeconds, 0);
    expect(d.engine.objects, isEmpty);
    final score = d.engine.score;
    d.run(2000000);
    expect(d.engine.score, score);
    d.engine.restart(d.now);
    expect(d.engine.phase, MoveCatchPhase.calibrating);
    expect(d.engine.score, 0);
    expect(d.engine.caught, 0);
    expect(d.engine.obstaclesHit, 0);
    expect(d.engine.missed, 0);
    expect(d.engine.calibrationProgress, 0);
    expect(d.engine.remainingSeconds, 2);
    expect(d.engine.trackingReady, isFalse);
  });
}
