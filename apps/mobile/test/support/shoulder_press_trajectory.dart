import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';

/// Synthetic projected joints only; no physical accuracy is claimed.
PoseFrame shoulderPressFrame(int t, double press,
    {double? rightPress,
    double confidence = .99,
    double shoulderShift = 0,
    double hipShift = 0,
    double torsoTilt = 0,
    double jitter = 0,
    double shoulderWidth = .15,
    bool lateralRaise = false,
    bool mirrored = false,
    int width = 400,
    int height = 800}) {
  final center = width / height / 2;
  PosePoint p(double x, double y) => PosePoint(
      x: (x + jitter) * height / width,
      y: y + jitter,
      z: 0,
      visibility: confidence,
      presence: confidence);
  final joints = <PoseLandmark, PosePoint>{};
  for (final left in [true, false]) {
    final v = left ? press : (rightPress ?? press);
    final d = left ? -1.0 : 1.0;
    final sx = center + d * shoulderWidth / 2 + torsoTilt;
    final sy = .46 + shoulderShift;
    final angle = (lateralRaise ? 0 : v * 80) * math.pi / 180;
    final ex = sx + d * .105 * math.cos(angle);
    final ey = sy - .105 * math.sin(angle);
    final ids = left
        ? [
            PoseLandmark.leftShoulder,
            PoseLandmark.leftElbow,
            PoseLandmark.leftWrist,
            PoseLandmark.leftHip
          ]
        : [
            PoseLandmark.rightShoulder,
            PoseLandmark.rightElbow,
            PoseLandmark.rightWrist,
            PoseLandmark.rightHip
          ];
    joints[ids[0]] = p(sx, sy);
    joints[ids[1]] = p(ex, ey);
    joints[ids[2]] = p(ex, ey - .105);
    joints[ids[3]] = p(center + d * .06, .71 + hipShift);
  }
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: 'synthetic-press',
      modelVersion: '1',
      imageWidth: width,
      imageHeight: height,
      isMirrored: mirrored,
      landmarks: joints);
}

Iterable<PoseFrame> shoulderPressTrajectory(
    {int startMicros = 0,
    int stepMicros = 50000,
    double amplitude = 1,
    bool unilateral = false,
    bool alternating = false,
    int width = 400,
    int height = 800}) sync* {
  for (var t = 0; t <= 3400000; t += stepMicros) {
    final motion = t < 900000
        ? 0.0
        : t < 1700000
            ? (t - 900000) / 800000
            : t < 2100000
                ? 1.0
                : t < 2900000
                    ? 1 - (t - 2100000) / 800000
                    : 0.0;
    yield shoulderPressFrame(startMicros + t, amplitude * motion,
        rightPress: unilateral
            ? 0
            : alternating
                ? (t < 2100000 ? 0 : motion)
                : null,
        width: width,
        height: height);
  }
}
