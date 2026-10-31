import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'support/shoulder_press_trajectory.dart';

void feed(ShoulderPressAnalyzer a, Iterable<PoseFrame> frames) {
  for (final f in frames) {
    a.update(f, nowMicros: f.capturedAtMicros);
  }
}

ShoulderPressAnalyzer calibrated() {
  final a = ShoulderPressAnalyzer();
  for (var t = 0; t <= 800000; t += 50000) {
    a.update(shoulderPressFrame(t, 0), nowMicros: t);
  }
  expect(a.snapshot.needsCalibration, false);
  return a;
}

PoseFrame replace(PoseFrame f, Map<PoseLandmark, PosePoint> joints,
        {bool mirrored = false}) =>
    PoseFrame(
        capturedAtMicros: f.capturedAtMicros,
        detectorId: f.detectorId,
        modelVersion: f.modelVersion,
        imageWidth: f.imageWidth,
        imageHeight: f.imageHeight,
        isMirrored: mirrored,
        landmarks: joints);

void main() {
  PoseFrame scaled(PoseFrame f, double scale) => PoseFrame(
      capturedAtMicros: f.capturedAtMicros,
      detectorId: f.detectorId,
      modelVersion: f.modelVersion,
      imageWidth: f.imageWidth,
      imageHeight: f.imageHeight,
      landmarks: f.landmarks.map((id, p) => MapEntry(
          id,
          PosePoint(
              x: .5 + (p.x - .5) * scale,
              y: .5 + (p.y - .5) * scale,
              z: p.z,
              visibility: p.visibility,
              presence: p.presence))));
  for (final scale in [.46, .40, .32, .24]) {
    for (final step in [16667, 50000, 125000]) {
      test(
          'smaller visible body scale=$scale at $step counts without the old 12 percent cutoff',
          () {
        final a = ShoulderPressAnalyzer();
        feed(
            a,
            shoulderPressTrajectory(stepMicros: step)
                .map((f) => scaled(f, scale)));
        expect(a.snapshot.repetitions, 1);
        expect(a.snapshot.needsCalibration, false);
        expect(a.snapshot.formScorePercent, isNull);
      });
    }
  }
  test('tiny body reports move closer rather than missing visible joints', () {
    final a = ShoulderPressAnalyzer();
    feed(a, shoulderPressTrajectory().map((f) => scaled(f, .06)));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.needsCalibration, true);
    expect(a.snapshot.calibrationCue, contains('Move closer'));
  });
  test('insufficient pixel resolution cannot be rescued by normalized scale',
      () {
    final a = ShoulderPressAnalyzer();
    feed(
        a,
        shoulderPressTrajectory(width: 400, height: 160)
            .map((f) => scaled(f, .46)));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.calibrationCue, contains('Move closer'));
  });
  test(
      'low confidence names the obscured joint and delayed frames report delay',
      () {
    final a = ShoulderPressAnalyzer();
    final f = shoulderPressFrame(50000, 0), joints = Map.of(f.landmarks);
    final p = joints[PoseLandmark.leftHip]!;
    joints[PoseLandmark.leftHip] =
        PosePoint(x: p.x, y: p.y, z: p.z, visibility: .4);
    a.update(replace(f, joints), nowMicros: 50000);
    expect(a.snapshot.calibrationCue, contains('left hip'));
    a.update(shoulderPressFrame(100000, 0), nowMicros: 400000);
    expect(a.snapshot.calibrationCue, contains('delayed'));
  });
  test(
      'scale fix does not count unilateral movement or bridge small-body tracking loss',
      () {
    final a = ShoulderPressAnalyzer();
    feed(
        a, shoulderPressTrajectory(unilateral: true).map((f) => scaled(f, .4)));
    expect(a.snapshot.repetitions, 0);
    final b = ShoulderPressAnalyzer();
    feed(
        b,
        shoulderPressTrajectory()
            .where((f) => f.capturedAtMicros <= 2100000)
            .map((f) => scaled(f, .4)));
    b.pause();
    feed(
        b,
        shoulderPressTrajectory(startMicros: 2200000)
            .take(18)
            .map((f) => scaled(f, .4)));
    expect(b.snapshot.repetitions, 0);
  });
  for (final step in [16667, 50000, 125000]) {
    for (final size in [(400, 800), (800, 400)]) {
      test('bilateral cycle at $step us and $size counts once without a score',
          () {
        final a = ShoulderPressAnalyzer();
        feed(
            a,
            shoulderPressTrajectory(
                stepMicros: step, width: size.$1, height: size.$2));
        expect(a.snapshot.repetitions, 1);
        expect(a.snapshot.partialRepetitions, 0);
        expect(a.snapshot.formScorePercent, isNull);
        expect(a.snapshot.phase, ShoulderPressPhase.ready);
        expect(a.snapshot.trackedDurationMicros, greaterThan(1000000));
      });
    }
  }
  test('two returned cycles count twice, holding overhead never counts', () {
    final a = ShoulderPressAnalyzer();
    feed(a, shoulderPressTrajectory());
    feed(a, shoulderPressTrajectory(startMicros: 3450000));
    expect(a.snapshot.repetitions, 2);
    final b = ShoulderPressAnalyzer();
    feed(b,
        shoulderPressTrajectory().where((f) => f.capturedAtMicros <= 2100000));
    expect(b.snapshot.repetitions, 0);
  });
  for (final alternating in [false, true]) {
    test('unilateral/alternating=$alternating motion cannot count', () {
      final a = ShoulderPressAnalyzer();
      feed(
          a,
          shoulderPressTrajectory(
              unilateral: !alternating, alternating: alternating));
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  test('bilateral shallow attempt is partial, never a complete repetition', () {
    final a = ShoulderPressAnalyzer();
    feed(a, shoulderPressTrajectory(amplitude: .55));
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 1);
  });
  test('static jitter and a single overhead spike do not count', () {
    final a = calibrated();
    for (var t = 850000; t <= 3000000; t += 50000) {
      a.update(
          shoulderPressFrame(t, t == 1500000 ? 1 : .02,
              jitter: (t ~/ 50000).isEven ? .001 : -.001),
          nowMicros: t);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
  });
  for (final id in [
    PoseLandmark.leftShoulder,
    PoseLandmark.rightShoulder,
    PoseLandmark.leftElbow,
    PoseLandmark.rightElbow,
    PoseLandmark.leftWrist,
    PoseLandmark.rightWrist,
    PoseLandmark.leftHip,
    PoseLandmark.rightHip
  ]) {
    test('missing $id never calibrates', () {
      final a = ShoulderPressAnalyzer();
      feed(
          a,
          shoulderPressTrajectory()
              .map((f) => replace(f, Map.of(f.landmarks)..remove(id))));
      expect(a.snapshot.needsCalibration, true);
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.trackedDurationMicros, 0);
    });
  }
  test(
      'poor confidence, mirrored coordinates and nonfinite/clipped wrist rejected',
      () {
    for (final kind in ['weak', 'mirror', 'nan', 'clipped']) {
      final a = ShoulderPressAnalyzer();
      feed(
          a,
          shoulderPressTrajectory().map((f) {
            final joints = Map.of(f.landmarks);
            if (kind != 'mirror') {
              final p = joints[PoseLandmark.rightWrist]!;
              joints[PoseLandmark.rightWrist] = PosePoint(
                  x: kind == 'nan'
                      ? double.nan
                      : kind == 'clipped'
                          ? 1.1
                          : p.x,
                  y: p.y,
                  z: p.z,
                  visibility: kind == 'weak' ? .4 : .99);
            }
            return replace(f, joints, mirrored: kind == 'mirror');
          }));
      expect(a.snapshot.needsCalibration, true, reason: kind);
      expect(a.snapshot.repetitions, 0, reason: kind);
    }
  });
  test('side-on or moving calibration cannot arm a press', () {
    for (final moving in [false, true]) {
      final a = ShoulderPressAnalyzer();
      for (var t = 0; t < 2000000; t += 50000) {
        a.update(
            shoulderPressFrame(t, 0,
                shoulderWidth: moving ? .15 : .025,
                shoulderShift: moving && (t ~/ 50000).isEven ? .04 : 0),
            nowMicros: t);
      }
      expect(a.snapshot.needsCalibration, true);
      expect(a.snapshot.repetitions, 0);
    }
  });
  for (final interruption in [
    'pause',
    'gap',
    'stale',
    'duplicate',
    'lost',
    'tilt',
    'geometry'
  ]) {
    test('$interruption breaks an overhead attempt without bridging a return',
        () {
      final a = ShoulderPressAnalyzer();
      feed(
          a,
          shoulderPressTrajectory()
              .where((f) => f.capturedAtMicros <= 2100000));
      switch (interruption) {
        case 'pause':
          a.pause();
        case 'gap':
          a.tick(nowMicros: 2600000);
        case 'stale':
          a.update(shoulderPressFrame(2150000, 1), nowMicros: 2500000);
        case 'duplicate':
          a.update(shoulderPressFrame(2100000, 1), nowMicros: 2150000);
        case 'lost':
          a.update(shoulderPressFrame(2150000, 1, confidence: .1),
              nowMicros: 2150000);
        case 'tilt':
          a.update(shoulderPressFrame(2150000, 1, torsoTilt: .12),
              nowMicros: 2150000);
        case 'geometry':
          a.update(shoulderPressFrame(2150000, 1, width: 800, height: 400),
              nowMicros: 2150000);
      }
      feed(a, shoulderPressTrajectory(startMicros: 2700000).take(18));
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 0);
    });
  }
  test('future and backwards capture times fail closed', () {
    final a = calibrated();
    a.update(shoulderPressFrame(950000, 1), nowMicros: 900000);
    expect(a.snapshot.needsCalibration, true);
    a.update(shoulderPressFrame(400000, 0), nowMicros: 850000);
    expect(a.snapshot.repetitions, 0);
  });
}
