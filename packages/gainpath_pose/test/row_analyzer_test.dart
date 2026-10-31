import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'support/row_trajectory.dart';

void feed(RowAnalyzer a, Iterable<PoseFrame> frames) {
  for (final frame in frames) {
    a.update(frame, nowMicros: frame.capturedAtMicros);
  }
}

RowAnalyzer calibrated() {
  final a = RowAnalyzer(side: RowSide.left);
  for (var t = 0; t <= 800000; t += 50000) {
    a.update(rowFrame(t, 0), nowMicros: t);
  }
  expect(a.snapshot.needsCalibration, false);
  return a;
}

void main() {
  for (final side in RowSide.values) {
    final requiredJoints = side == RowSide.left
        ? const [
            PoseLandmark.leftShoulder,
            PoseLandmark.leftElbow,
            PoseLandmark.leftWrist,
            PoseLandmark.leftHip
          ]
        : const [
            PoseLandmark.rightShoulder,
            PoseLandmark.rightElbow,
            PoseLandmark.rightWrist,
            PoseLandmark.rightHip
          ];
    Iterable<PoseFrame> withRequiredJoints({PoseLandmark? missing}) sync* {
      for (final f in rowTrajectory(side: side)) {
        yield PoseFrame(
            capturedAtMicros: f.capturedAtMicros,
            detectorId: f.detectorId,
            modelVersion: f.modelVersion,
            imageWidth: f.imageWidth,
            imageHeight: f.imageHeight,
            landmarks: {
              for (final id in requiredJoints)
                if (id != missing) id: f.landmarks[id]!
            });
      }
    }

    test('$side counts one row with only shoulder elbow wrist and hip visible',
        () {
      final a = RowAnalyzer(side: side);
      feed(a, withRequiredJoints());
      expect(a.snapshot.repetitions, 1);
      expect(a.snapshot.partialRepetitions, 0);
    });
    for (final missing in requiredJoints) {
      test('$side missing $missing cannot calibrate or count', () {
        final a = RowAnalyzer(side: side);
        feed(a, withRequiredJoints(missing: missing));
        expect(a.snapshot.needsCalibration, true);
        expect(a.snapshot.repetitions, 0);
        expect(a.snapshot.partialRepetitions, 0);
        expect(a.snapshot.trackedDurationMicros, 0);
      });
    }
  }
  for (final side in RowSide.values) {
    for (final left in [false, true]) {
      for (final step in [16667, 50000, 125000]) {
        test('$side facingLeft=$left counts controlled row at $step us', () {
          final a = RowAnalyzer(side: side);
          feed(
              a, rowTrajectory(side: side, facingLeft: left, stepMicros: step));
          expect(a.snapshot.repetitions, 1);
          expect(a.snapshot.partialRepetitions, 0);
          expect(a.snapshot.selectedSide, side);
          expect(a.snapshot.formScorePercent, isNull);
          expect(a.snapshot.phase, RowPhase.ready);
          expect(a.snapshot.trackedDurationMicros, greaterThan(1000000));
        });
      }
    }
  }
  test('horizontal torso calibrates and aspect ratio preserves joint angles',
      () {
    final a = RowAnalyzer(side: RowSide.left);
    feed(a, rowTrajectory(horizontalTorso: true));
    expect(a.snapshot.repetitions, 1);
    for (final size in [(400, 800), (800, 400)]) {
      final geometry = RowGeometry.fromFrame(
          rowFrame(0, 1, width: size.$1, height: size.$2), RowSide.left)!;
      expect(geometry.elbowAngleDegrees, closeTo(80, .001));
      expect(geometry.torsoLength, closeTo(.2236068, .000001));
    }
  });
  test('shallow genuine row records partial without fabricating a score', () {
    final a = RowAnalyzer(side: RowSide.left);
    feed(a, rowTrajectory(amplitude: .60));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 1);
    expect(a.snapshot.formScorePercent, isNull);
  });
  test('bent-over curl cannot count full or partial rows', () {
    final a = RowAnalyzer(side: RowSide.left);
    feed(a, rowTrajectory(curlOnly: true));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('static jitter and one isolated deep spike cannot count', () {
    final a = calibrated();
    for (var t = 850000; t < 2500000; t += 50000) {
      a.update(
          rowFrame(t, t == 1500000 ? 1 : .02,
              jitter: (t ~/ 50000).isEven ? .001 : -.001),
          nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('bent starting arm and moving calibration never arm the counter', () {
    for (final moving in [false, true]) {
      final a = RowAnalyzer(side: RowSide.left);
      for (var t = 0; t < 2000000; t += 50000) {
        a.update(
            rowFrame(t, moving ? 0 : 1,
                shoulderShift: moving
                    ? (t ~/ 50000).isEven
                        ? .04
                        : 0
                    : 0),
            nowMicros: t);
      }
      expect(a.snapshot.needsCalibration, true);
      expect(a.snapshot.repetitions, 0);
    }
  });
  for (final mode in [
    'pause',
    'confidence',
    'stale',
    'mirror',
    'gap',
    'duplicate',
    'backwards',
    'dimensions',
    'rocking',
    'displacement'
  ]) {
    test('$mode invalidates a peak and cannot bridge the return', () {
      final a = RowAnalyzer(side: RowSide.left);
      feed(a, rowTrajectory().where((f) => f.capturedAtMicros <= 2100000));
      if (mode == 'pause') a.pause();
      final t = mode == 'duplicate'
          ? 2100000
          : mode == 'backwards'
              ? 2050000
              : mode == 'gap'
                  ? 2500000
                  : 2150000;
      a.update(
          rowFrame(t, .8,
              confidence: mode == 'confidence' ? .2 : .99,
              mirrored: mode == 'mirror',
              width: mode == 'dimensions' ? 800 : 400,
              shoulderShift:
                  mode == 'rocking' || mode == 'displacement' ? .08 : 0,
              hipShift: mode == 'displacement' ? .08 : 0),
          nowMicros: mode == 'stale'
              ? t + 300000
              : 2150000 > t
                  ? 2150000
                  : t);
      expect(a.snapshot.needsCalibration, true);
      for (var next = 2850000; next < 4000000; next += 50000) {
        a.update(rowFrame(next, 0), nowMicros: next);
      }
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  test('tick rejects delayed tracking and preserves finished repetitions', () {
    final a = RowAnalyzer(side: RowSide.left);
    feed(a, rowTrajectory());
    final tracked = a.snapshot.trackedDurationMicros;
    a.tick(nowMicros: 3700000);
    expect(a.snapshot.health, TrackingStatus.lost);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 1);
    expect(a.snapshot.trackedDurationMicros, tracked);
    expect(a.snapshot.rejectedDurationMicros, greaterThan(0));
  });
  test('invalid/missing selected joints fail closed without side switching',
      () {
    final a = calibrated();
    a.update(rowFrame(850000, 0, side: RowSide.right), nowMicros: 850000);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.selectedSide, RowSide.left);
    final f = rowFrame(900000, 0);
    final invalid = PoseFrame(
        capturedAtMicros: 900000,
        detectorId: 'bad',
        modelVersion: '1',
        landmarks: {
          ...f.landmarks,
          PoseLandmark.leftWrist:
              const PosePoint(x: double.nan, y: .5, z: 0, visibility: 1)
        });
    expect(RowGeometry.fromFrame(invalid, RowSide.left), isNull);
    expect(RowGeometry.confidence(invalid, RowSide.left), 0);
  });
  test('repeated cycles retain exact counts in bounded stream state', () {
    final a = RowAnalyzer(side: RowSide.left);
    for (var n = 0; n < 20; n++) {
      feed(a, rowTrajectory(startMicros: n * 3350000));
    }
    expect(a.snapshot.repetitions, 20);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('a moving nearly extended arm cannot complete stable calibration', () {
    final a = RowAnalyzer(side: RowSide.left);
    for (var t = 0; t < 2000000; t += 50000) {
      a.update(rowFrame(t, (t ~/ 50000).isEven ? 0 : .18), nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.calibrationProgress, lessThan(1));
  });
  for (final speed in [.65, 3.0]) {
    test('one controlled cycle retains its count at duration factor $speed',
        () {
      final a = RowAnalyzer(side: RowSide.left);
      for (final f in rowTrajectory()) {
        // Keep the required still calibration window; vary the movement only.
        final t = f.capturedAtMicros <= 900000
            ? f.capturedAtMicros
            : 900000 + ((f.capturedAtMicros - 900000) * speed).round();
        a.update(
            PoseFrame(
                capturedAtMicros: t,
                detectorId: f.detectorId,
                modelVersion: f.modelVersion,
                landmarks: f.landmarks,
                imageWidth: f.imageWidth,
                imageHeight: f.imageHeight),
            nowMicros: t);
      }
      expect(a.snapshot.repetitions, 1);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  test('a held peak times out and cannot count when eventually lowered', () {
    final a = RowAnalyzer(side: RowSide.left);
    feed(a, rowTrajectory().where((f) => f.capturedAtMicros <= 2100000));
    for (var t = 2150000; t < 19000000; t += 50000) {
      a.update(rowFrame(t, 1), nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, true);
    for (var t = 19000000; t < 20500000; t += 50000) {
      a.update(rowFrame(t, 0), nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('capture gap rejects its whole duration without inventing tracked time',
      () {
    final a = calibrated();
    final before = a.snapshot;
    a.update(rowFrame(1100000, 0), nowMicros: 1100000);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.trackedDurationMicros, before.trackedDurationMicros);
    expect(a.snapshot.rejectedDurationMicros,
        before.rejectedDurationMicros + 300000);
  });
  test(
      'ticks and invalid frames account for elapsed time once and pause excludes gaps',
      () {
    final a = calibrated();
    final before = a.snapshot;
    a.tick(nowMicros: 850000);
    expect(
        a.snapshot.trackedDurationMicros, before.trackedDurationMicros + 50000);
    a.update(rowFrame(900000, 0, confidence: .2), nowMicros: 900000);
    expect(
        a.snapshot.trackedDurationMicros, before.trackedDurationMicros + 50000);
    expect(a.snapshot.rejectedDurationMicros,
        before.rejectedDurationMicros + 50000);
    a.tick(nowMicros: 950000);
    a.update(rowFrame(950000, 0, confidence: .2), nowMicros: 950000);
    expect(a.snapshot.rejectedDurationMicros,
        before.rejectedDurationMicros + 100000);
    final paused = a.snapshot;
    a.pause();
    a.tick(nowMicros: 5000000);
    a.update(rowFrame(5000000, 0), nowMicros: 5000000);
    expect(a.snapshot.trackedDurationMicros, paused.trackedDurationMicros);
    expect(a.snapshot.rejectedDurationMicros, paused.rejectedDurationMicros);
  });
}
