import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'support/reach_tap_fixture.dart';

ReachTapSample sample(int t,
    {Point<double>? left,
    Point<double>? right,
    bool missing = false,
    bool missingBoth = false,
    double width = 400,
    double height = 800,
    String geometry = 'front',
    double shift = 0,
    double scale = 1}) {
  return reachTapSample(t,
      leftHand: left,
      rightHand: right,
      missingLeftHand: missing,
      missingBothHands: missingBoth,
      boardWidth: width,
      boardHeight: height,
      geometryKey: geometry,
      shift: shift,
      scale: scale);
}

int start(ReachTapEngine e,
    {int step = 50000,
    double width = 400,
    double height = 800,
    double scale = 1}) {
  for (var t = 1000000; t < 8000000; t += step) {
    e.update(sample(t, width: width, height: height, scale: scale),
        nowMicros: t);
    if (e.phase == ReachTapPhase.playing) return t;
  }
  fail('Stable frames must start: ${e.phase} ${e.feedback}');
}

int hit(ReachTapEngine e, int t, {int step = 50000}) {
  final target = e.target!;
  for (var i = 0; i < (800000 / step).ceil(); i++) {
    t += step;
    e.update(sample(t, left: target), nowMicros: t);
    if (e.hits > 0) return t;
  }
  fail('Observed hand dwell should hit');
}

void main() {
  test('only confirmed hits emit score events with bounded active clock', () {
    final e = ReachTapEngine(random: Random(4));
    final events = <String>[];
    e.onScoreEvent = events.add;
    final t = start(e);
    expect(events, isEmpty);
    hit(e, t);
    expect(events, ['hit']);
    expect(e.activeMillis, inInclusiveRange(0, 40000));
  });

  test('requires two seconds of real stable body before Ready', () {
    final e = ReachTapEngine();
    for (var t = 1000000; t < 3000000; t += 50000) {
      e.update(sample(t), nowMicros: t);
    }
    expect(e.phase, ReachTapPhase.calibrating);
    e.update(sample(3000000), nowMicros: 3000000);
    expect(e.phase, ReachTapPhase.ready);
  });
  test('timer alone cannot calibrate count down or score', () {
    final e = ReachTapEngine();
    e.update(sample(1000000), nowMicros: 1000000);
    e.tick(9000000);
    expect(e.phase, isNot(ReachTapPhase.playing));
    expect(e.hits, 0);
  });
  for (final step in [16667, 33333, 100000]) {
    test('fresh cadence $step starts and captures one dwell', () {
      final e = ReachTapEngine(random: Random(4));
      final t = start(e, step: step);
      expect(e.remainingSeconds, 40);
      hit(e, t, step: step);
      expect(e.hits, 1);
      expect(e.score, 10);
      expect(e.hitSerial, 1);
    });
  }
  test('short overlap and timer never score', () {
    final e = ReachTapEngine();
    var t = start(e);
    final p = e.target!;
    t += 50000;
    e.update(sample(t, left: p), nowMicros: t);
    e.tick(t + 100000);
    expect(e.hits, 0);
    t += 150000;
    e.update(sample(t), nowMicros: t);
    expect(e.hits, 0);
  });
  test('new target is separated and a held hand cannot repeat a hit', () {
    final e = ReachTapEngine(random: Random(2));
    var t = start(e);
    final old = e.target!;
    t = hit(e, t);
    final next = e.target!;
    expect(
        sqrt(pow((next.x - old.x) * 400, 2) + pow((next.y - old.y) * 800, 2)),
        greaterThan(85));
    for (var i = 0; i < 10; i++) {
      t += 50000;
      e.update(sample(t, left: old), nowMicros: t);
    }
    expect(e.hits, 1);
  });
  for (final reason in [
    'missing',
    'stale',
    'future',
    'duplicate',
    'geometry',
    'clock',
    'body'
  ]) {
    test('$reason freezes immediately and accepts fresh hands-free recovery',
        () {
      final e = ReachTapEngine();
      final t = start(e);
      final target = e.target;
      switch (reason) {
        case 'missing':
          e.update(sample(t + 50000, missingBoth: true), nowMicros: t + 50000);
        case 'stale':
          e.update(sample(t + 1), nowMicros: t + 400000);
        case 'future':
          e.update(sample(t + 50000), nowMicros: t + 49999);
        case 'duplicate':
          e.update(sample(t), nowMicros: t + 50000);
        case 'geometry':
          e.update(sample(t + 50000, geometry: 'rotate'), nowMicros: t + 50000);
        case 'clock':
          e.tick(t - 1);
        case 'body':
          e.update(sample(t + 50000, scale: 1.4), nowMicros: t + 50000);
      }
      final hard = ['geometry', 'clock', 'body'].contains(reason);
      expect(e.phase,
          hard ? ReachTapPhase.trackingLost : ReachTapPhase.recovering);
      expect(e.target, hard ? isNull : target);
      expect(e.trackingReady, false);
      final next = t + (reason == 'stale' ? 450000 : 100000);
      e.update(sample(next), nowMicros: next);
      expect(
          e.phase, hard ? ReachTapPhase.calibrating : ReachTapPhase.recovering);
      expect(e.activeMicros, 0);
      expect(e.hits, 0);
    });
  }
  test('pause freezes active time and Resume reacquires stable alignment', () {
    final e = ReachTapEngine();
    var t = start(e);
    t += 50000;
    e.update(sample(t), nowMicros: t);
    final active = e.activeMicros;
    e.pause(t);
    e.tick(t + 10000000);
    expect(e.activeMicros, active);
    e.resume(t + 10000000);
    expect(e.phase, ReachTapPhase.calibrating);
    for (t += 10050000; t < 22000000; t += 50000) {
      e.update(sample(t), nowMicros: t);
      if (e.phase == ReachTapPhase.playing) break;
    }
    expect(e.phase, ReachTapPhase.playing);
    expect(e.activeMicros, active);
  });
  test('forty fresh active seconds end round and Replay clears evidence', () {
    final e = ReachTapEngine();
    var t = hit(e, start(e));
    while (e.phase == ReachTapPhase.playing) {
      t += 50000;
      e.update(sample(t), nowMicros: t);
    }
    expect(e.phase, ReachTapPhase.finished);
    expect(e.activeMicros, 40000000);
    expect(e.remainingSeconds, 0);
    e.restart(t);
    expect(e.hits, 0);
    expect(e.hitSerial, 0);
    expect(e.activeMicros, 0);
    expect(e.target, isNull);
  });
  for (final size in [(400.0, 800.0), (800.0, 400.0), (600.0, 600.0)]) {
    for (final scale in [.75, 1.0]) {
      test('visible reachable target at $size scale $scale', () {
        final e = ReachTapEngine(random: Random(12));
        start(e, width: size.$1, height: size.$2, scale: scale);
        final p = e.target!;
        final r = e.targetRadius * min(size.$1, size.$2);
        expect(p.x * size.$1, inInclusiveRange(r, size.$1 - r));
        expect(p.y * size.$2, inInclusiveRange(r, size.$2 - r));
        final s = sample(0, width: size.$1, height: size.$2, scale: scale);
        double d(Point<double> a, Point<double> b) =>
            sqrt(pow((a.x - b.x) * size.$1, 2) + pow((a.y - b.y) * size.$2, 2));
        final l =
            d(s.leftShoulder!, s.leftElbow!) + d(s.leftElbow!, s.leftHand!);
        final rr =
            d(s.rightShoulder!, s.rightElbow!) + d(s.rightElbow!, s.rightHand!);
        expect(
            distanceToMotionArea(p, s.leftShoulder!, s) + r <= l * .90 ||
                distanceToMotionArea(p, s.rightShoulder!, s) + r <= rr * .90,
            true);
      });
    }
  }
  test('moving calibration cannot accrue disconnected stable time', () {
    final e = ReachTapEngine();
    for (var t = 1000000; t < 10000000; t += 50000) {
      e.update(sample(t, shift: (t ~/ 500000).isEven ? .08 : 0), nowMicros: t);
    }
    expect(e.phase, ReachTapPhase.calibrating);
  });
  test('small fresh jitter calibrates and unavailable clears both cursors', () {
    final e = ReachTapEngine();
    for (var t = 1000000; t < 7000000; t += 50000) {
      e.update(sample(t, shift: (t ~/ 50000).isEven ? .002 : -.002),
          nowMicros: t);
    }
    expect(e.phase, ReachTapPhase.playing);
    e.unavailable(7000000);
    expect(e.leftHand, isNull);
    expect(e.rightHand, isNull);
    expect(e.phase, ReachTapPhase.recovering);
  });
  test('arrival clock gap pauses even when the next frame is barely fresh', () {
    final e = ReachTapEngine();
    final t = start(e);
    final active = e.activeMicros;
    e.update(sample(t + 200000), nowMicros: t + 400000);
    expect(e.phase, ReachTapPhase.recovering);
    expect(e.activeMicros, active);
  });
  test('freshness timeout freezes round without crediting rejected time', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.tick(t + 100000);
    final active = e.activeMicros;
    e.tick(t + 200001);
    expect(e.phase, ReachTapPhase.recovering);
    expect(e.activeMicros, active);
    e.tick(t + 10000000);
    expect(e.activeMicros, active);
  });
  test('new capture cannot revive a cursor after raw hand moves away', () {
    final e = ReachTapEngine(random: Random(9));
    var t = start(e);
    final p = e.target!;
    for (var i = 0; i < 4; i++) {
      t += 20000;
      e.update(sample(t, left: p, right: p), nowMicros: t);
    }
    t += 20000;
    e.update(sample(t), nowMicros: t);
    expect(e.hits, 0);
    for (var i = 0; i < 4; i++) {
      t += 20000;
      e.update(sample(t, left: p, right: p), nowMicros: t);
    }
    expect(e.hits, 0);
  });
  test('right hand can independently confirm a target', () {
    final e = ReachTapEngine(random: Random(7));
    var t = start(e);
    final p = e.target!;
    for (var i = 0; i < 12 && e.hits == 0; i++) {
      t += 50000;
      e.update(sample(t, right: p), nowMicros: t);
    }
    expect(e.hits, 1);
  });
  test('countdown interruption automatically requires a full fresh alignment',
      () {
    final e = ReachTapEngine();
    var t = 1000000;
    for (; t < 5000000; t += 50000) {
      e.update(sample(t), nowMicros: t);
    }
    expect(e.phase, ReachTapPhase.countdown);
    e.unavailable(t);
    expect(e.phase, ReachTapPhase.trackingLost);
    final returnAt = t;
    for (; t < 10000000; t += 50000) {
      e.update(sample(t), nowMicros: t);
      if (t < returnAt + 2000000) {
        expect(e.phase, ReachTapPhase.calibrating);
      }
    }
    expect(e.phase, ReachTapPhase.countdown);
    expect(e.activeMicros, 0);
  });
  for (final bad in [
    const Point<double>(double.nan, .5),
    const Point<double>(.5, double.infinity),
    const Point<double>(-.01, .5),
    const Point<double>(1.01, .5)
  ]) {
    test('rejects malformed or cropped actual hand $bad', () {
      final e = ReachTapEngine();
      final t = start(e);
      e.update(sample(t + 50000, left: bad), nowMicros: t + 50000);
      expect(e.phase, ReachTapPhase.recovering);
      expect(e.hits, 0);
      expect(e.leftHand, isNull);
    });
  }
  test('viewport resize invalidates geometry even with same model key', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.update(sample(t + 50000, width: 401), nowMicros: t + 50000);
    expect(e.phase, ReachTapPhase.trackingLost);
  });
  test('calibration rejects degenerate body instead of synthesizing reach', () {
    final e = ReachTapEngine();
    e.update(sample(1000000, scale: .01), nowMicros: 1000000);
    expect(e.phase, ReachTapPhase.calibrating);
    expect(e.trackingReady, false);
  });
  test('initial unavailable camera does not latch a Resume requirement', () {
    final e = ReachTapEngine();
    e.unavailable(0);
    e.unavailable(50000);
    expect(e.phase, ReachTapPhase.calibrating);
    final t = start(e);
    expect(t, greaterThan(5000000));
    expect(e.phase, ReachTapPhase.playing);
  });
  test('partial calibration loss requires a whole fresh alignment hold', () {
    final e = ReachTapEngine();
    for (var t = 1000000; t <= 2500000; t += 50000) {
      e.update(sample(t), nowMicros: t);
    }
    e.update(sample(2550000, missing: true), nowMicros: 2550000);
    expect(e.phase, ReachTapPhase.calibrating);
    expect(e.calibrationProgress, 0);
    for (var t = 2600000; t < 4600000; t += 50000) {
      e.update(sample(t), nowMicros: t);
    }
    expect(e.phase, ReachTapPhase.calibrating);
    e.update(sample(4600000), nowMicros: 4600000);
    expect(e.phase, ReachTapPhase.ready);
  });
  test('unavailable cannot change an intentional manual pause', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.pause(t);
    e.unavailable(t + 50000);
    expect(e.phase, ReachTapPhase.paused);
  });
  test('manual pause during acquisition honors an arrival clock gap', () {
    final e = ReachTapEngine();
    e.update(sample(1000000), nowMicros: 1000000);
    e.pause(1500000);
    expect(e.phase, ReachTapPhase.paused);
    expect(e.activeMicros, 0);
    e.unavailable(1550000);
    expect(e.phase, ReachTapPhase.paused);
  });
  test('manual pause after a playing clock gap discards unobserved time', () {
    final e = ReachTapEngine();
    final t = start(e);
    final active = e.activeMicros;
    e.pause(t + 500000);
    expect(e.phase, ReachTapPhase.paused);
    expect(e.activeMicros, active);
    e.unavailable(t + 550000);
    e.resume(t - 1);
    expect(e.phase, ReachTapPhase.paused);
    expect(e.activeMicros, active);
  });
  test('manual pause cannot reopen a completed round', () {
    final e = ReachTapEngine();
    var t = start(e);
    while (e.phase == ReachTapPhase.playing) {
      t += 50000;
      e.update(sample(t), nowMicros: t);
    }
    e.pause(t + 500000);
    e.resume(t + 550000);
    expect(e.phase, ReachTapPhase.finished);
    expect(e.activeMicros, 40000000);
  });
  for (final size in [(400.0, 800.0), (800.0, 400.0)]) {
    test('collision circles use board pixels rather than normalized $size', () {
      final e = ReachTapEngine();
      var t = start(e, width: size.$1, height: size.$2);
      final p = e.target!;
      final outside = Point(p.x + (size.$1 > size.$2 ? .075 : 0),
          p.y + (size.$2 > size.$1 ? .075 : 0));
      for (var i = 0; i < 15; i++) {
        t += 50000;
        e.update(
            sample(t,
                left: outside, right: outside, width: size.$1, height: size.$2),
            nowMicros: t);
      }
      expect(e.hits, 0);
      for (var i = 0; i < 15 && e.hits == 0; i++) {
        t += 50000;
        e.update(sample(t, left: p, right: p, width: size.$1, height: size.$2),
            nowMicros: t);
      }
      expect(e.hits, 1);
    });
  }
  test('observed hand may pass the elbow projection during active reach', () {
    final e = ReachTapEngine();
    final t = start(e);
    e.update(sample(t + 50000, left: const Point(.30, .43)),
        nowMicros: t + 50000);
    expect(e.phase, ReachTapPhase.playing);
    expect(e.leftHand, isNotNull);
  });
  for (final size in [(400.0, 800.0), (800.0, 400.0), (600.0, 600.0)]) {
    test(
        'many generated targets stay reachable during continuous observed reaches $size',
        () {
      final e = ReachTapEngine(random: Random(45));
      var t = start(e, width: size.$1, height: size.$2, scale: .75);
      final neutral = sample(t, width: size.$1, height: size.$2, scale: .75);
      var left = neutral.leftHand!, right = neutral.rightHand!;
      final r = e.targetRadius * min(size.$1, size.$2);
      double d(Point<double> a, Point<double> b) =>
          sqrt(pow((a.x - b.x) * size.$1, 2) + pow((a.y - b.y) * size.$2, 2));
      final leftReach = (d(neutral.leftShoulder!, neutral.leftElbow!) +
              d(neutral.leftElbow!, neutral.leftHand!)) *
          .90;
      final rightReach = (d(neutral.rightShoulder!, neutral.rightElbow!) +
              d(neutral.rightElbow!, neutral.rightHand!)) *
          .90;
      for (var frames = 0;
          frames < 700 && e.phase == ReachTapPhase.playing;
          frames++) {
        final p = e.target!;
        expect(p.x * size.$1, inInclusiveRange(r, size.$1 - r));
        expect(p.y * size.$2, inInclusiveRange(r, size.$2 - r));
        expect(
            distanceToMotionArea(p, neutral.leftShoulder!, neutral) + r <=
                    leftReach ||
                distanceToMotionArea(p, neutral.rightShoulder!, neutral) + r <=
                    rightReach,
            true);
        final moveLeft =
            d(p, neutral.leftShoulder!) < d(p, neutral.rightShoulder!);
        Point<double> approach(Point<double> hand) =>
            Point(hand.x + (p.x - hand.x) * .3, hand.y + (p.y - hand.y) * .3);
        if (moveLeft) {
          left = approach(left);
        } else {
          right = approach(right);
        }
        t += 50000;
        e.update(
            sample(t,
                left: left,
                right: right,
                width: size.$1,
                height: size.$2,
                scale: .75),
            nowMicros: t);
        expect(e.phase, isNot(ReachTapPhase.trackingLost), reason: e.feedback);
      }
      expect(e.hits, greaterThan(15));
      expect(e.score, e.hits * 10);
    });
  }
}
