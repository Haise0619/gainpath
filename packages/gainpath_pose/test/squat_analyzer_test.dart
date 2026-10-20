import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';

// Analytic sagittal fixture, not recorded person data or uploadable activity.
PoseFrame sample(int time, double angle,
    {double lean = 0,
    bool missingKnee = false,
    double confidence = .95,
    int width = 640,
    int height = 720,
    bool mirrored = false}) {
  final radians = angle * math.pi / 180;
  final hx = 320 + 140 * math.sin(radians);
  final hy = 370 + 140 * math.cos(radians);
  PosePoint p(double x, double y) => PosePoint(
      x: x / width,
      y: y / height,
      z: 0,
      visibility: confidence,
      presence: confidence);
  return PoseFrame(
    capturedAtMicros: time,
    detectorId: 'fixture',
    modelVersion: 'analytic-v1',
    imageWidth: width,
    imageHeight: height,
    isMirrored: mirrored,
    posePresence: .95,
    landmarks: {
      PoseLandmark.leftShoulder: p(hx + 100 * math.sin(lean * math.pi / 180),
          hy - 100 * math.cos(lean * math.pi / 180)),
      PoseLandmark.leftHip: p(hx, hy),
      if (!missingKnee) PoseLandmark.leftKnee: p(320, 370),
      PoseLandmark.leftAnkle: p(320, 510),
      // Face points must never rescue a missing squat joint.
      PoseLandmark.nose: p(200, 100),
      PoseLandmark.leftEye: p(210, 100),
      PoseLandmark.rightEye: p(190, 100),
    },
  );
}

class Rig {
  final analyzer = SquatAnalyzer();
  int time = 0;
  SquatUpdate? last;
  SquatUpdate step(double angle,
      {bool missing = false,
      double confidence = .95,
      double lean = 0,
      int delta = 100000}) {
    time += delta;
    return last = analyzer.update(
        sample(time, angle,
            missingKnee: missing, confidence: confidence, lean: lean),
        nowMicros: time);
  }

  void hold(double angle, int count, {double lean = 0}) {
    for (var i = 0; i < count; i++) {
      step(angle, lean: lean);
    }
  }

  void calibrate() => hold(175, 12);
  void ramp(double from, double to, {double lean = 0}) {
    for (var i = 1; i <= 20; i++) {
      step(from + (to - from) * i / 20, lean: lean);
    }
  }

  void cycle({double bottom = 75, double lean = 0}) {
    ramp(175, bottom, lean: lean);
    hold(bottom, 8, lean: lean);
    ramp(bottom, 175, lean: lean);
    hold(175, 12);
  }
}

void main() {
  test('bounded standing jitter at irregular cadence cannot create attempts', () {
    final r = Rig()..calibrate();
    for (var i = 0; i < 180; i++) {
      final u = r.step(174 + 3 * math.sin(i * 1.7),
          delta: [33000, 67000, 100000][i % 3]);
      expect(u.repetitions, 0);
      expect(u.partialRepetitions, 0);
      expect(u.completedAttempt, isNull);
      expect(u.cues, isEmpty);
    }
    expect(r.last!.needsCalibration, false);
    expect(r.last!.formScorePercent, isNull);
  });
  test('geometry restores common XY units before computing knee angle', () {
    // Changing image aspect without changing physical pixel coordinates must
    // preserve the hand-defined 90 degree knee and 30 degree trunk angle.
    for (final size in [(640, 720), (1280, 720), (640, 1080)]) {
      final g = SquatGeometry.fromFrame(
          sample(1, 90, lean: 30, width: size.$1, height: size.$2),
          SquatSide.left);
      expect(g!.kneeAngleDegrees, closeTo(90, 1e-8));
      expect(g.trunkLeanDegrees, closeTo(30, 1e-8));
    }
  });
  test('degenerate segments and missing essential joints are unassessable', () {
    final f = sample(1, 90);
    final points = Map<PoseLandmark, PosePoint>.of(f.landmarks);
    points[PoseLandmark.leftHip] = points[PoseLandmark.leftKnee]!;
    expect(
        SquatGeometry.fromFrame(
            PoseFrame(
                capturedAtMicros: 1,
                detectorId: 'fixture',
                modelVersion: '1',
                imageWidth: 640,
                imageHeight: 720,
                landmarks: points),
            SquatSide.left),
        isNull);
    expect(
        SquatGeometry.fromFrame(
            sample(2, 90, missingKnee: true), SquatSide.left),
        isNull);
  });
  test('starting bent cannot calibrate or count a half rep', () {
    final r = Rig()..hold(75, 12);
    expect(r.last!.needsCalibration, true);
    expect(r.last!.formScorePercent, isNull);
    r.ramp(75, 175);
    r.hold(175, 12);
    expect(r.last!.needsCalibration, false);
    expect(r.last!.repetitions, 0);
  });
  test('a complete squat traverses four phases and counts once on standing',
      () {
    final r = Rig()..calibrate();
    expect(r.last!.selectedSide, SquatSide.left);
    expect(r.last!.needsCalibration, false);
    r.ramp(175, 75);
    r.hold(75, 8);
    expect(r.last!.phase, SquatPhase.inflection);
    expect(r.last!.repetitions, 0);
    r.ramp(75, 130);
    expect(r.last!.phase, SquatPhase.concentric);
    r.ramp(130, 175);
    r.hold(175, 12);
    expect(r.last!.repetitions, 1);
    expect(r.last!.partialRepetitions, 0);
    expect(r.last!.formScorePercent, 100);
    r.hold(175, 30);
    expect(r.last!.repetitions, 1);
  });
  test('early reversal records incomplete ROM without counting a full rep', () {
    final r = Rig()
      ..calibrate()
      ..cycle(bottom: 120);
    expect(r.last!.repetitions, 0);
    expect(r.last!.partialRepetitions, 1);
    expect(r.last!.formScorePercent, lessThan(100));
  });
  test('missing knee freezes progress even with visible face landmarks', () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 100);
    final phase = r.last!.phase;
    final goodTime = r.last!.trackedDurationMicros;
    final lost = r.step(80, missing: true);
    expect(lost.health, TrackingStatus.degraded);
    expect(lost.phase, phase);
    expect(lost.trackedDurationMicros, goodTime);
    expect(lost.rejectedDurationMicros, greaterThan(0));
    expect(lost.repetitions, 0);
  });
  test('sustained loss invalidates cycle and requires standing recalibration',
      () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75);
    for (var i = 0; i < 7; i++) {
      r.step(75, missing: true);
    }
    expect(r.last!.health, TrackingStatus.lost);
    expect(r.last!.needsCalibration, true);
    r.hold(175, 15);
    expect(r.last!.repetitions, 0);
    expect(r.last!.partialRepetitions, 0);
    expect(r.last!.needsCalibration, false);
  });
  test('short loss cannot bridge a hidden return to standing into a rep', () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75)
      ..hold(75, 8);
    r.step(75, missing: true);
    r.step(175);
    r.hold(175, 12);
    expect(r.last!.repetitions, 0);
  });
  test('recovery requires high confidence instead of the display threshold',
      () {
    final r = Rig()..calibrate();
    r.step(175, confidence: .6);
    expect(r.last!.health, TrackingStatus.degraded);
    for (var i = 0; i < 7; i++) {
      r.step(175, confidence: .6);
    }
    expect(r.last!.health, TrackingStatus.lost);
    expect(r.last!.needsCalibration, true);
    r.hold(175, 12);
    expect(r.last!.health, TrackingStatus.healthy);
  });
  test('gap is rejected time and cannot complete the active rep', () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75)
      ..hold(75, 8);
    final before = r.last!.trackedDurationMicros;
    r.step(175, delta: 1000000);
    expect(r.last!.trackedDurationMicros, before);
    expect(r.last!.rejectedDurationMicros, greaterThanOrEqualTo(1000000));
    expect(r.last!.needsCalibration, true);
    r.hold(175, 12);
    expect(r.last!.repetitions, 0);
  });
  test('stale and future inputs cannot enter calibration', () {
    final a = SquatAnalyzer();
    final stale = a.update(sample(100000, 175), nowMicros: 500000);
    expect(stale.health, isNot(TrackingStatus.healthy));
    expect(stale.needsCalibration, true);
    expect(() => a.update(sample(600000, 175), nowMicros: 550000),
        throwsArgumentError);
  });
  test('duplicate timestamps are rejected without incrementing metrics', () {
    final r = Rig()..calibrate();
    expect(() => r.analyzer.update(sample(r.time, 175), nowMicros: r.time),
        throwsArgumentError);
    expect(r.step(175).repetitions, 0);
  });
  test('pause discards cycle and excludes paused wall time', () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75);
    final before = r.last!.trackedDurationMicros;
    r.analyzer.pause();
    r.time += 10000000;
    r.step(175);
    r.analyzer.resume();
    r.step(175);
    expect(r.last!.trackedDurationMicros, before);
    r.hold(175, 12);
    expect(r.last!.repetitions, 0);
    expect(r.last!.rejectedDurationMicros, lessThan(10000000));
  });
  test('no-frame watchdog invalidates cycle without double accounting time',
      () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75);
    final before = r.last!.trackedDurationMicros;
    final t = r.time + 1000000;
    final u = r.analyzer.tick(nowMicros: t);
    expect(u.health, TrackingStatus.lost);
    expect(u.needsCalibration, true);
    final again = r.analyzer.tick(nowMicros: t);
    expect(again.rejectedDurationMicros, u.rejectedDurationMicros);
    expect(again.trackedDurationMicros, before);
  });
  test('sustained trunk deviation is scored once per attempt, not per frame',
      () {
    final r = Rig()
      ..calibrate()
      ..cycle(lean: 60);
    expect(r.last!.repetitions, 1);
    expect(r.last!.formScorePercent, inInclusiveRange(1, 99));
    final score = r.last!.formScorePercent;
    r.cycle(lean: 60);
    expect(r.last!.repetitions, 2);
    expect(r.last!.formScorePercent, closeTo(score!, .1));
  });
  test('score remains absent before an assessable attempt', () {
    final r = Rig()
      ..calibrate()
      ..hold(175, 40);
    expect(r.last!.formScorePercent, isNull);
    expect(r.last!.trackedDurationMicros, greaterThan(0));
  });
  test('invalid rule ordering fails before a session starts', () {
    expect(() => SquatRuleSet(readyAngleDegrees: 80, depthAngleDegrees: 90),
        throwsArgumentError);
  });
  test('right-side calibration works and does not switch sides mid attempt',
      () {
    final a = SquatAnalyzer();
    PoseFrame right(int t) {
      final f = sample(t, 175);
      final l = SquatGeometry.joints(SquatSide.left);
      final r = SquatGeometry.joints(SquatSide.right);
      return PoseFrame(
          capturedAtMicros: t,
          detectorId: f.detectorId,
          modelVersion: f.modelVersion,
          imageWidth: f.imageWidth,
          imageHeight: f.imageHeight,
          landmarks: {
            for (var i = 0; i < 4; i++) r[i]: f.landmarks[l[i]]!,
          });
    }

    SquatUpdate? u;
    for (var t = 100000; t <= 1000000; t += 100000) {
      u = a.update(right(t), nowMicros: t);
    }
    expect(u!.selectedSide, SquatSide.right);
    expect(u.needsCalibration, false);
    final changed = a.update(sample(1100000, 175), nowMicros: 1100000);
    expect(changed.selectedSide, SquatSide.right);
    expect(changed.health, TrackingStatus.degraded);
  });
  test('mirrored coordinates cannot silently enter the anatomical pipeline',
      () {
    final a = SquatAnalyzer();
    final u = a.update(sample(1, 175, mirrored: true), nowMicros: 1);
    expect(u.health, isNot(TrackingStatus.healthy));
    expect(u.geometry, isNull);
  });
  test('nonfinite and off-image joints never produce angles', () {
    for (final x in [double.nan, double.infinity, -0.01, 1.01]) {
      final f = sample(1, 90);
      final p = Map<PoseLandmark, PosePoint>.of(f.landmarks);
      p[PoseLandmark.leftKnee] =
          PosePoint(x: x, y: .5, z: 0, visibility: .95, presence: .95);
      final invalid = PoseFrame(
          capturedAtMicros: 1,
          detectorId: 'fixture',
          modelVersion: '1',
          imageWidth: 640,
          imageHeight: 720,
          landmarks: p);
      expect(SquatGeometry.fromFrame(invalid, SquatSide.left), isNull);
    }
  });
  test('image geometry change invalidates an in-progress squat', () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75)
      ..hold(75, 8);
    r.time += 100000;
    final u =
        r.analyzer.update(sample(r.time, 175, height: 1080), nowMicros: r.time);
    expect(u.needsCalibration, true);
    expect(u.repetitions, 0);
    expect(u.phase, SquatPhase.ready);
  });
  test('brief stable occlusion can resume without spurious velocity', () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75)
      ..hold(75, 8);
    r.step(75, missing: true);
    final recovered = r.step(75);
    expect(recovered.angularVelocityDegreesPerSecond, isNull);
    expect(recovered.needsCalibration, false);
    r.ramp(75, 175);
    r.hold(175, 12);
    expect(r.last!.repetitions, 1);
  });
  test('a stalled cycle expires rather than counting an unrelated ascent', () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75)
      ..hold(75, 115);
    expect(r.last!.needsCalibration, true);
    r.ramp(75, 175);
    r.hold(175, 12);
    expect(r.last!.repetitions, 0);
  });
  test('reversal before reaching standing cannot double count', () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75)
      ..hold(75, 8);
    r.ramp(75, 125);
    r.ramp(125, 75);
    r.hold(75, 8);
    r.ramp(75, 175);
    r.hold(175, 12);
    // This long fixture exceeds the maximum cycle duration; it must not count.
    expect(r.last!.repetitions, lessThanOrEqualTo(1));
    expect(r.last!.partialRepetitions, 0);
  });
  test('watchdog recovery never scores the elapsed camera stall', () {
    final r = Rig()..calibrate();
    final tracked = r.last!.trackedDurationMicros;
    r.analyzer.tick(nowMicros: r.time + 1000000);
    r.time += 1000000;
    r.step(175);
    expect(r.last!.trackedDurationMicros, tracked);
    expect(r.last!.rejectedDurationMicros, greaterThanOrEqualTo(1000000));
    expect(r.last!.needsCalibration, true);
  });
  test('reset clears all session aggregates and requires a new calibration',
      () {
    final r = Rig()
      ..calibrate()
      ..cycle();
    expect(r.last!.repetitions, 1);
    r.analyzer.reset();
    final u = r.analyzer.update(sample(1, 175), nowMicros: 1);
    expect(u.repetitions, 0);
    expect(u.trackedDurationMicros, 0);
    expect(u.rejectedDurationMicros, 0);
    expect(u.formScorePercent, isNull);
    expect(u.needsCalibration, true);
  });
  test('recovery crossing the loss timeout still invalidates the old cycle',
      () {
    final r = Rig()
      ..calibrate()
      ..ramp(175, 75)
      ..hold(75, 8);
    for (var i = 0; i < 3; i++) {
      r.step(75, missing: true, delta: 200000);
    }
    final recovered = r.step(75, delta: 200000);
    expect(recovered.needsCalibration, true);
    r.ramp(75, 175);
    r.hold(175, 12);
    expect(r.last!.repetitions, 0);
  });
  test('automatic calibration selects valid geometry over a collapsed side',
      () {
    final a = SquatAnalyzer();
    SquatUpdate? u;
    for (var t = 100000; t <= 1000000; t += 100000) {
      final f = sample(t, 175);
      final l = SquatGeometry.joints(SquatSide.left);
      final r = SquatGeometry.joints(SquatSide.right);
      final p = Map<PoseLandmark, PosePoint>.of(f.landmarks);
      for (var i = 0; i < 4; i++) {
        p[r[i]] = p[l[i]]!;
      }
      p[PoseLandmark.leftHip] = p[PoseLandmark.leftKnee]!;
      u = a.update(
          PoseFrame(
              capturedAtMicros: t,
              detectorId: f.detectorId,
              modelVersion: f.modelVersion,
              imageWidth: 640,
              imageHeight: 720,
              landmarks: p),
          nowMicros: t);
    }
    expect(u!.selectedSide, SquatSide.right);
    expect(u.needsCalibration, false);
  });
}
