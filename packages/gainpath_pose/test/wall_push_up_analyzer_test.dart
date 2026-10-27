import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

PoseFrame wallFrame(int t, double angle,
    {WallPushUpSide side = WallPushUpSide.left,
    bool facingLeft = false,
    double confidence = .99,
    double wristShift = 0,
    bool bentBody = false,
    bool mirrored = false,
    int width = 400,
    int height = 800}) {
  final wristX = facingLeft ? .08 : .42;
  final direction = facingLeft ? -1.0 : 1.0;
  final reach = .28 * math.sin(angle * math.pi / 360),
      sag = .14 * math.cos(angle * math.pi / 360);
  final shoulderX = wristX - direction * reach,
      hipX = shoulderX - direction * .04;
  PosePoint p(double x, double y) => PosePoint(
      x: x * height / width,
      y: y,
      z: 0,
      visibility: confidence,
      presence: confidence);
  final j = WallPushUpGeometry.joints(side);
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: 'fixture',
      modelVersion: '1',
      imageWidth: width,
      imageHeight: height,
      isMirrored: mirrored,
      landmarks: {
        j[0]: p(shoulderX, .25),
        j[1]: p((shoulderX + wristX) / 2, .25 + sag),
        j[2]: p(wristX + wristShift, .25),
        j[3]: p(hipX + (bentBody ? .16 : 0), .5),
        j[4]: p(hipX - direction * .04, .75)
      });
}

void main() {
  WallPushUpAnalyzer calibrated(
      {WallPushUpSide side = WallPushUpSide.left, bool facingLeft = false}) {
    final a = WallPushUpAnalyzer();
    for (var t = 0; t <= 1100000; t += 100000) {
      a.update(wallFrame(t, 170, side: side, facingLeft: facingLeft),
          nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
    return a;
  }

  void cycle(WallPushUpAnalyzer a, List<double> angles,
      {int start = 1250000,
      WallPushUpSide side = WallPushUpSide.left,
      bool facingLeft = false}) {
    for (var i = 0; i < angles.length; i++) {
      final t = start + i * 150000;
      a.update(wallFrame(t, angles[i], side: side, facingLeft: facingLeft),
          nowMicros: t);
    }
  }

  for (final side in WallPushUpSide.values) {
    for (final left in [false, true]) {
      test(
          '${side.name} arm facingLeft=$left counts one controlled wall push-up',
          () {
        final a = calibrated(side: side, facingLeft: left);
        cycle(a, [160, 140, 120, 100, 90, 90, 110, 140, 160, 170, 170],
            side: side, facingLeft: left);
        expect(a.snapshot.repetitions, 1);
        expect(a.snapshot.partialRepetitions, 0);
        expect(a.snapshot.selectedSide, side);
        expect(a.snapshot.formScorePercent, 100);
      });
    }
  }
  test('shallow movement is partial and one deep spike cannot become full', () {
    for (final angles in <List<double>>[
      [160, 140, 125, 120, 120, 140, 160, 170, 170],
      [160, 140, 125, 90, 125, 140, 160, 170, 170]
    ]) {
      final a = calibrated();
      cycle(a, angles);
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.partialRepetitions, 1);
    }
  });
  test('standing jitter and static bent-arm start cannot count', () {
    final a = calibrated();
    cycle(a, [168, 164, 169, 163, 170, 168, 170]);
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.partialRepetitions, 0);
    final bent = WallPushUpAnalyzer();
    for (var t = 0; t <= 1500000; t += 100000) {
      bent.update(wallFrame(t, 90), nowMicros: t);
    }
    expect(bent.snapshot.needsCalibration, true);
  });
  test('wrist sliding or a body fold invalidates the unfinished cycle', () {
    for (final fold in [false, true]) {
      final a = calibrated();
      cycle(a, [160, 140, 120, 100, 90, 90]);
      a.update(
          wallFrame(2150000, 170, wristShift: fold ? 0 : .1, bentBody: fold),
          nowMicros: 2150000);
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.needsCalibration, true);
    }
  });
  test(
      'pause confidence loss stale mirror and camera gap cannot bridge a return',
      () {
    for (final mode in ['pause', 'confidence', 'stale', 'mirror', 'gap']) {
      final a = calibrated();
      cycle(a, [160, 140, 120, 100, 90, 90]);
      if (mode == 'pause') a.pause();
      final t = mode == 'gap' ? 2700000 : 2150000;
      a.update(
          wallFrame(t, 170,
              confidence: mode == 'confidence' ? .2 : .99,
              mirrored: mode == 'mirror'),
          nowMicros: mode == 'stale' ? t + 300000 : t);
      expect(a.snapshot.repetitions, 0);
      expect(a.snapshot.needsCalibration, true);
    }
  });
  test(
      'startup uses stable samples and tolerates small wrist jitter and one weak sample',
      () {
    final a = WallPushUpAnalyzer();
    for (var t = 0; t <= 1400000; t += 50000) {
      a.update(
          wallFrame(t, 168 + (t ~/ 50000 % 3),
              wristShift: (t ~/ 50000).isEven ? .002 : -.002,
              confidence: t == 400000 ? .6 : .99),
          nowMicros: t);
    }
    expect(a.snapshot.needsCalibration, false);
    expect(a.snapshot.repetitions, 0);
  });
  test('aspect ratio does not change projected elbow angle', () {
    for (final size in [(400, 800), (800, 400)]) {
      final g = WallPushUpGeometry.fromFrame(
          wallFrame(0, 95, width: size.$1, height: size.$2),
          WallPushUpSide.left)!;
      expect(g.elbowAngleDegrees, closeTo(95, .001));
    }
  });
}
