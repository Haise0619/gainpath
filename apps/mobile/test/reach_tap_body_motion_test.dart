import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'reach_tap_engine_test.dart' show start;
import 'support/reach_tap_fixture.dart';

// Synthetic observed movement, not native camera replay or physical acceptance.
ReachTapSample moving(int t,
    {double dx = 0,
    double dy = 0,
    double scale = 1,
    double width = 400,
    double height = 800,
    Point<double>? hand,
    bool missingBoth = false,
    String geometry = 'front'}) {
  final s = reachTapSample(t,
      shift: dx,
      scale: scale,
      boardWidth: width,
      boardHeight: height,
      geometryKey: geometry);
  Point<double> p(Point<double>? q) => Point(q!.x, q.y + dy);
  return ReachTapSample(
      leftShoulder: p(s.leftShoulder),
      rightShoulder: p(s.rightShoulder),
      leftElbow: p(s.leftElbow),
      rightElbow: p(s.rightElbow),
      leftHand: missingBoth ? null : hand ?? p(s.leftHand),
      rightHand: missingBoth ? null : p(s.rightHand),
      leftHip: p(s.leftHip),
      rightHip: p(s.rightHip),
      capturedAtMicros: t,
      boardWidth: width,
      boardHeight: height,
      geometryKey: geometry);
}

double distance(Point<double> a, Point<double> b, ReachTapSample s) => sqrt(
    pow((a.x - b.x) * s.boardWidth, 2) + pow((a.y - b.y) * s.boardHeight, 2));

void expectPlayable(ReachTapEngine e, ReachTapSample current) {
  final setup = reachTapSample(0,
      boardWidth: current.boardWidth, boardHeight: current.boardHeight);
  final l = (distance(setup.leftShoulder!, setup.leftElbow!, setup) +
          distance(setup.leftElbow!, setup.leftHand!, setup)) *
      .9;
  final r = (distance(setup.rightShoulder!, setup.rightElbow!, setup) +
          distance(setup.rightElbow!, setup.rightHand!, setup)) *
      .9;
  final radius = e.targetRadius * min(current.boardWidth, current.boardHeight);
  final target = e.target!;
  final short = min(current.boardWidth, current.boardHeight);
  // Any allowed target must be reachable after at most the bounded side-step
  // and upward displacement, not necessarily while standing at the origin.
  final torso = .35 * current.boardHeight;
  final side = min(short * .32, torso * .50);
  final up = min(short * .35, torso * .55);
  final down = min(short * .40, torso * .55);
  double nearest(Point<double> shoulder) {
    final x = (target.x * current.boardWidth).clamp(
        shoulder.x * current.boardWidth - side,
        shoulder.x * current.boardWidth + side);
    final y = (target.y * current.boardHeight).clamp(
        shoulder.y * current.boardHeight - up,
        shoulder.y * current.boardHeight + down);
    return sqrt(pow(target.x * current.boardWidth - x, 2) +
        pow(target.y * current.boardHeight - y, 2));
  }

  expect(
      nearest(setup.leftShoulder!) + radius <= l + 1e-8 ||
          nearest(setup.rightShoulder!) + radius <= r + 1e-8,
      true);
  expect(target.y, lessThanOrEqualTo(.65 + down / current.boardHeight));
  expect(target.x * current.boardWidth,
      inInclusiveRange(radius, current.boardWidth - radius));
  expect(target.y * current.boardHeight,
      inInclusiveRange(radius, current.boardHeight - radius));
}

void main() {
  for (final size in [(400.0, 800.0), (800.0, 400.0), (600.0, 600.0)]) {
    for (final direction in [
      (-.18, 0.0),
      (.18, 0.0),
      (0.0, .12),
      (.16, -.10)
    ]) {
      test('observed body translation $direction continues at $size', () {
        final e = ReachTapEngine(random: Random(4));
        var t = start(e, width: size.$1, height: size.$2);
        final before = e.activeMicros;
        for (var i = 1; i <= 20; i++) {
          t += 50000;
          final s = moving(t,
              dx: direction.$1 * i / 20,
              dy: direction.$2 * i / 20,
              width: size.$1,
              height: size.$2);
          e.update(s, nowMicros: t);
          expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
          expectPlayable(e, s);
        }
        expect(e.activeMicros - before, 1000000);
      });
    }
  }

  test('target stays fixed while still reachable after a side step', () {
    final e = ReachTapEngine(random: Random(4));
    final t = start(e);
    final target = e.target!;
    final dx = target.x < .5 ? -.12 : .12;
    final s = moving(t + 50000, dx: dx);
    e.update(s, nowMicros: t + 50000);
    expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
    expect(e.target, target, reason: 'Targets must not chase body movement');
    expectPlayable(e, s);
  });

  test('target stays fixed through a jump and landing without automatic score',
      () {
    final e = ReachTapEngine(random: Random(4));
    var t = start(e);
    final old = e.target!;
    for (final dy in [-.04, -.09, -.14, -.18, -.14, -.09, -.04, 0.0]) {
      t += 50000;
      // Park the observed wrist far from this target while moving the torso.
      final hand = Point(old.x < .5 ? .95 : .05, .90);
      e.update(moving(t, dy: dy, hand: hand, missingBoth: false), nowMicros: t);
      expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
      expect(e.target, old, reason: 'Jumping must not move the point');
      expect(e.hits, 0);
    }
    expect(e.activeMicros, 400000);
    for (var i = 0; i < 15 && e.hits == 0; i++) {
      t += 50000;
      e.update(moving(t, dy: -.12, hand: old), nowMicros: t);
    }
    expect(e.hits, 1);
    expect(e.score, 10);
    expectPlayable(e, moving(t));
  });

  test('several translated hits stay in the fixed calibrated movement area',
      () {
    final e = ReachTapEngine(random: Random(21));
    var t = start(e);
    for (var round = 0; round < 8; round++) {
      final dx = round.isEven ? .18 : -.18;
      final dy = round % 3 == 0 ? .10 : -.08;
      t += 50000;
      e.update(moving(t, dx: dx, dy: dy), nowMicros: t);
      expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
      final before = e.hits, target = e.target!;
      for (var i = 0; i < 24 && e.hits == before; i++) {
        t += 50000;
        e.update(moving(t, dx: dx, dy: dy, hand: target), nowMicros: t);
        expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
      }
      expect(e.hits, before + 1);
      expectPlayable(e, moving(t, dx: dx, dy: dy));
    }
  });

  test('bounded depth change does not lock a player to the initial position',
      () {
    final e = ReachTapEngine(random: Random(21));
    var t = start(e);
    for (var n = 0; n < 6; n++) {
      t += 50000;
      final s = moving(t, dx: .14, dy: .08, scale: .80);
      e.update(s, nowMicros: t);
      expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
      expectPlayable(e, s);
      final target = e.target!, before = e.hits;
      for (var i = 0; i < 24 && e.hits == before; i++) {
        t += 50000;
        e.update(moving(t, dx: .14, dy: .08, scale: .80, hand: target),
            nowMicros: t);
      }
      expect(e.hits, before + 1);
    }
  });

  test('translated visible return recovers without time or score credit', () {
    final e = ReachTapEngine(random: Random(4));
    final t = start(e);
    e.unavailable(t + 50000);
    for (var n = 100000; n <= 450000; n += 50000) {
      e.update(moving(t + n, dx: .18), nowMicros: t + n);
      expect(e.phase, ReachTapPhase.recovering, reason: e.feedback);
    }
    e.update(moving(t + 500000, dx: .18), nowMicros: t + 500000);
    expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
    expect(e.activeMicros, 0);
    expect(e.score, 0);
    expectPlayable(e, moving(t + 500000, dx: .18));
    e.update(moving(t + 550000, dx: .18, missingBoth: true),
        nowMicros: t + 550000);
    expect(e.phase, ReachTapPhase.recovering);
    expect(e.activeMicros, 0);
    expect(e.leftHand, isNull);
  });

  test('continuous moving body cannot bypass initial stable calibration', () {
    final e = ReachTapEngine();
    for (var t = 1000000; t < 9000000; t += 50000) {
      e.update(moving(t, dx: (t ~/ 300000).isEven ? .16 : -.16), nowMicros: t);
    }
    expect(e.phase, ReachTapPhase.calibrating);
    expect(e.target, isNull);
    expect(e.score, 0);
  });

  test('high and side targets require movement beyond stationary arm reach',
      () {
    var aboveStandingReach = 0, sideMovement = 0;
    final setup = reachTapSample(0);
    // 400x800 fixture: each 90% arm reach is about 199px; target radius36px.
    for (var seed = 0; seed < 40; seed++) {
      final e = ReachTapEngine(random: Random(seed));
      start(e);
      final p = e.target!;
      expectPlayable(e, setup);
      if (distance(p, setup.leftShoulder!, setup) + 36 > 199.4 &&
          distance(p, setup.rightShoulder!, setup) + 36 > 199.4) {
        if (p.y < .15) aboveStandingReach++;
        if (p.x < .25 || p.x > .75) sideMovement++;
      }
    }
    expect(aboveStandingReach, greaterThan(4));
    expect(sideMovement, greaterThan(4));
  });

  for (final issue in ['scale', 'geometry', 'outside']) {
    test('$issue still rejects translated evidence without score', () {
      final e = ReachTapEngine();
      final t = start(e);
      e.update(
          moving(t + 50000,
              dx: issue == 'outside' ? .45 : .12,
              scale: issue == 'scale' ? 1.4 : 1,
              geometry: issue == 'geometry' ? 'rotated' : 'front'),
          nowMicros: t + 50000);
      expect(e.phase, isNot(ReachTapPhase.playing));
      expect(e.activeMicros, 0);
      expect(e.score, 0);
    });
  }
}
