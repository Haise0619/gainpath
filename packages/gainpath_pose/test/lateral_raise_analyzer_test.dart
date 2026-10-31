import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'support/lateral_raise_trajectory.dart';
import 'support/shoulder_press_trajectory.dart';

void feed(LateralRaiseAnalyzer a, Iterable<PoseFrame> frames) {
  for (final f in frames) {
    a.update(f, nowMicros: f.capturedAtMicros);
  }
}

LateralRaiseAnalyzer calibrated() {
  final a = LateralRaiseAnalyzer();
  feed(a, lateralRaiseTrajectory().take(18));
  expect(a.snapshot.needsCalibration, false);
  return a;
}

void main() {
  test('exact identity and projected geometry has no score authority', () {
    expect(LateralRaiseAnalyzer.version, 'standing-lateral-raise-front-v1');
    final neutral = LateralRaiseGeometry.fromFrame(lateralRaiseFrame(0, 0))!;
    final peak = LateralRaiseGeometry.fromFrame(lateralRaiseFrame(50000, 1))!;
    expect(neutral.neutral, true);
    expect(peak.neutral, false);
    expect(peak.raised, true);
    expect(peak.symmetric, true);
    expect(peak.angles, everyElement(closeTo(90, .001)));
    expect(LateralRaiseAnalyzer().snapshot.formScorePercent, isNull);
  });
  for (final scale in [1.0, .46, .32, .24]) {
    for (final step in [16667, 50000, 125000]) {
      for (final size in [(400, 800), (800, 400)]) {
        test('full bilateral scale=$scale cadence=$step size=$size counts once',
            () {
          final a = LateralRaiseAnalyzer();
          feed(
              a,
              lateralRaiseTrajectory(
                      stepMicros: step, width: size.$1, height: size.$2)
                  .map((f) => transformLateralFrame(f, scale: scale)));
          expect(a.snapshot.repetitions, 1);
          expect(a.snapshot.partialRepetitions, 0);
          expect(a.snapshot.needsCalibration, false);
          expect(a.snapshot.phase, LateralRaisePhase.ready);
          expect(a.snapshot.formScorePercent, isNull);
          expect(a.snapshot.trackedDurationMicros, greaterThan(1000000));
        });
      }
    }
  }
  for (final bend in [0.0, 20.0, 30.0]) {
    test('slight elbow bend $bend remains a lateral raise', () {
      final a = LateralRaiseAnalyzer();
      feed(a, lateralRaiseTrajectory(bendDegrees: bend));
      expect(a.snapshot.repetitions, 1);
    });
  }
  test('two returned cycles count twice and a held peak never counts', () {
    final a = LateralRaiseAnalyzer();
    feed(a, lateralRaiseTrajectory());
    feed(a, lateralRaiseTrajectory(startMicros: 3650000));
    expect(a.snapshot.repetitions, 2);
    final b = LateralRaiseAnalyzer();
    feed(b,
        lateralRaiseTrajectory().where((f) => f.capturedAtMicros <= 2200000));
    for (var t = 2250000; t < 5000000; t += 50000) {
      b.update(lateralRaiseFrame(t, 1), nowMicros: t);
    }
    expect(b.snapshot.repetitions, 0);
  });
  test('static jitter and isolated peak cannot start or complete an attempt',
      () {
    final a = calibrated();
    for (var t = 900000; t <= 3000000; t += 50000) {
      a.update(
          lateralRaiseFrame(t, t == 1500000 ? 1 : .02,
              jitter: (t ~/ 50000).isEven ? .001 : -.001),
          nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('shallow bilateral cycle records a partial without full rep', () {
    final a = LateralRaiseAnalyzer();
    feed(a, lateralRaiseTrajectory(amplitude: .55));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 1);
  });
  for (final alternating in [false, true]) {
    test('unilateral and alternating=$alternating cannot count', () {
      final a = LateralRaiseAnalyzer();
      feed(
          a,
          lateralRaiseTrajectory(
              unilateral: !alternating, alternating: alternating));
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  test('overhead press and curl-shaped elbows cannot count', () {
    final a = LateralRaiseAnalyzer();
    feed(a, shoulderPressTrajectory());
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
    final b = LateralRaiseAnalyzer();
    feed(b, lateralRaiseTrajectory(bendDegrees: 85));
    expect(b.snapshot.repetitions, 0);
  });
  test('front projection collapse invalidates the attempt', () {
    final a = calibrated();
    for (var t = 900000; t <= 2200000; t += 50000) {
      a.update(lateralRaiseFrame(t, 1, projection: .62), nowMicros: t);
    }
    feed(a, lateralRaiseTrajectory(startMicros: 2250000).take(18));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  for (final id in LateralRaiseGeometry.joints) {
    test('missing or weak $id cannot calibrate', () {
      for (final missing in [true, false]) {
        final a = LateralRaiseAnalyzer();
        feed(
            a,
            lateralRaiseTrajectory().map((f) {
              final joints = Map.of(f.landmarks);
              final p = joints[id]!;
              if (missing) {
                joints.remove(id);
              } else {
                joints[id] = PosePoint(x: p.x, y: p.y, z: p.z, visibility: .4);
              }
              return transformLateralFrame(f, landmarks: joints);
            }));
        expect(a.snapshot.needsCalibration, true);
        expect(a.snapshot.repetitions, 0);
        expect(a.snapshot.trackedDurationMicros, 0);
      }
    });
  }
  test('tiny resolution gives actionable cue', () {
    final a = LateralRaiseAnalyzer();
    feed(
        a,
        lateralRaiseTrajectory()
            .map((f) => transformLateralFrame(f, scale: .06)));
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.calibrationCue, contains('Move closer'));
  });
  test('moving neutral and side view never calibrate', () {
    for (final moving in [false, true]) {
      final a = LateralRaiseAnalyzer();
      for (var t = 0; t < 2000000; t += 50000) {
        a.update(
            lateralRaiseFrame(t, 0,
                shoulderWidth: moving ? .12 : .025,
                shoulderShift: moving && (t ~/ 50000).isEven ? .04 : 0),
            nowMicros: t);
      }
      expect(a.snapshot.needsCalibration, true);
    }
  });
  for (final interruption in [
    'pause',
    'gap',
    'stale',
    'duplicate',
    'lost',
    'sway',
    'geometry',
    'model'
  ]) {
    test('$interruption discards peak and requires observed new start', () {
      final a = LateralRaiseAnalyzer();
      feed(a,
          lateralRaiseTrajectory().where((f) => f.capturedAtMicros <= 2200000));
      switch (interruption) {
        case 'pause':
          a.pause();
        case 'gap':
          a.tick(nowMicros: 2700000);
        case 'stale':
          a.update(lateralRaiseFrame(2250000, 1), nowMicros: 2600000);
        case 'duplicate':
          a.update(lateralRaiseFrame(2200000, 1), nowMicros: 2250000);
        case 'lost':
          a.update(lateralRaiseFrame(2250000, 1, confidence: .1),
              nowMicros: 2250000);
        case 'sway':
          a.update(lateralRaiseFrame(2250000, 1, hipShift: .10),
              nowMicros: 2250000);
        case 'geometry':
          a.update(lateralRaiseFrame(2250000, 1, width: 800, height: 400),
              nowMicros: 2250000);
        case 'model':
          a.update(lateralRaiseFrame(2250000, 1, modelVersion: '2'),
              nowMicros: 2250000);
      }
      feed(a, lateralRaiseTrajectory(startMicros: 2800000).take(18));
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  test('brief loss discards full cycle then neutral hold rearms clean rep', () {
    final a = LateralRaiseAnalyzer();
    feed(a,
        lateralRaiseTrajectory().where((f) => f.capturedAtMicros <= 2200000));
    a.update(lateralRaiseFrame(2250000, 1, confidence: .1), nowMicros: 2250000);
    expect(a.snapshot.requiresBottomReset, true);
    for (var t = 2300000; t <= 2600000; t += 50000) {
      a.update(lateralRaiseFrame(t, 1), nowMicros: t);
    }
    expect(a.snapshot.requiresBottomReset, true);
    feed(a, lateralRaiseTrajectory(startMicros: 2650000));
    expect(a.snapshot.repetitions, 1);
    expect(a.snapshot.requiresBottomReset, false);
  });
  test('tick without camera never calibrates or fabricates repetitions', () {
    final a = calibrated();
    for (var t = 900000; t < 3000000; t += 50000) {
      a.tick(nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.rejectedDurationMicros, greaterThan(0));
  });
  for (final step in [16667, 50000, 125000]) {
    test('bounded camera jitter throughout the cycle counts at $step', () {
      final a = LateralRaiseAnalyzer();
      feed(
          a,
          lateralRaiseTrajectory(stepMicros: step).map((f) {
            final jitter = (f.capturedAtMicros ~/ step).isEven ? .001 : -.001;
            return transformLateralFrame(f,
                landmarks: f.landmarks.map((id, p) => MapEntry(
                    id,
                    PosePoint(
                        x: p.x + jitter,
                        y: p.y - jitter,
                        z: p.z,
                        visibility: p.visibility,
                        presence: p.presence))));
          }));
      expect(a.snapshot.repetitions, 1);
      expect(a.snapshot.needsCalibration, false);
    });
  }
  test('brief raw peak during an established shallow attempt stays partial',
      () {
    final a = LateralRaiseAnalyzer();
    feed(
        a,
        lateralRaiseTrajectory(amplitude: .7).map((f) =>
            f.capturedAtMicros == 1950000 ? lateralRaiseFrame(1950000, 1) : f));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 1);
  });
  test('one down frame cannot bridge a held peak into a counted return', () {
    final a = LateralRaiseAnalyzer();
    feed(a,
        lateralRaiseTrajectory().where((f) => f.capturedAtMicros <= 2200000));
    a.update(lateralRaiseFrame(2250000, 0), nowMicros: 2250000);
    for (var t = 2300000; t <= 2600000; t += 50000) {
      a.update(lateralRaiseFrame(t, 1), nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
  });
  test('forearm bending after calibration discards peak even if hands return',
      () {
    final a = LateralRaiseAnalyzer();
    feed(a,
        lateralRaiseTrajectory().where((f) => f.capturedAtMicros <= 2200000));
    a.update(lateralRaiseFrame(2250000, .8, bendDegrees: 80),
        nowMicros: 2250000);
    feed(a,
        lateralRaiseTrajectory().where((f) => f.capturedAtMicros >= 2300000));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  test('overhead excursion after a lateral peak discards the attempt', () {
    final a = LateralRaiseAnalyzer();
    feed(a,
        lateralRaiseTrajectory().where((f) => f.capturedAtMicros <= 2200000));
    a.update(lateralRaiseFrame(2250000, 1.5), nowMicros: 2250000);
    feed(a,
        lateralRaiseTrajectory().where((f) => f.capturedAtMicros >= 2300000));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  for (final kind in [
    'mirror',
    'nan',
    'clipped',
    'presence',
    'posePresence',
    'resolution'
  ]) {
    test('$kind geometry fails closed before readiness', () {
      final a = LateralRaiseAnalyzer();
      feed(
          a,
          lateralRaiseTrajectory().map((f) {
            final joints = Map.of(f.landmarks);
            final p = joints[PoseLandmark.rightWrist]!;
            joints[PoseLandmark.rightWrist] = PosePoint(
                x: kind == 'nan'
                    ? double.nan
                    : kind == 'clipped'
                        ? 1.1
                        : p.x,
                y: p.y,
                z: p.z,
                visibility: p.visibility,
                presence: kind == 'presence' ? .4 : p.presence);
            return PoseFrame(
                capturedAtMicros: f.capturedAtMicros,
                detectorId: f.detectorId,
                modelVersion: f.modelVersion,
                imageWidth: f.imageWidth,
                imageHeight: kind == 'resolution' ? 0 : f.imageHeight,
                isMirrored: kind == 'mirror',
                posePresence: kind == 'posePresence' ? .4 : 1,
                landmarks: joints);
          }));
      expect(a.snapshot.needsCalibration, true);
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.trackedDurationMicros, 0);
    });
  }
  test('future capture and backwards clock invalidate calibration', () {
    final a = calibrated();
    a.update(lateralRaiseFrame(1000000, 1), nowMicros: 950000);
    expect(a.snapshot.needsCalibration, true);
    a.update(lateralRaiseFrame(500000, 0), nowMicros: 700000);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.repetitions, 0);
  });
  for (final size in [(400, 800), (800, 400)]) {
    test('naturally inward resting arms calibrate and count in $size', () {
      final a = LateralRaiseAnalyzer();
      final neutral =
          lateralRaiseFrame(0, -16 / 82, width: size.$1, height: size.$2);
      expect(LateralRaiseGeometry.fromFrame(neutral)?.neutral, true);
      feed(
          a,
          lateralRaiseTrajectory(width: size.$1, height: size.$2).map((f) {
            final t = f.capturedAtMicros;
            final motion = t < 900000
                ? 0.0
                : t < 1750000
                    ? (t - 900000) / 850000
                    : t < 2200000
                        ? 1.0
                        : t < 3050000
                            ? 1 - (t - 2200000) / 850000
                            : 0.0;
            return lateralRaiseFrame(t, (-16 + 98 * motion) / 82,
                width: size.$1, height: size.$2);
          }));
      expect(a.snapshot.repetitions, 1);
      expect(a.snapshot.needsCalibration, false);
    });
  }
  test('active inward cross-body arms remain rejected', () {
    final a = calibrated();
    for (var t = 900000; t <= 2200000; t += 50000) {
      a.update(lateralRaiseFrame(t, -65 / 82), nowMicros: t);
    }
    feed(a, lateralRaiseTrajectory(startMicros: 2250000).take(18));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
}
