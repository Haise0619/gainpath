import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/floor_push_up_trajectory.dart';

PoseFrame change(PoseFrame f,
        {Map<PoseLandmark, PosePoint>? landmarks,
        Map<PoseLandmark, PosePoint>? world,
        bool? mirrored}) =>
    PoseFrame(
        capturedAtMicros: f.capturedAtMicros,
        detectorId: f.detectorId,
        modelVersion: f.modelVersion,
        imageWidth: f.imageWidth,
        imageHeight: f.imageHeight,
        posePresence: f.posePresence,
        landmarks: landmarks ?? f.landmarks,
        worldLandmarks: world ?? f.worldLandmarks,
        isMirrored: mirrored ?? f.isMirrored);

void main() {
  test('manual reset never advertises Ready before fresh TOP acquisition', () {
    final r = FloorReplay()..hold(170, 700);
    r.analyzer.pause();
    expect(r.analyzer.snapshot.needsCalibration, true);
    expect(r.analyzer.snapshot.rejection, FloorPushUpRejection.waitingTop);
  });
  test('unusable high-confidence candidate can be replaced before TOP', () {
    final a = FloorPushUpAnalyzer();
    void sample(int t, {bool badLeft = false}) {
      final left = floorFrame(t, 170),
          right =
              floorFrame(t, 170, right: true, visibility: badLeft ? .99 : .7);
      final points = {...left.landmarks, ...right.landmarks};
      if (badLeft) {
        points[PoseLandmark.leftElbow] = const PosePoint(
            x: .9, y: .55, z: 0, visibility: .99, presence: .99);
      }
      a.update(change(left, landmarks: points), nowMicros: t);
    }

    sample(50000);
    expect(a.snapshot.selectedSide, FloorPushUpSide.left);
    for (var t = 100000; t <= 550000; t += 50000) {
      sample(t, badLeft: true);
    }
    expect(a.snapshot.selectedSide, FloorPushUpSide.right);
    expect(a.snapshot.phase, FloorPushUpPhase.top);
  });
  test('watchdog preserves a current no-pose rejection instead of masking it',
      () {
    final a = FloorPushUpAnalyzer();
    for (var t = 50000; t <= 1000000; t += 50000) {
      a.update(change(floorFrame(t, 170), landmarks: {}), nowMicros: t);
      a.tick(nowMicros: t + 10000);
      expect(a.snapshot.rejection, FloorPushUpRejection.noPose);
    }
  });
  test('fresh results at 150ms cadence and 200ms latency can acquire TOP', () {
    final a = FloorPushUpAnalyzer();
    for (var t = 50000; t <= 650000; t += 150000) {
      a.update(floorFrame(t, 170), nowMicros: t + 200000);
      a.tick(nowMicros: t + 300000);
    }
    expect(a.snapshot.phase, FloorPushUpPhase.top);
    expect(a.snapshot.health, TrackingStatus.healthy);
    a.tick(nowMicros: 1100001);
    expect(a.snapshot.health, TrackingStatus.lost);
  });
  test('an early side candidate cannot lock the hidden arm before TOP', () {
    final a = FloorPushUpAnalyzer();
    void sample(int t, double leftConfidence, double rightConfidence) {
      final left = floorFrame(t, 170, visibility: leftConfidence);
      final right =
          floorFrame(t, 170, right: true, visibility: rightConfidence);
      final points = {...left.landmarks, ...right.landmarks};
      a.update(change(left, landmarks: points), nowMicros: t);
    }

    sample(50000, .99, .7);
    expect(a.snapshot.selectedSide, FloorPushUpSide.left);
    for (var t = 100000; t <= 550000; t += 50000) {
      sample(t, .1, .99);
    }
    expect(a.snapshot.selectedSide, FloorPushUpSide.right);
    expect(a.snapshot.phase, FloorPushUpPhase.top);
  });
  test(
      'accepted TOP clears the camera warning; unsupported mirrored input stays rejected',
      () {
    final r = FloorReplay()..hold(170, 700);
    expect(r.analyzer.snapshot.rejection, FloorPushUpRejection.none);
    expect(r.analyzer.snapshot.calibrationCue, 'Ready — start your push-ups.');
    r.t += 50000;
    r.analyzer
        .update(change(floorFrame(r.t, 170), mirrored: true), nowMicros: r.t);
    expect(r.analyzer.snapshot.rejection, FloorPushUpRejection.mirroredInput);
    expect(r.analyzer.snapshot.needsCalibration, true);
  });
  test(
      'diagnostics distinguish empty pose, low elbow confidence and waiting TOP',
      () {
    final a = FloorPushUpAnalyzer();
    final first = floorFrame(50000, 170);
    a.update(change(first, landmarks: {}), nowMicros: 50000);
    expect(a.snapshot.rejection, FloorPushUpRejection.noPose);
    a.update(floorFrame(100000, 170, visibility: .60), nowMicros: 100000);
    expect(a.snapshot.rejection, FloorPushUpRejection.lowLandmarkConfidence);
    expect((a.diagnostics['landmarkConfidence'] as Map)['leftElbow'],
        {'visibility': .60, 'presence': .60});
    a.update(floorFrame(150000, 130), nowMicros: 150000);
    expect(a.snapshot.rejection, FloorPushUpRejection.waitingTop);
  });
  for (final right in [false, true]) {
    test('stable side=$right TOP survives one 50ms confidence dropout', () {
      final r = FloorReplay(right: right)..hold(170, 700);
      r.hold(170, 50, visibility: .60);
      r.hold(170, 100);
      expect(r.analyzer.snapshot.phase, FloorPushUpPhase.top);
      expect(r.analyzer.snapshot.health, TrackingStatus.healthy);
      r.cycle();
      expect(r.analyzer.snapshot.repetitions, 1);
    });
    test(
        'initial TOP acquisition tolerates one brief invalid observation side=$right',
        () {
      final r = FloorReplay(right: right)..hold(170, 200);
      r.hold(170, 50, visibility: .60);
      r.hold(170, 200);
      expect(r.analyzer.snapshot.phase, FloorPushUpPhase.top);
    });
  }
  test(
      'unreliable optional world data allows measured 2D counting, no form score',
      () {
    final r = FloorReplay();
    void sample(double angle, int n) {
      for (var i = 0; i < n; i++) {
        r.t += 50000;
        final f = floorFrame(r.t, angle, world: true);
        final world = Map<PoseLandmark, PosePoint>.of(f.worldLandmarks)
          ..remove(PoseLandmark.leftElbow);
        r.analyzer.update(change(f, world: world), nowMicros: r.t);
      }
    }

    sample(170, 14);
    for (final a in [
      150.0,
      130.0,
      110.0,
      90.0,
      90.0,
      90.0,
      110.0,
      130.0,
      150.0,
      170.0,
      170.0
    ]) {
      sample(a, 4);
    }
    expect(r.analyzer.snapshot.repetitions, 1);
    expect(r.analyzer.snapshot.formScorePercent, isNull);
  });
  test('a dropout cannot bridge an unobserved bottom or extension', () {
    final r = FloorReplay()
      ..hold(170, 700)
      ..hold(130, 400);
    r.hold(90, 50, visibility: .1);
    r.hold(170, 600);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 1);
  });
  test('brief missing bottom frames preserve only a still-observed bottom', () {
    final r = FloorReplay()
      ..hold(170, 700)
      ..hold(130, 400)
      ..hold(90, 400);
    r.hold(90, 50, visibility: .1);
    r.hold(90, 200);
    expect(r.analyzer.snapshot.phase, FloorPushUpPhase.bottom);
    r.hold(120, 300);
    r.hold(170, 500);
    expect(r.analyzer.snapshot.repetitions, 1);
    expect(r.analyzer.snapshot.formScorePercent, isNull);
  });
  test('long loss during bottom invalidates credit and demands fresh top', () {
    final r = FloorReplay()
      ..hold(170, 700)
      ..hold(130, 400)
      ..hold(90, 400);
    r.hold(90, 400, visibility: .1);
    r.hold(170, 700);
    expect(r.analyzer.snapshot.repetitions, 0);
    expect(r.analyzer.snapshot.partialRepetitions, 1);
    r.cycle();
    expect(r.analyzer.snapshot.repetitions, 1);
  });
}
