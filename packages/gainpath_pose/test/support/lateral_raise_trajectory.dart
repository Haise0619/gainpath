import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';

/// Synthetic projected joints only, never native detector or physical evidence.
PoseFrame lateralRaiseFrame(int t, double raise,
    {double? rightRaise,
    double confidence = .99,
    double bendDegrees = 10,
    double projection = 1,
    double shoulderShift = 0,
    double hipShift = 0,
    double torsoTilt = 0,
    double jitter = 0,
    double shoulderWidth = .12,
    bool mirrored = false,
    int width = 400,
    int height = 800,
    String modelVersion = '1'}) {
  final center = width / height / 2;
  PosePoint p(double x, double y) => PosePoint(
      x: (x + jitter) * height / width,
      y: y + jitter,
      z: 0,
      visibility: confidence,
      presence: confidence);
  final joints = <PoseLandmark, PosePoint>{};
  for (final left in [true, false]) {
    final v = left ? raise : (rightRaise ?? raise);
    final d = left ? -1.0 : 1.0;
    final sx = center + d * shoulderWidth / 2 + torsoTilt;
    final sy = .40 + shoulderShift;
    final angle = (8 + v * 82) * math.pi / 180;
    final forearmAngle = angle - bendDegrees * math.pi / 180;
    final ex = sx + d * .085 * math.sin(angle) * projection;
    final ey = sy + .085 * math.cos(angle) * projection;
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
    joints[ids[2]] = p(ex + d * .08 * math.sin(forearmAngle) * projection,
        ey + .08 * math.cos(forearmAngle) * projection);
    joints[ids[3]] = p(center + d * .05, .65 + hipShift);
  }
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: 'synthetic-lateral-raise',
      modelVersion: modelVersion,
      imageWidth: width,
      imageHeight: height,
      isMirrored: mirrored,
      landmarks: joints);
}

Iterable<PoseFrame> lateralRaiseTrajectory(
    {int startMicros = 0,
    int stepMicros = 50000,
    double amplitude = 1,
    double bendDegrees = 10,
    bool unilateral = false,
    bool alternating = false,
    int width = 400,
    int height = 800}) sync* {
  for (var t = 0; t <= 3600000; t += stepMicros) {
    final motion = t < 900000
        ? 0.0
        : t < 1750000
            ? (t - 900000) / 850000
            : t < 2200000
                ? 1.0
                : t < 3050000
                    ? 1 - (t - 2200000) / 850000
                    : 0.0;
    yield lateralRaiseFrame(startMicros + t, amplitude * motion,
        rightRaise: unilateral
            ? 0
            : alternating
                ? (t < 2200000 ? 0 : motion)
                : null,
        bendDegrees: bendDegrees,
        width: width,
        height: height);
  }
}

PoseFrame transformLateralFrame(PoseFrame f,
        {double scale = 1,
        bool? mirrored,
        String? modelVersion,
        Map<PoseLandmark, PosePoint>? landmarks}) =>
    PoseFrame(
        capturedAtMicros: f.capturedAtMicros,
        detectorId: f.detectorId,
        modelVersion: modelVersion ?? f.modelVersion,
        imageWidth: f.imageWidth,
        imageHeight: f.imageHeight,
        isMirrored: mirrored ?? f.isMirrored,
        landmarks: landmarks ??
            f.landmarks.map((id, p) => MapEntry(
                id,
                PosePoint(
                    x: .5 + (p.x - .5) * scale,
                    y: .5 + (p.y - .5) * scale,
                    z: p.z,
                    visibility: p.visibility,
                    presence: p.presence))));
