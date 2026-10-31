import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';

/// Projected synthetic motion only; these fixtures are not physical validation.
PoseFrame rowFrame(int t, double pull,
    {RowSide side = RowSide.left,
    bool facingLeft = false,
    bool curlOnly = false,
    bool horizontalTorso = false,
    double confidence = .99,
    double shoulderShift = 0,
    double hipShift = 0,
    double jitter = 0,
    bool mirrored = false,
    int width = 400,
    int height = 800}) {
  final direction = facingLeft ? -1.0 : 1.0;
  final sx = facingLeft ? .42 : .18;
  final sy = .24 + shoulderShift;
  final upperAngle = (90 - (curlOnly ? 0 : 75 * pull)) * math.pi / 180;
  final elbowAngle = (180 - 100 * pull) * math.pi / 180;
  final ex = sx + direction * .14 * math.cos(upperAngle);
  final ey = sy + .14 * math.sin(upperAngle);
  final forearmAngle = upperAngle + math.pi - elbowAngle;
  PosePoint p(double x, double y) => PosePoint(
      x: (x + jitter) * height / width,
      y: y + jitter,
      z: 0,
      visibility: confidence,
      presence: confidence);
  final joints = side == RowSide.left
      ? [
          PoseLandmark.leftShoulder,
          PoseLandmark.leftElbow,
          PoseLandmark.leftWrist,
          PoseLandmark.leftHip,
          PoseLandmark.leftKnee
        ]
      : [
          PoseLandmark.rightShoulder,
          PoseLandmark.rightElbow,
          PoseLandmark.rightWrist,
          PoseLandmark.rightHip,
          PoseLandmark.rightKnee
        ];
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: 'synthetic-row',
      modelVersion: '1',
      imageWidth: width,
      imageHeight: height,
      isMirrored: mirrored,
      landmarks: {
        joints[0]: p(sx, sy),
        joints[1]: p(ex, ey),
        joints[2]: p(ex + direction * .14 * math.cos(forearmAngle),
            ey + .14 * math.sin(forearmAngle)),
        joints[3]: p(
            sx + direction * .22, .24 + (horizontalTorso ? 0 : .04) + hipShift),
        joints[4]: p(sx + direction * .20, .65)
      });
}

/// Calibrate for 0.9s, then return a complete 2.4s row cycle.
Iterable<PoseFrame> rowTrajectory(
    {RowSide side = RowSide.left,
    int stepMicros = 50000,
    int startMicros = 0,
    bool facingLeft = false,
    bool horizontalTorso = false,
    double amplitude = 1,
    bool curlOnly = false}) sync* {
  for (var t = 0; t <= 3300000; t += stepMicros) {
    final motion = t < 900000
        ? 0.0
        : t < 1700000
            ? (t - 900000) / 800000
            : t < 2100000
                ? 1.0
                : t < 2900000
                    ? 1 - (t - 2100000) / 800000
                    : 0.0;
    yield rowFrame(startMicros + t, motion * amplitude,
        side: side,
        facingLeft: facingLeft,
        horizontalTorso: horizontalTorso,
        curlOnly: curlOnly);
  }
}
