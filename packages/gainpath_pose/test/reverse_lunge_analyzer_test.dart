import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/reverse_lunge_trajectory.dart';

void feed(ReverseLungeAnalyzer analyzer, Iterable<PoseFrame> frames) {
  for (final f in frames) {
    analyzer.update(f, nowMicros: f.capturedAtMicros);
  }
}

void main() {
  for (final side in LungeSide.values) {
    for (final facingLeft in [false, true]) {
      for (final step in [33333, 50000, 100000]) {
        test('counts one $side facingLeft=$facingLeft interval=$step', () {
          final a = ReverseLungeAnalyzer(side: side);
          feed(
              a,
              reverseLungeTrajectory(
                  side: side, facingLeft: facingLeft, stepMicros: step));
          expect(a.snapshot.repetitions, 1);
          expect(a.snapshot.partialRepetitions, 0);
          expect(a.snapshot.formScorePercent, isNull);
          expect(a.snapshot.selectedSide, side);
        });
      }
    }
  }
  test('requires sustained fresh neutral setup', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    a.update(reverseLungeFrame(0, 0, 0), nowMicros: 0);
    a.update(reverseLungeFrame(800000, 0, 0), nowMicros: 800000);
    expect(a.snapshot.needsCalibration, isTrue);
    feed(a, [
      for (var t = 850000; t <= 1700000; t += 50000) reverseLungeFrame(t, 0, 0)
    ]);
    expect(a.snapshot.needsCalibration, isFalse);
  });
  test('shallow stepped movement is partial', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a, reverseLungeTrajectory(amplitude: .4));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 1);
  });
  for (final kind in ['forward', 'wrong leg', 'squat', 'static split']) {
    test('rejects $kind', () {
      final a = ReverseLungeAnalyzer(side: LungeSide.left);
      feed(
          a,
          kind == 'static split'
              ? [
                  for (var t = 0; t < 4300000; t += 50000)
                    reverseLungeFrame(t, 1, .7)
                ]
              : reverseLungeTrajectory(
                  forward: kind == 'forward',
                  wrongLeg: kind == 'wrong leg',
                  squat: kind == 'squat'));
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  for (final interruption in [
    'pause',
    'occlusion',
    'stale',
    'gap',
    'duplicate',
    'tick'
  ]) {
    test('$interruption discards unfinished repetition', () {
      final a = ReverseLungeAnalyzer(side: LungeSide.left);
      final frames = reverseLungeTrajectory().toList();
      feed(a, frames.where((f) => f.capturedAtMicros <= 2500000));
      switch (interruption) {
        case 'pause':
          a.pause();
        case 'occlusion':
          a.update(reverseLungeFrame(2550000, 1, 1, confidence: .2),
              nowMicros: 2550000);
        case 'stale':
          a.update(reverseLungeFrame(2550000, 1, 1), nowMicros: 3000000);
        case 'gap':
          a.update(reverseLungeFrame(2900000, 1, .5), nowMicros: 2900000);
        case 'duplicate':
          a.update(reverseLungeFrame(2500000, 1, 1), nowMicros: 2550000);
        case 'tick':
          a.tick(nowMicros: 2900000);
      }
      feed(a, frames.where((f) => f.capturedAtMicros >= 3050000));
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
      feed(a, reverseLungeTrajectory(startMicros: 4400000));
      expect(a.snapshot.repetitions, 1);
    });
  }
  test('tick never credits more than the fresh frame horizon', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a,
        [for (var t = 0; t <= 1000000; t += 50000) reverseLungeFrame(t, 0, 0)]);
    final before = a.snapshot.trackedDurationMicros;
    a.tick(nowMicros: 1100000);
    a.tick(nowMicros: 2000000);
    expect(
        a.snapshot.trackedDurationMicros - before, lessThanOrEqualTo(250000));
    expect(a.snapshot.rejectedDurationMicros, greaterThanOrEqualTo(750000));
  });
  for (final dimensions in [(400, 800), (800, 400), (1080, 1920)]) {
    test('aspect corrected motion $dimensions', () {
      final a = ReverseLungeAnalyzer(side: LungeSide.left);
      feed(a,
          reverseLungeTrajectory(width: dimensions.$1, height: dimensions.$2));
      expect(a.snapshot.repetitions, 1);
    });
  }
  test('one bottom spike cannot count', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a,
        [for (var t = 0; t <= 1000000; t += 50000) reverseLungeFrame(t, 0, 0)]);
    a.update(reverseLungeFrame(1050000, 1, 1), nowMicros: 1050000);
    feed(a, [
      for (var t = 1100000; t <= 1600000; t += 50000) reverseLungeFrame(t, 0, 0)
    ]);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('setup rejects hidden joints, mirrored frames and split stance', () {
    expect(
        ReverseLungeGeometry.canSetup(
            reverseLungeFrame(0, 0, 0), LungeSide.left),
        isTrue);
    expect(
        ReverseLungeGeometry.canSetup(
            reverseLungeFrame(0, 0, 0, confidence: .69), LungeSide.left),
        isFalse);
    expect(
        ReverseLungeGeometry.canSetup(
            reverseLungeFrame(0, 0, 0, mirrored: true), LungeSide.left),
        isFalse);
    expect(
        ReverseLungeGeometry.canSetup(
            reverseLungeFrame(0, 1, 0), LungeSide.left),
        isFalse);
  });
  test('airborne front foot cannot create a reverse lunge', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(
        a,
        reverseLungeTrajectory().map((f) {
          if (f.capturedAtMicros < 1150000) return f;
          return copyFrame(f, landmarks: {
            for (final e in f.landmarks.entries)
              e.key: PosePoint(
                  x: e.value.x, y: e.value.y - .03, z: 0, visibility: .99)
          });
        }));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('backstep without hip descent is not a partial repetition', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a, reverseLungeTrajectory(amplitude: 0));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('standing must bring the rear foot back before a count', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a,
        reverseLungeTrajectory().where((f) => f.capturedAtMicros <= 3300000));
    feed(a, [
      for (var t = 3350000; t <= 4300000; t += 50000) reverseLungeFrame(t, 1, 0)
    ]);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('walking camera translation cannot count', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(
        a,
        reverseLungeTrajectory().map((f) => f.capturedAtMicros < 1150000
            ? f
            : copyFrame(f, landmarks: {
                for (final e in f.landmarks.entries)
                  e.key: PosePoint(
                      x: e.value.x + .12, y: e.value.y, z: 0, visibility: .99)
              })));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  for (final id in [
    PoseLandmark.leftHip,
    PoseLandmark.rightHip,
    PoseLandmark.leftKnee,
    PoseLandmark.leftAnkle,
    PoseLandmark.rightAnkle
  ]) {
    test('missing $id prevents setup', () {
      final f = reverseLungeFrame(0, 0, 0);
      expect(
          ReverseLungeGeometry.canSetup(
              copyFrame(f, landmarks: Map.of(f.landmarks)..remove(id)),
              LungeSide.left),
          isFalse);
    });
  }
  for (final invalid in [double.nan, double.infinity, -.1, 1.1]) {
    test('invalid landmark coordinate $invalid is rejected', () {
      final f = reverseLungeFrame(0, 0, 0);
      final landmarks = Map.of(f.landmarks);
      landmarks[PoseLandmark.leftKnee] =
          PosePoint(x: invalid, y: .6, z: 0, visibility: .99);
      expect(
          ReverseLungeGeometry.canSetup(
              copyFrame(f, landmarks: landmarks), LungeSide.left),
          isFalse);
    });
  }
  for (final discontinuity in ['dimensions', 'model', 'detector', 'facing']) {
    test('$discontinuity change breaks a started cycle', () {
      final a = ReverseLungeAnalyzer(side: LungeSide.left);
      feed(
          a,
          reverseLungeTrajectory().map((f) => f.capturedAtMicros < 2500000
              ? f
              : discontinuity == 'facing'
                  ? reverseLungeFrame(f.capturedAtMicros, 1, 1,
                      facingLeft: true)
                  : copyFrame(f,
                      width: discontinuity == 'dimensions' ? 800 : null,
                      model: discontinuity == 'model' ? '2' : null,
                      detector: discontinuity == 'detector' ? 'new' : null)));
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  test('backdated now and future capture cannot increase tracked time', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a,
        [for (var t = 0; t <= 1000000; t += 50000) reverseLungeFrame(t, 0, 0)]);
    final tracked = a.snapshot.trackedDurationMicros;
    a.update(reverseLungeFrame(1100000, 0, 0), nowMicros: 900000);
    a.update(reverseLungeFrame(1200000, 0, 0), nowMicros: 1100000);
    expect(a.snapshot.trackedDurationMicros, tracked);
    expect(a.snapshot.needsCalibration, isTrue);
  });
  test('repeated observations do not grow a completed count', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a, reverseLungeTrajectory());
    feed(a, [
      for (var t = 4350000; t <= 6000000; t += 50000) reverseLungeFrame(t, 0, 0)
    ]);
    expect(a.snapshot.repetitions, 1);
  });
  test('combined full and partial counts stop at wire maximum', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(a, [
      for (var t = 0; t <= 1000000; t += 100000) reverseLungeFrame(t, 0, 0)
    ]);
    for (var i = 0; i < 10001; i++) {
      final start = 1100000 + i * 1100000;
      for (var j = 0; j <= 10; j++) {
        final step = j <= 6 ? 1.0 : 0.0;
        final depth = j >= 2 && j <= 4 ? (i.isEven ? 1.0 : .4) : 0.0;
        final t = start + j * 100000;
        a.update(reverseLungeFrame(t, step, depth), nowMicros: t);
      }
    }
    expect(a.snapshot.repetitions, 5000);
    expect(a.snapshot.partialRepetitions, 5000);
  });
  test('small independent landmark jitter still counts a controlled cycle', () {
    final a = ReverseLungeAnalyzer(side: LungeSide.left);
    feed(
        a,
        reverseLungeTrajectory().map((f) => copyFrame(f, landmarks: {
              for (final e in f.landmarks.entries)
                e.key: PosePoint(
                    x: e.value.x +
                        .0015 *
                            math.sin(f.capturedAtMicros / 83000 + e.key.index),
                    y: e.value.y +
                        .0015 *
                            math.cos(f.capturedAtMicros / 71000 + e.key.index),
                    z: 0,
                    visibility: .99)
            })));
    expect(a.snapshot.repetitions, 1);
    expect(a.snapshot.partialRepetitions, 0);
  });
}

PoseFrame copyFrame(PoseFrame frame,
        {Map<PoseLandmark, PosePoint>? landmarks,
        int? width,
        String? model,
        String? detector}) =>
    PoseFrame(
        capturedAtMicros: frame.capturedAtMicros,
        detectorId: detector ?? frame.detectorId,
        modelVersion: model ?? frame.modelVersion,
        imageWidth: width ?? frame.imageWidth,
        imageHeight: frame.imageHeight,
        landmarks: landmarks ?? frame.landmarks);
