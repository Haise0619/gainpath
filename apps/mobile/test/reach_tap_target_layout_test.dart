import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'reach_tap_engine_test.dart' show start, sample;
import 'support/reach_tap_fixture.dart' show distanceToMotionArea;

void main() {
  test('targets are visibly larger while adapting to a smaller player', () {
    for (final scale in [1.0, .55]) {
      final e = ReachTapEngine(random: Random(45));
      final t = start(e, scale: scale);
      final neutral = sample(t, scale: scale);
      double d(Point<double> a, Point<double> b) =>
          sqrt(pow((a.x - b.x) * 400, 2) + pow((a.y - b.y) * 800, 2));
      final length = d(neutral.leftShoulder!, neutral.leftElbow!) +
          d(neutral.leftElbow!, neutral.leftHand!);
      final oldRadius = min(.065, length * .72 / 400 * .22);
      final oldCursor = min(.035, length * .72 / 400 * .12);
      expect(e.cursorRadius, closeTo(oldCursor, .000001));
      expect(e.targetRadius, greaterThanOrEqualTo(oldRadius * 1.2));
      expect(e.targetRadius, lessThanOrEqualTo(.09));
      if (scale == 1) expect(e.targetRadius, closeTo(.09, .0001));
    }
  });
  for (final size in [(400.0, 800.0), (800.0, 400.0), (600.0, 600.0)]) {
    test(
        'targets spread through twelve regions inside calibrated movement reach $size',
        () {
      final e = ReachTapEngine(random: Random(45));
      var t = start(e, width: size.$1, height: size.$2, scale: .75);
      final neutral = sample(t, width: size.$1, height: size.$2, scale: .75);
      var left = neutral.leftHand!, right = neutral.rightHand!;
      final short = min(size.$1, size.$2), r = e.targetRadius * short;
      double d(Point<double> a, Point<double> b) =>
          sqrt(pow((a.x - b.x) * size.$1, 2) + pow((a.y - b.y) * size.$2, 2));
      final ll = d(neutral.leftShoulder!, neutral.leftElbow!) +
          d(neutral.leftElbow!, neutral.leftHand!);
      final rl = d(neutral.rightShoulder!, neutral.rightElbow!) +
          d(neutral.rightElbow!, neutral.rightHand!);
      final minY = max(
          r + short * .02,
          min(
              neutral.leftShoulder!.y * size.$2 -
                  ll * .90 -
                  min(short * .35, .35 * .75 * size.$2 * .55) +
                  r,
              neutral.rightShoulder!.y * size.$2 -
                  rl * .90 -
                  min(short * .35, .35 * .75 * size.$2 * .55) +
                  r));
      final maxY = min(
          size.$2 - r - short * .02,
          min(
              min(neutral.leftHip!.y, neutral.rightHip!.y) * size.$2 +
                  min(short * .40, .35 * .75 * size.$2 * .55),
              max(
                  neutral.leftShoulder!.y * size.$2 +
                      ll * .90 +
                      min(short * .40, .35 * .75 * size.$2 * .55) -
                      r,
                  neutral.rightShoulder!.y * size.$2 +
                      rl * .90 +
                      min(short * .40, .35 * .75 * size.$2 * .55) -
                      r)));
      final minX = max(
          r + short * .02,
          neutral.leftShoulder!.x * size.$1 -
              ll * .90 -
              min(short * .32, .35 * .75 * size.$2 * .50) +
              r);
      final maxX = min(
          size.$1 - r - short * .02,
          neutral.rightShoulder!.x * size.$1 +
              rl * .90 +
              min(short * .32, .35 * .75 * size.$2 * .50) -
              r);
      final regions = <int>{};
      var wider = false, lastSerial = -1;
      for (var frames = 0;
          frames < 760 && e.phase == ReachTapPhase.playing;
          frames++) {
        final p = e.target!;
        if (lastSerial != e.hitSerial) {
          lastSerial = e.hitSerial;
          final row =
              ((p.y * size.$2 - minY) / (maxY - minY) * 4).floor().clamp(0, 3);
          final column =
              ((p.x * size.$1 - minX) / (maxX - minX) * 3).floor().clamp(0, 2);
          regions.add(row * 3 + column);
          wider |= d(p, neutral.leftShoulder!) + r > ll * .72 &&
              d(p, neutral.rightShoulder!) + r > rl * .72;
        }
        expect(p.x * size.$1, inInclusiveRange(r, size.$1 - r));
        expect(p.y * size.$2, inInclusiveRange(r, size.$2 - r));
        expect(
            distanceToMotionArea(p, neutral.leftShoulder!, neutral) + r <=
                    ll * .90 + .001 ||
                distanceToMotionArea(p, neutral.rightShoulder!, neutral) + r <=
                    rl * .90 + .001,
            true);
        final useLeft =
            d(p, neutral.leftShoulder!) < d(p, neutral.rightShoulder!);
        Point<double> approach(Point<double> h) =>
            Point(h.x + (p.x - h.x) * .35, h.y + (p.y - h.y) * .35);
        if (useLeft) {
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
      expect(regions.length, 12);
      expect(wider, true);
    });
  }
}
