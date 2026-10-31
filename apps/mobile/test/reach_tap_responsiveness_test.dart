import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'reach_tap_engine_test.dart' show start;
import 'support/reach_tap_fixture.dart';

void main() {
  for (final cadence in [16667, 33333, 66667]) {
    test('fast observed hand has no extra filter backlog at $cadence us', () {
      final e = ReachTapEngine(random: Random(4));
      var t = start(e);
      final initial = e.leftHand!;
      final real = Point(initial.x + .12, initial.y - .08);
      t += cadence;
      e.update(reachTapSample(t, leftHand: real), nowMicros: t);
      expect(e.phase, ReachTapPhase.playing);
      expect(e.leftHand!.x, closeTo(real.x, .001));
      expect(e.leftHand!.y, closeTo(real.y, .001));
      expect(e.hits, 0, reason: 'A quick move alone never completes hit dwell');
    });
  }

  test('small observed jitter is smoothed without overshoot or prediction', () {
    final e = ReachTapEngine(random: Random(4));
    var t = start(e);
    final initial = e.leftHand!;
    final raw = Point(initial.x + .002, initial.y);
    t += 16667;
    e.update(reachTapSample(t, leftHand: raw), nowMicros: t);
    expect(e.leftHand!.x, greaterThan(initial.x));
    expect(e.leftHand!.x, lessThan(raw.x));
    final position = e.leftHand;
    e.tick(t + 16000);
    expect(e.leftHand, position,
        reason: 'Clock ticks cannot predict a new wrist');
    expect(e.hits, 0);
  });

  test('quick reversal follows current measurement rather than old direction',
      () {
    final e = ReachTapEngine(random: Random(4));
    var t = start(e);
    for (final raw in [
      const Point(.55, .35),
      const Point(.15, .55),
      const Point(.65, .20),
      const Point(.25, .60)
    ]) {
      t += 16667;
      e.update(reachTapSample(t, leftHand: raw), nowMicros: t);
      expect(e.leftHand, raw);
      expect(e.hits, 0);
    }
  });

  test('fast cursor cannot retain a hidden or stale hand for scoring', () {
    final e = ReachTapEngine(random: Random(4));
    var t = start(e);
    final target = e.target!;
    t += 16667;
    e.update(reachTapSample(t, leftHand: target), nowMicros: t);
    expect(e.hits, 0);
    t += 16667;
    e.update(reachTapSample(t, missingLeftHand: true), nowMicros: t);
    expect(e.leftHand, isNull);
    expect(e.hits, 0);
    e.update(reachTapSample(t - 1, leftHand: target), nowMicros: t + 50000);
    expect(e.phase, ReachTapPhase.recovering);
    expect(e.leftHand, isNull);
    expect(e.hits, 0);
  });

  test('expanded fixed play area actually uses lower screen positions', () {
    var lower = 0, left = 0, right = 0;
    final e = ReachTapEngine(random: Random(45));
    var t = start(e);
    var hits = 0;
    for (var round = 0; round < 48; round++) {
      final p = e.target!;
      // Previous stationary/upward area ends around y=.504 for this fixture.
      if (p.y > .57) lower++;
      if (p.x < .22) left++;
      if (p.x > .78) right++;
      final r = e.targetRadius * 400;
      expect(p.x * 400, inInclusiveRange(r + 8, 400 - r - 8));
      expect(p.y * 800, inInclusiveRange(r + 8, 800 - r - 8));
      for (var frames = 0; frames < 24 && e.hits == hits; frames++) {
        t += 50000;
        e.update(reachTapSample(t, leftHand: p), nowMicros: t);
      }
      expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
      expect(e.hits, ++hits);
    }
    expect(lower, greaterThanOrEqualTo(4));
    expect(left, greaterThanOrEqualTo(6));
    expect(right, greaterThanOrEqualTo(6));
    expect(e.score, 480);
  });
}
