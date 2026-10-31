import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';

/// Synthetic, fixed-length sagittal leg projection; not physical validation.
PoseFrame reverseLungeFrame(int t, double step, double depth,
    {LungeSide side = LungeSide.left,
    bool facingLeft = false,
    double confidence = .99,
    bool forward = false,
    bool wrongLeg = false,
    double? neutralGapRatio,
    double translateX = 0,
    double translateY = 0,
    int width = 400,
    int height = 800,
    bool mirrored = false}) {
  final points = <PoseLandmark, PosePoint>{};
  PosePoint p(double x, double y) => PosePoint(
      x: ((facingLeft ? .5 - x : x) + translateX) * height / width,
      y: y + translateY,
      z: 0,
      visibility: confidence,
      presence: confidence);
  final hipX = .29 - .065 * step + .045 * depth;
  final hipY = .445 + .155 * depth + .03 * step;
  for (final left in [true, false]) {
    final selected = left == (side == LungeSide.left);
    final front = wrongLeg ? !selected : selected;
    final rearStart =
        neutralGapRatio == null ? .29 : .30 - .44 * neutralGapRatio;
    final ankleX = front ? .30 : rearStart + (forward ? 1 : -1) * .23 * step;
    const ankleY = .88;
    final dx = ankleX - hipX, dy = ankleY - hipY;
    final distance = math.sqrt(dx * dx + dy * dy);
    final heightToKnee =
        math.sqrt(math.max(0, .22 * .22 - distance * distance / 4));
    final kneeX = (hipX + ankleX) / 2 + heightToKnee * dy / distance;
    final kneeY = (hipY + ankleY) / 2 - heightToKnee * dx / distance;
    points.addAll({
      left ? PoseLandmark.leftShoulder : PoseLandmark.rightShoulder:
          p(hipX, hipY - .24),
      left ? PoseLandmark.leftHip : PoseLandmark.rightHip: p(hipX, hipY),
      left ? PoseLandmark.leftKnee : PoseLandmark.rightKnee: p(kneeX, kneeY),
      left ? PoseLandmark.leftAnkle : PoseLandmark.rightAnkle:
          p(ankleX, ankleY),
      left ? PoseLandmark.leftHeel : PoseLandmark.rightHeel:
          p(ankleX - .025, ankleY + .012),
      left ? PoseLandmark.leftFootIndex : PoseLandmark.rightFootIndex:
          p(ankleX + .045, ankleY + .012),
    });
  }
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: 'synthetic-reverse-lunge',
      modelVersion: '1',
      imageWidth: width,
      imageHeight: height,
      isMirrored: mirrored,
      landmarks: points);
}

/// Standing, backward step, descent/hold, then feet-together standing return.
Iterable<PoseFrame> reverseLungeTrajectory(
    {LungeSide side = LungeSide.left,
    int stepMicros = 50000,
    int startMicros = 0,
    bool facingLeft = false,
    double amplitude = 1,
    bool forward = false,
    bool wrongLeg = false,
    bool squat = false,
    double? neutralGapRatio,
    double translateX = 0,
    int width = 400,
    int height = 800}) sync* {
  for (var t = 0; t <= 4300000; t += stepMicros) {
    final step = t < 1100000
        ? 0.0
        : t < 1700000
            ? (t - 1100000) / 600000
            : t < 3300000
                ? 1.0
                : t < 3900000
                    ? 1 - (t - 3300000) / 600000
                    : 0.0;
    final depth = t < 1700000
        ? 0.0
        : t < 2300000
            ? (t - 1700000) / 600000
            : t < 2700000
                ? 1.0
                : t < 3300000
                    ? 1 - (t - 2700000) / 600000
                    : 0.0;
    yield reverseLungeFrame(
        startMicros + t, squat ? 0 : step, depth * amplitude,
        side: side,
        facingLeft: facingLeft,
        forward: forward,
        wrongLeg: wrongLeg,
        neutralGapRatio: neutralGapRatio,
        translateX: translateX,
        width: width,
        height: height);
  }
}
