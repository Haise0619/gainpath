import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

PoseFrame calfFrame(int time, double lift,
    {CalfSide side = CalfSide.left,
    double confidence = .99,
    double toeShift = 0,
    bool bent = false,
    bool mirrored = false,
    int width = 400,
    int height = 800}) {
  PosePoint p(double x, double y) => PosePoint(
      x: x * height / width,
      y: y,
      z: 0,
      visibility: confidence,
      presence: confidence);
  final joints = CalfRaiseGeometry.joints(side);
  return PoseFrame(
      capturedAtMicros: time,
      detectorId: 'fixture',
      modelVersion: '1',
      imageWidth: width,
      imageHeight: height,
      isMirrored: mirrored,
      landmarks: {
        joints[0]: p(bent ? .36 : .20, .35 - lift * .2),
        joints[1]: p(.20, .55 - lift * .2),
        joints[2]: p(.20, .75 - lift * .2),
        joints[3]: p(.19, .80 - lift * .2),
        joints[4]: p(.26, .80 + toeShift),
      });
}

void main() {
  test('the bounded calibration window can finish on high-rate fresh input',
      () {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 1100000; t += 10000) {
      a.update(calfFrame(t, 0), nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
    expect(a.snapshot.repetitions, 0);
  });
  test(
      'independent toe heel and shin jitter does not repeatedly restart the hold',
      () {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 1400000; t += 100000) {
      final src = calfFrame(t, 0), sign = (t ~/ 100000).isEven ? 1.0 : -1.0;
      final heel = src.landmark(PoseLandmark.leftHeel)!,
          toe = src.landmark(PoseLandmark.leftFootIndex)!,
          knee = src.landmark(PoseLandmark.leftKnee)!;
      a.update(
          PoseFrame(
              capturedAtMicros: t,
              detectorId: 'fixture',
              modelVersion: '1',
              imageWidth: 400,
              imageHeight: 800,
              landmarks: {
                ...src.landmarks,
                PoseLandmark.leftHeel: PosePoint(
                    x: heel.x,
                    y: heel.y + sign * .004,
                    z: 0,
                    visibility: .99,
                    presence: .99),
                PoseLandmark.leftFootIndex: PosePoint(
                    x: toe.x + sign * .007,
                    y: toe.y + sign * .001,
                    z: 0,
                    visibility: .99,
                    presence: .99),
                PoseLandmark.leftKnee: PosePoint(
                    x: knee.x,
                    y: knee.y + sign * .006,
                    z: 0,
                    visibility: .99,
                    presence: .99),
              }),
          nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test(
      'one brief weak sample pauses calibration progress without discarding the hold',
      () {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 500000; t += 100000) {
      a.update(calfFrame(t, 0), nowMicros: t);
    }
    final before = a.snapshot.calibrationProgress;
    a.update(calfFrame(600000, 0, confidence: .6), nowMicros: 600000);
    expect(a.snapshot.calibrationProgress, before);
    expect(a.snapshot.needsCalibration, true);
    for (var t = 700000; t <= 1100000; t += 100000) {
      a.update(calfFrame(t, 0), nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
    expect(a.snapshot.repetitions, 0);
  });
  test('moving through heel raises cannot satisfy a neutral calibration window',
      () {
    final a = CalfRaiseAnalyzer();
    for (var i = 0; i < 30; i++) {
      final phase = i % 8;
      final lift = (phase <= 4 ? phase : 8 - phase) * .035;
      final t = i * 100000;
      a.update(calfFrame(t, lift), nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
  });
  test(
      'a stable projected foot slope can calibrate and count relative heel rise',
      () {
    PoseFrame projected(int t, double lift) {
      final source = calfFrame(t, lift);
      final heel = source.landmark(PoseLandmark.leftHeel)!;
      return PoseFrame(
          capturedAtMicros: t,
          detectorId: 'fixture',
          modelVersion: '1',
          imageWidth: 400,
          imageHeight: 800,
          landmarks: {
            ...source.landmarks,
            PoseLandmark.leftHeel: PosePoint(
                x: heel.x,
                y: heel.y - .036,
                z: 0,
                visibility: .99,
                presence: .99)
          });
    }

    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 1000000; t += 100000) {
      a.update(projected(t, 0), nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
    final lifts = <double>[.02, .04, .07, .11, .11, .11, .07, .04, .01, 0];
    for (var i = 0; i < lifts.length; i++) {
      final t = 1150000 + i * 150000;
      a.update(projected(t, lifts[i]), nowMicros: t);
    }
    expect(a.snapshot.repetitions, 1);
  });
  test('small stationary landmark jitter can settle into calibration', () {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 1600000; t += 100000) {
      final original = calfFrame(t, 0);
      final jitter = (t ~/ 100000).isEven ? .002 : -.002;
      a.update(
          PoseFrame(
              capturedAtMicros: t,
              detectorId: 'fixture',
              modelVersion: '1',
              imageWidth: 400,
              imageHeight: 800,
              landmarks: {
                for (final entry in original.landmarks.entries)
                  entry.key: PosePoint(
                      x: entry.value.x,
                      y: entry.value.y +
                          (entry.key == PoseLandmark.leftHeel ? jitter : 0),
                      z: 0,
                      visibility: .99,
                      presence: .99)
              }),
          nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
  });
  test(
      'calibration explains weak foot tracking instead of repeating generic setup',
      () {
    final a = CalfRaiseAnalyzer();
    a.update(calfFrame(0, 0, confidence: .5), nowMicros: 0);
    final status = a.snapshot;
    expect(status.calibrationCue, contains('tracking is weak'));
    expect(status.calibrationProgress, 0);
  });
  test('initial calibration can recover onto the visible leg before any reps',
      () {
    final a = CalfRaiseAnalyzer();
    a.update(calfFrame(0, 0), nowMicros: 0);
    for (var t = 100000; t <= 1200000; t += 100000) {
      a.update(calfFrame(t, 0, side: CalfSide.right), nowMicros: t);
    }
    expect(a.snapshot.selectedSide, CalfSide.right);
    expect(a.snapshot.needsCalibration, false);
    expect(a.snapshot.repetitions, 0);
  });
  CalfRaiseAnalyzer calibrated({CalfSide side = CalfSide.left}) {
    final a = CalfRaiseAnalyzer();
    for (var t = 0; t <= 1000000; t += 100000) {
      a.update(calfFrame(t, 0, side: side), nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
    return a;
  }

  CalfRaiseUpdate cycle(CalfRaiseAnalyzer a, List<double> lifts,
      {CalfSide side = CalfSide.left,
      int start = 1150000,
      double toeShift = 0,
      bool bent = false}) {
    for (var i = 0; i < lifts.length; i++) {
      final t = start + i * 150000;
      a.update(
          calfFrame(t, lifts[i], side: side, toeShift: toeShift, bent: bent),
          nowMicros: t);
    }
    return a.snapshot;
  }

  for (final side in CalfSide.values) {
    test('${side.name} view counts a sustained heel raise and return once', () {
      final u = cycle(calibrated(side: side),
          [.02, .04, .07, .11, .11, .11, .07, .04, .01, 0, 0],
          side: side);
      expect(u.repetitions, 1);
      expect(u.partialRepetitions, 0);
      expect(u.selectedSide, side);
      expect(u.formScorePercent, 100);
    });
  }
  test('holds and standing jitter never create repetitions', () {
    final a = calibrated();
    cycle(a, [.001, .01, .02, .01, 0, .01, 0]);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('a small rise is partial and a single high spike cannot become full',
      () {
    for (final lifts in <List<double>>[
      [.02, .04, .06, .06, .04, .02, 0],
      [.02, .04, .06, .12, .06, .04, .02, 0]
    ]) {
      final u = cycle(calibrated(), lifts);
      expect(u.repetitions, 0);
      expect(u.partialRepetitions, 1);
    }
  });
  test('toe movement and knee bending invalidate an attempted repetition', () {
    for (final bent in [false, true]) {
      final a = calibrated();
      cycle(a, [.02, .04, .07, .11, .11, .11]);
      final u = cycle(a, [.07, .04, .01, 0],
          start: 2050000, toeShift: bent ? 0 : -.03, bent: bent);
      expect(u.repetitions, 0);
      expect(u.needsCalibration, true);
    }
  });
  test('tracking loss, pause, mirror and stale frames cannot bridge a cycle',
      () {
    for (final kind in ['loss', 'pause', 'mirror', 'stale', 'gap']) {
      final a = calibrated();
      cycle(a, [.02, .04, .07, .11, .11, .11]);
      if (kind == 'pause') a.pause();
      a.update(
          calfFrame(2050000, 0,
              confidence: kind == 'loss' ? .1 : .99,
              mirrored: kind == 'mirror'),
          nowMicros: kind == 'stale'
              ? 2400000
              : kind == 'gap'
                  ? 2500000
                  : 2050000);
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.needsCalibration, true);
    }
  });
  test('freshness tick invalidates a held peak', () {
    final a = calibrated();
    cycle(a, [.02, .04, .07, .11, .11, .11]);
    a.tick(nowMicros: 2400000);
    expect(a.snapshot.health, TrackingStatus.lost);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
  });
  test('after a measured rep, another leg cannot silently take over', () {
    final a = calibrated();
    cycle(a, [.02, .04, .07, .11, .11, .11, .07, .04, .01, 0, 0]);
    a.pause();
    for (var t = 3000000; t <= 4200000; t += 100000) {
      a.update(calfFrame(t, 0, side: CalfSide.right), nowMicros: t);
    }
    expect(a.snapshot.selectedSide, CalfSide.left);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 1);
  });
  test('setup feedback distinguishes front view, bent knees and hold progress',
      () {
    final front = calfFrame(0, 0);
    final heel = front.landmark(PoseLandmark.leftHeel)!;
    final points = {
      ...front.landmarks,
      PoseLandmark.leftFootIndex: PosePoint(
          x: heel.x + .002, y: heel.y, z: 0, visibility: .99, presence: .99)
    };
    final a = CalfRaiseAnalyzer();
    a.update(
        PoseFrame(
            capturedAtMicros: 0,
            detectorId: 'fixture',
            modelVersion: '1',
            imageWidth: 400,
            imageHeight: 800,
            landmarks: points),
        nowMicros: 0);
    expect(a.snapshot.calibrationCue, contains('side-on'));
    a.update(calfFrame(100000, 0, bent: true), nowMicros: 100000);
    expect(a.snapshot.calibrationCue, contains('knees'));
    for (var t = 200000; t <= 600000; t += 100000) {
      a.update(calfFrame(t, 0), nowMicros: t);
    }
    expect(a.snapshot.calibrationProgress, closeTo(.5, .001));
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
  });
  test('projected geometry remains stable across image aspect ratios', () {
    for (final size in [(400, 800), (800, 400)]) {
      final g = CalfRaiseGeometry.fromFrame(
          calfFrame(0, .1, width: size.$1, height: size.$2), CalfSide.left)!;
      expect(g.kneeAngleDegrees, closeTo(180, .001));
      expect(g.heelHeight / g.shinLength, closeTo(.1, .001));
    }
  });
}
