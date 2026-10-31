import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/domain/reach_tap.dart';
import 'reach_tap_engine_test.dart' show start;
import 'support/reach_tap_fixture.dart';

// Synthetic geometry inspired by visible reaching. No native video landmarks,
// confidence replay or physical accuracy acceptance is represented here.
ReachTapSample frame(int t,
    {Point<double>? left,
    Point<double>? right,
    bool noLeft = false,
    bool noRight = false,
    bool noLeftElbow = false,
    bool noRightElbow = false,
    bool noHip = false,
    Point<double>? leftShoulder,
    Point<double>? rightShoulder,
    Point<double>? leftHip,
    Point<double>? rightHip,
    double shift = 0,
    double scale = 1,
    double width = 400,
    double height = 800}) {
  final s = reachTapSample(t,
      leftHand: left,
      rightHand: right,
      shift: shift,
      scale: scale,
      boardWidth: width,
      boardHeight: height);
  return ReachTapSample(
      leftShoulder: leftShoulder ?? s.leftShoulder,
      rightShoulder: rightShoulder ?? s.rightShoulder,
      leftElbow: noLeftElbow ? null : s.leftElbow,
      rightElbow: noRightElbow ? null : s.rightElbow,
      leftHand: noLeft ? null : s.leftHand,
      rightHand: noRight ? null : s.rightHand,
      leftHip: noHip ? null : leftHip ?? s.leftHip,
      rightHip: rightHip ?? s.rightHip,
      capturedAtMicros: t,
      boardWidth: width,
      boardHeight: height,
      geometryKey: s.geometryKey);
}

void main() {
  for (final side in ['left', 'right', 'both']) {
    test('missing $side elbow cannot interrupt real wrists in active play', () {
      final e = ReachTapEngine(random: Random(4));
      var t = start(e);
      final target = e.target;
      for (var i = 0; i < 12 && e.hits == 0; i++) {
        t += 50000;
        e.update(
            frame(t,
                left: target,
                noLeftElbow: side != 'right',
                noRightElbow: side != 'left'),
            nowMicros: t);
        expect(e.phase, ReachTapPhase.playing);
      }
      expect(e.hits, 1);
      expect(e.activeMicros, greaterThan(0));
    });
  }

  for (final leftVisible in [true, false]) {
    test('only actual ${leftVisible ? 'left' : 'right'} wrist can keep scoring',
        () {
      final e = ReachTapEngine(random: Random(4));
      var t = start(e);
      final target = e.target;
      for (var i = 0; i < 12 && e.hits == 0; i++) {
        t += 50000;
        e.update(
            frame(t,
                left: target,
                right: target,
                noLeft: !leftVisible,
                noRight: leftVisible,
                noLeftElbow: true,
                noRightElbow: true),
            nowMicros: t);
        expect(e.phase, ReachTapPhase.playing);
        expect(leftVisible ? e.rightHand : e.leftHand, isNull);
      }
      expect(e.hits, 1);
      expect(e.score, 10);
      expect(
          e.feedback.toLowerCase(), contains(leftVisible ? 'left' : 'right'));
    });
  }

  test('ordinary elevated projected shoulder permits a cross-body hit', () {
    final e = ReachTapEngine(random: Random(4));
    var t = start(e);
    final target = e.target;
    for (var i = 0; i < 12 && e.hits == 0; i++) {
      t += 50000;
      e.update(
          frame(t,
              right: target,
              leftShoulder: const Point(.475, .245),
              rightShoulder: const Point(.64, .30)),
          nowMicros: t);
      expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
    }
    expect(e.hits, 1);
    expect(e.activeMicros, greaterThan(0));
  });

  test('lost hand clears its own dwell and smoothing while other hand plays',
      () {
    final e = ReachTapEngine(random: Random(2));
    var t = start(e);
    final target = e.target!;
    for (var i = 0; i < 15; i++) {
      t += 5000;
      e.update(frame(t, left: target), nowMicros: t);
    }
    expect(e.hits, 0);
    t += 5000;
    e.update(frame(t, noLeft: true), nowMicros: t);
    expect(e.phase, ReachTapPhase.playing);
    expect(e.leftHand, isNull);
    t += 50000;
    const returned = Point(.10, .85);
    e.update(frame(t, left: returned), nowMicros: t);
    expect(e.leftHand, returned, reason: 'No stale missing-hand smoothing');
    expect(e.hits, 0);
    for (var i = 0; i < 10; i++) {
      t += 5000;
      e.update(frame(t, left: target), nowMicros: t);
    }
    expect(e.hits, 0, reason: 'Old hand dwell must not survive loss');
  });

  test('missing wrist cannot hit from old smoothed cursor or hidden raw point',
      () {
    final e = ReachTapEngine(random: Random(2));
    var t = start(e);
    final target = e.target!;
    for (var i = 0; i < 15; i++) {
      t += 5000;
      e.update(frame(t, left: target), nowMicros: t);
    }
    for (var i = 0; i < 20; i++) {
      t += 50000;
      e.update(frame(t, left: target, noLeft: true), nowMicros: t);
      expect(e.leftHand, isNull);
      expect(e.phase, ReachTapPhase.playing);
    }
    expect(e.hits, 0);
    expect(e.activeMicros, greaterThan(1000000));
  });

  for (final leftVisible in [true, false]) {
    test(
        'same actual single wrist completes 400ms recovery without scoring '
        '$leftVisible', () {
      final e = ReachTapEngine(random: Random(2));
      final t = start(e);
      final target = e.target;
      e.unavailable(t + 50000);
      for (var n = 100000; n <= 450000; n += 50000) {
        e.update(
            frame(t + n,
                left: target,
                right: target,
                noLeft: !leftVisible,
                noRight: leftVisible),
            nowMicros: t + n);
      }
      expect(e.phase, ReachTapPhase.recovering);
      expect(e.recoveryProgress, closeTo(.875, .001));
      e.update(
          frame(t + 500000,
              left: target,
              right: target,
              noLeft: !leftVisible,
              noRight: leftVisible),
          nowMicros: t + 500000);
      expect(e.phase, ReachTapPhase.playing);
      expect(e.activeMicros, 0);
      expect(e.hits, 0);
      expect(e.target, target);
      expect(leftVisible ? e.rightHand : e.leftHand, isNull);
    });
  }

  test('alternating visible wrists cannot combine disconnected recovery hold',
      () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 50000);
    for (var n = 100000; n <= 900000; n += 50000) {
      final left = n < 350000 || n >= 650000;
      e.update(frame(t + n, noLeft: !left, noRight: left), nowMicros: t + n);
      expect(e.phase, ReachTapPhase.recovering);
    }
    expect(e.recoveryProgress, closeTo(.625, .001));
    expect(e.activeMicros, 0);
    for (var n = 950000; n <= 1050000; n += 50000) {
      e.update(frame(t + n, noRight: true), nowMicros: t + n);
    }
    expect(e.phase, ReachTapPhase.playing);
  });

  test('both hands during return cannot bridge a switch of sole visible hand',
      () {
    final e = ReachTapEngine();
    final t = start(e);
    e.unavailable(t + 50000);
    for (var n = 100000; n <= 300000; n += 50000) {
      e.update(frame(t + n, noRight: true), nowMicros: t + n);
    }
    e.update(frame(t + 350000), nowMicros: t + 350000);
    e.update(frame(t + 400000, noLeft: true), nowMicros: t + 400000);
    expect(e.phase, ReachTapPhase.recovering);
    expect(e.recoveryProgress, 0);
    e.update(frame(t + 450000, noLeft: true), nowMicros: t + 450000);
    expect(e.recoveryProgress, closeTo(.125, .001));
  });

  for (final loss in ['both wrists', 'hip']) {
    test('$loss still freezes immediately and clears both cursors', () {
      final e = ReachTapEngine();
      final t = start(e);
      final target = e.target;
      e.update(
          frame(t + 50000,
              noLeft: loss == 'both wrists',
              noRight: loss == 'both wrists',
              noHip: loss == 'hip'),
          nowMicros: t + 50000);
      expect(e.phase, ReachTapPhase.recovering);
      expect(e.target, target);
      expect(e.leftHand, isNull);
      expect(e.rightHand, isNull);
      expect(e.activeMicros, 0);
      expect(e.hits, 0);
    });
  }

  for (final joint in ['left wrist', 'right wrist', 'left elbow', 'hip']) {
    test('full setup still requires real $joint', () {
      final e = ReachTapEngine();
      for (var t = 1000000; t < 8000000; t += 50000) {
        e.update(
            frame(t,
                noLeft: joint == 'left wrist',
                noRight: joint == 'right wrist',
                noLeftElbow: joint == 'left elbow',
                noHip: joint == 'hip'),
            nowMicros: t);
      }
      expect(e.phase, ReachTapPhase.calibrating);
      expect(e.calibrationProgress, 0);
      expect(e.target, isNull);
    });
  }

  for (final geometry in [
    'coincident hips',
    'vertical hips',
    'vertical shoulders',
    'crossed torso',
    'centroid collapse'
  ]) {
    test('$geometry cannot create an undefined front-view baseline', () {
      final e = ReachTapEngine();
      for (var t = 1000000; t < 8000000; t += 50000) {
        e.update(
            frame(t,
                leftHip: switch (geometry) {
                  'vertical shoulders' => null,
                  'crossed torso' => const Point(.58, .65),
                  'centroid collapse' => const Point(.4, .31),
                  _ => const Point(.5, .65),
                },
                rightHip: geometry == 'coincident hips'
                    ? const Point(.5, .65)
                    : geometry == 'vertical hips'
                        ? const Point(.5, .70)
                        : geometry == 'crossed torso'
                            ? const Point(.42, .65)
                            : geometry == 'centroid collapse'
                                ? const Point(.6, .31)
                                : null,
                leftShoulder: geometry == 'vertical shoulders'
                    ? const Point(.5, .25)
                    : geometry == 'centroid collapse'
                        ? const Point(.1, .3)
                        : null,
                rightShoulder: geometry == 'vertical shoulders'
                    ? const Point(.5, .35)
                    : geometry == 'centroid collapse'
                        ? const Point(.9, .3)
                        : null),
            nowMicros: t);
      }
      expect(e.phase, ReachTapPhase.calibrating);
      expect(e.target, isNull);
      expect(e.hits, 0);
    });
  }

  for (final shape in ['scale', 'lean', 'side collapse']) {
    test('$shape cannot be accepted as shoulder reach', () {
      final e = ReachTapEngine();
      final t = start(e);
      e.update(
          frame(t + 50000,
              scale: shape == 'scale' ? 1.4 : 1,
              leftShoulder: shape == 'lean'
                  ? const Point(.64, .30)
                  : shape == 'side collapse'
                      ? const Point(.44, .30)
                      : null,
              rightShoulder: shape == 'lean'
                  ? const Point(.88, .30)
                  : shape == 'side collapse'
                      ? const Point(.56, .30)
                      : null),
          nowMicros: t + 50000);
      expect(e.phase, ReachTapPhase.trackingLost, reason: e.feedback);
      expect(e.target, isNull);
      expect(e.activeMicros, 0);
      expect(e.hits, 0);
    });
  }

  test('gradual scale drift never teaches a new active body baseline', () {
    final e = ReachTapEngine(random: Random(4));
    final t = start(e);
    for (var i = 1; i <= 30 && e.phase == ReachTapPhase.playing; i++) {
      e.update(frame(t + i * 50000, shift: i * .003, scale: 1 + i * .015),
          nowMicros: t + i * 50000);
    }
    expect(e.phase, ReachTapPhase.trackingLost);
    expect(e.activeMicros, lessThan(1500000));
    expect(e.hits, 0);
  });

  for (final change in [
    'torso shorten',
    'torso lengthen',
    'shoulder widen',
    'hip collapse',
    'hip widen',
    'shoulder swap'
  ]) {
    test('fixed body evidence rejects $change without crediting time', () {
      final e = ReachTapEngine();
      final t = start(e);
      final (ls, rs, lh, rh) = switch (change) {
        'torso shorten' => (
            const Point(.38, .40),
            const Point(.62, .40),
            const Point(.42, .65),
            const Point(.58, .65)
          ),
        'torso lengthen' => (
            const Point(.38, .20),
            const Point(.62, .20),
            const Point(.42, .65),
            const Point(.58, .65)
          ),
        'shoulder widen' => (
            const Point(.30, .30),
            const Point(.70, .30),
            const Point(.42, .65),
            const Point(.58, .65)
          ),
        'hip collapse' => (
            const Point(.38, .30),
            const Point(.62, .30),
            const Point(.46, .65),
            const Point(.54, .65)
          ),
        'hip widen' => (
            const Point(.38, .30),
            const Point(.62, .30),
            const Point(.38, .65),
            const Point(.62, .65)
          ),
        _ => (
            const Point(.62, .30),
            const Point(.38, .30),
            const Point(.42, .65),
            const Point(.58, .65)
          )
      };
      e.update(
          frame(t + 50000,
              leftShoulder: ls, rightShoulder: rs, leftHip: lh, rightHip: rh),
          nowMicros: t + 50000);
      expect(e.phase, ReachTapPhase.trackingLost, reason: e.feedback);
      expect(e.activeMicros, 0);
      expect(e.hits, 0);
    });
  }

  for (final size in [(400.0, 800.0), (800.0, 400.0), (600.0, 600.0)]) {
    test('continuous projected reaches and partial wrists stay fresh at $size',
        () {
      final e = ReachTapEngine(random: Random(45));
      var t = start(e, width: size.$1, height: size.$2);
      // Pixel offsets keep the synthetic excursion comparable across boards.
      for (var i = 0; i < 300; i++) {
        t += 50000;
        final wave = (sin(i / 7) + 1) / 2;
        e.update(
            frame(t,
                width: size.$1,
                height: size.$2,
                left: e.target,
                noRight: i % 20 < 10,
                noLeftElbow: true,
                leftShoulder: Point(
                    .38 + 38 * wave / size.$1, .30 - 32 * wave / size.$2)),
            nowMicros: t);
        expect(e.phase, ReachTapPhase.playing, reason: e.feedback);
      }
      expect(e.activeMicros, 15000000);
      expect(e.hits, greaterThan(15));
      expect(e.score, e.hits * 10);
    });
  }
}
