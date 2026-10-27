import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

PoseFrame curlFrame(int time, double angle,
    {double visibility = .99,
    bool mirrored = false,
    int width = 400,
    int height = 800}) {
  final radians = angle * math.pi / 180;
  final wristX = .4 + .12 * math.sin(radians) * height / width;
  final wristY = .34 - .12 * math.cos(radians);
  PosePoint point(double x, double y) =>
      PosePoint(x: x, y: y, z: 0, visibility: visibility, presence: visibility);
  return PoseFrame(
      capturedAtMicros: time,
      detectorId: 'synthetic',
      modelVersion: '1',
      imageWidth: width,
      imageHeight: height,
      isMirrored: mirrored,
      landmarks: {
        PoseLandmark.leftShoulder: point(.4, .2),
        PoseLandmark.leftElbow: point(.4, .34),
        PoseLandmark.leftWrist: point(wristX, wristY),
        PoseLandmark.leftHip: point(.4, .58),
      });
}

void main() {
  CurlAnalyzer calibrated() {
    final analyser = CurlAnalyzer();
    for (var time = 0; time <= 1000000; time += 100000) {
      analyser.update(curlFrame(time, 170), nowMicros: time);
    }
    return analyser;
  }

  CurlUpdate cycle(CurlAnalyzer analyser, List<double> angles,
      {int start = 1100000}) {
    late CurlUpdate update;
    for (var i = 0; i < angles.length; i++) {
      final time = start + i * 150000;
      update = analyser.update(curlFrame(time, angles[i]), nowMicros: time);
    }
    return update;
  }

  test('a controlled flexion and full return counts once, holds do not repeat',
      () {
    final analyser = calibrated();
    final update = cycle(
        analyser, [160, 130, 100, 70, 45, 45, 70, 100, 130, 160, 170, 170]);
    expect(update.repetitions, 1);
    expect(update.partialRepetitions, 0);
    expect(update.selectedSide, CurlSide.left);
    expect(update.formScorePercent, isNotNull);
  });
  test('incomplete flexion is partial and never a full repetition', () {
    final update =
        cycle(calibrated(), [160, 130, 110, 95, 95, 110, 130, 160, 170]);
    expect(update.repetitions, 0);
    expect(update.partialRepetitions, 1);
  });
  test('explicit right arm ignores left motion and counts right motion', () {
    PoseFrame rightFrame(int time, double angle) {
      final source = curlFrame(time, angle);
      return PoseFrame(
          capturedAtMicros: time,
          detectorId: 'synthetic',
          modelVersion: '1',
          imageWidth: 400,
          imageHeight: 800,
          landmarks: {
            for (var i = 0; i < 4; i++)
              CurlGeometry.joints(CurlSide.right)[i]:
                  source.landmark(CurlGeometry.joints(CurlSide.left)[i])!,
          });
    }

    final analyser = CurlAnalyzer(side: CurlSide.right);
    for (var t = 0; t <= 1000000; t += 100000) {
      analyser.update(curlFrame(t, 170), nowMicros: t);
    }
    expect(analyser.snapshot.needsCalibration, true);
    for (var t = 1100000; t <= 2100000; t += 100000) {
      analyser.update(rightFrame(t, 170), nowMicros: t);
    }
    final angles = [
      160.0,
      130.0,
      100.0,
      70.0,
      45.0,
      45.0,
      70.0,
      100.0,
      130.0,
      160.0
    ];
    for (var i = 0; i < angles.length; i++) {
      final t = 2200000 + i * 150000;
      analyser.update(rightFrame(t, angles[i]), nowMicros: t);
    }
    expect(analyser.snapshot.selectedSide, CurlSide.right);
    expect(analyser.snapshot.repetitions, 1);
    analyser.pause();
    expect(analyser.snapshot.selectedSide, CurlSide.right);
  });
  test('one isolated flexion spike cannot turn a partial curl into a full rep',
      () {
    final update =
        cycle(calibrated(), [160, 130, 100, 95, 45, 95, 100, 130, 160, 170]);
    expect(update.repetitions, 0);
    expect(update.partialRepetitions, 1);
  });
  test('confidence loss breaks the attempt and cannot bridge to a return', () {
    final analyser = calibrated();
    cycle(analyser, [160, 130, 100, 60, 45]);
    analyser.update(curlFrame(1900000, 45, visibility: .1), nowMicros: 1900000);
    final update = analyser.update(curlFrame(2000000, 170), nowMicros: 2000000);
    expect(update.repetitions, 0);
    expect(update.needsCalibration, true);
  });
  test('pause, stale and mirrored input cannot complete a repetition', () {
    final analyser = calibrated();
    cycle(analyser, [160, 130, 100, 60, 45]);
    analyser.pause();
    var update = analyser.update(curlFrame(1900000, 170), nowMicros: 1900000);
    expect(update.repetitions, 0);
    update = analyser.update(curlFrame(2000000, 170, mirrored: true),
        nowMicros: 2000000);
    expect(update.needsCalibration, true);
    update = analyser.update(curlFrame(2100000, 170), nowMicros: 2500001);
    expect(update.repetitions, 0);
    expect(update.needsCalibration, true);
  });
  test('aspect-correct angle is stable for portrait and landscape frames', () {
    for (final dimensions in [(400, 800), (800, 400)]) {
      final geometry = CurlGeometry.fromFrame(
          curlFrame(0, 75, width: dimensions.$1, height: dimensions.$2),
          CurlSide.left);
      expect(geometry!.elbowAngleDegrees, closeTo(75, .001));
    }
  });
}
