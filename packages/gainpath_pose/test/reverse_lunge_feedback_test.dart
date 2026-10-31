import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/reverse_lunge_trajectory.dart';

PoseFrame change(PoseFrame f,
        {Set<PoseLandmark> remove = const {}, double jitter = 0}) =>
    PoseFrame(
        capturedAtMicros: f.capturedAtMicros,
        detectorId: f.detectorId,
        modelVersion: f.modelVersion,
        imageWidth: f.imageWidth,
        imageHeight: f.imageHeight,
        landmarks: {
          for (final e in f.landmarks.entries)
            if (!remove.contains(e.key))
              e.key: PosePoint(
                  x: e.value.x + jitter * f.imageHeight / f.imageWidth,
                  y: e.value.y,
                  z: e.value.z,
                  visibility: e.value.visibility,
                  presence: e.value.presence)
        });

Iterable<PoseFrame> overlapping(
    {LungeSide side = LungeSide.left,
    bool facingLeft = false,
    int interval = 50000,
    int width = 400,
    int height = 800,
    bool forward = false,
    bool wrongLeg = false}) sync* {
  for (var t = 0; t <= 4700000; t += interval) {
    final p = t < 1200000
        ? 0.0
        : t < 2400000
            ? (t - 1200000) / 1200000
            : t < 2800000
                ? 1.0
                : t < 4000000
                    ? 1 - (t - 2800000) / 1200000
                    : 0.0;
    yield reverseLungeFrame(t, p, p,
        side: side,
        facingLeft: facingLeft,
        width: width,
        height: height,
        forward: forward,
        wrongLeg: wrongLeg);
  }
}

void feed(ReverseLungeAnalyzer a, Iterable<PoseFrame> frames) {
  for (final f in frames) {
    a.update(f, nowMicros: f.capturedAtMicros);
  }
}

void main() {
  for (final side in LungeSide.values) {
    final optional = side == LungeSide.left
        ? {
            PoseLandmark.rightHeel,
            PoseLandmark.rightFootIndex,
            PoseLandmark.rightShoulder
          }
        : {
            PoseLandmark.leftHeel,
            PoseLandmark.leftFootIndex,
            PoseLandmark.leftShoulder
          };
    for (final facing in [false, true]) {
      test('far shoulder and far foot may be occluded $side facing=$facing',
          () {
        final a = ReverseLungeAnalyzer(side: side);
        feed(
            a,
            reverseLungeTrajectory(side: side, facingLeft: facing)
                .map((f) => change(f, remove: optional)));
        expect(a.snapshot.needsCalibration, isFalse);
        expect(a.snapshot.repetitions, 1);
      });
      for (final interval in [33333, 50000, 100000]) {
        for (final dimensions in [(400, 800), (800, 400), (1080, 1920)]) {
          test(
              'observed overlapping step and descent $side facing=$facing interval=$interval size=$dimensions',
              () {
            final a = ReverseLungeAnalyzer(side: side);
            feed(
                a,
                overlapping(
                    side: side,
                    facingLeft: facing,
                    interval: interval,
                    width: dimensions.$1,
                    height: dimensions.$2));
            expect(a.snapshot.repetitions, 1);
            expect(a.snapshot.partialRepetitions, 0);
          });
        }
      }
    }
    test('bounded neutral jitter settles using stable window $side', () {
      final a = ReverseLungeAnalyzer(side: side);
      feed(a, [
        for (var t = 0; t <= 1600000; t += 50000)
          change(reverseLungeFrame(t, 0, 0, side: side),
              jitter: .014 * math.cos(t / 50000 * math.pi))
      ]);
      expect(a.snapshot.needsCalibration, isFalse);
      expect(a.snapshot.repetitions, 0);
    });
    test(
        'brief weak calibration frame pauses without losing valid evidence $side',
        () {
      final a = ReverseLungeAnalyzer(side: side);
      feed(a, [
        for (var t = 0; t <= 950000; t += 50000)
          reverseLungeFrame(t, 0, 0,
              side: side, confidence: t == 400000 ? .2 : .99)
      ]);
      expect(a.snapshot.needsCalibration, isFalse);
      expect(a.snapshot.trackedDurationMicros, lessThanOrEqualTo(50000));
    });
    test('weak calibration evidence receives no hold credit $side', () {
      final a = ReverseLungeAnalyzer(side: side);
      feed(a, [
        for (var t = 0; t <= 800000; t += 50000)
          reverseLungeFrame(t, 0, 0,
              side: side, confidence: t == 400000 ? .2 : .99)
      ]);
      expect(a.snapshot.needsCalibration, isTrue);
    });
    test('coherent camera drift cannot calibrate $side', () {
      final a = ReverseLungeAnalyzer(side: side);
      feed(a, [
        for (var t = 0; t <= 1600000; t += 50000)
          change(reverseLungeFrame(t, 0, 0, side: side),
              jitter: t / 1600000 * .05)
      ]);
      expect(a.snapshot.needsCalibration, isTrue);
    });
    final required = side == LungeSide.left
        ? {
            PoseLandmark.leftShoulder,
            PoseLandmark.leftHip,
            PoseLandmark.leftKnee,
            PoseLandmark.leftAnkle,
            PoseLandmark.leftHeel,
            PoseLandmark.leftFootIndex,
            PoseLandmark.rightHip,
            PoseLandmark.rightAnkle
          }
        : {
            PoseLandmark.rightShoulder,
            PoseLandmark.rightHip,
            PoseLandmark.rightKnee,
            PoseLandmark.rightAnkle,
            PoseLandmark.rightHeel,
            PoseLandmark.rightFootIndex,
            PoseLandmark.leftHip,
            PoseLandmark.leftAnkle
          };
    for (final id in required) {
      for (final invalid in ['missing', 'weak', 'nonfinite']) {
        test('$invalid required $id cannot set up $side and names the joint',
            () {
          final f = reverseLungeFrame(0, 0, 0, side: side);
          final points = Map.of(f.landmarks);
          final p = points[id]!;
          if (invalid == 'missing') {
            points.remove(id);
          } else {
            points[id] = PosePoint(
                x: invalid == 'nonfinite' ? double.nan : p.x,
                y: p.y,
                z: p.z,
                visibility: invalid == 'weak' ? .69 : .99);
          }
          final changed = PoseFrame(
              capturedAtMicros: 0,
              detectorId: f.detectorId,
              modelVersion: f.modelVersion,
              imageWidth: f.imageWidth,
              imageHeight: f.imageHeight,
              landmarks: points);
          expect(ReverseLungeGeometry.canSetup(changed, side), isFalse);
          expect(
              ReverseLungeGeometry.setupCue(changed, side),
              contains(id.name.contains('FootIndex')
                  ? 'toes'
                  : id.name
                      .replaceAll(RegExp(r'left|right'), '')
                      .toLowerCase()));
          final a = ReverseLungeAnalyzer(side: side)
            ..update(changed, nowMicros: 0);
          expect(a.snapshot.rejectionReason, contains(id.name));
        });
      }
    }
    test('weak working sample discards overlapping cycle $side', () {
      final a = ReverseLungeAnalyzer(side: side);
      feed(
          a,
          overlapping(side: side).map((f) => f.capturedAtMicros == 2500000
              ? change(f, remove: {required.first})
              : f));
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
    });
    test('repeated weak observations never provide calibration credit $side',
        () {
      final a = ReverseLungeAnalyzer(side: side);
      feed(a, [
        for (var t = 0; t <= 2000000; t += 50000)
          reverseLungeFrame(t, 0, 0,
              side: side, confidence: (t ~/ 50000).isEven ? .99 : .2)
      ]);
      expect(a.snapshot.needsCalibration, isTrue);
      expect(a.snapshot.trackedDurationMicros, 0);
    });
    test('weak observations beyond grace require a new neutral hold $side', () {
      final a = ReverseLungeAnalyzer(side: side);
      feed(a, [
        for (var t = 0; t <= 1100000; t += 50000)
          reverseLungeFrame(t, 0, 0,
              side: side, confidence: t >= 350000 && t <= 600000 ? .2 : .99)
      ]);
      expect(a.snapshot.needsCalibration, isTrue);
      feed(a, [
        for (var t = 1150000; t <= 1500000; t += 50000)
          reverseLungeFrame(t, 0, 0, side: side)
      ]);
      expect(a.snapshot.needsCalibration, isFalse);
    });
  }
  for (final kind in ['forward', 'wrong leg']) {
    test('overlapping $kind remains rejected', () {
      final a = ReverseLungeAnalyzer(side: LungeSide.left);
      feed(
          a,
          overlapping(
              forward: kind == 'forward', wrongLeg: kind == 'wrong leg'));
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  test('brief low pose-presence frame pauses calibration without resetting',
      () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a, [
      for (var t = 0; t <= 950000; t += 50000)
        if (t == 400000)
          PoseFrame(
              capturedAtMicros: t,
              detectorId: 'synthetic-reverse-lunge',
              modelVersion: '1',
              imageWidth: 400,
              imageHeight: 800,
              posePresence: .5,
              landmarks: reverseLungeFrame(t, 0, 0).landmarks)
        else
          reverseLungeFrame(t, 0, 0)
    ]);
    expect(a.snapshot.needsCalibration, isFalse);
    expect(a.snapshot.trackedDurationMicros, lessThanOrEqualTo(50000));
  });
  test('setup feedback distinguishes bent selected knee from feet apart', () {
    expect(
        ReverseLungeGeometry.setupCue(
            reverseLungeFrame(0, 0, .1), LungeSide.left),
        contains('selected front knee'));
    final f = reverseLungeFrame(0, 0, 0);
    final moved = PoseFrame(
        capturedAtMicros: 0,
        detectorId: f.detectorId,
        modelVersion: f.modelVersion,
        imageWidth: f.imageWidth,
        imageHeight: f.imageHeight,
        landmarks: {
          for (final e in f.landmarks.entries)
            e.key: PosePoint(
                x: e.value.x - (e.key == PoseLandmark.rightAnkle ? .32 : 0),
                y: e.value.y,
                z: 0,
                visibility: .99)
        });
    expect(ReverseLungeGeometry.setupCue(moved, LungeSide.left),
        contains('comfortably apart'));
  });
  test(
      'descent before the observed backstep cannot become an overlapping cycle',
      () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a, [
      for (var t = 0; t <= 4700000; t += 50000)
        reverseLungeFrame(
            t,
            t < 1800000
                ? 0
                : t < 2400000
                    ? (t - 1800000) / 600000
                    : t < 2800000
                        ? 1
                        : t < 4000000
                            ? 1 - (t - 2800000) / 1200000
                            : 0,
            t < 1200000
                ? 0
                : t < 1800000
                    ? (t - 1200000) / 600000
                    : t < 2800000
                        ? 1
                        : t < 4000000
                            ? 1 - (t - 2800000) / 1200000
                            : 0)
    ]);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('setup and calibration diagnostics contain scalar measurements only',
      () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    a.update(reverseLungeFrame(0, 0, .1), nowMicros: 0);
    expect(a.snapshot.rejectionReason, 'neutral_knees_bent');
    expect(a.snapshot.diagnostics.keys, contains('frontKneeDegrees'));
    feed(a, [
      for (var t = 50000; t <= 900000; t += 50000) reverseLungeFrame(t, 0, 0)
    ]);
    expect(a.snapshot.needsCalibration, isFalse);
    expect(a.snapshot.rejectionReason, isNull);
    expect(a.snapshot.diagnostics.values.every((v) => v.isFinite), isTrue);
    expect(
        ReverseLungeGeometry.setupCue(
            reverseLungeFrame(0, 0, 0), LungeSide.left),
        isNull);
  });
  test('outliers between stored time buckets never provide neutral hold credit',
      () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a, [
      for (var t = 0; t <= 800000; t += 25000)
        change(reverseLungeFrame(t, 0, 0), jitter: t % 50000 == 25000 ? .06 : 0)
    ]);
    expect(a.snapshot.needsCalibration, isTrue);
    expect(a.snapshot.trackedDurationMicros, 0);
  });
}
