import 'dart:math' as math;
import '../pose/pose_frame.dart';

enum CurlSide { left, right }

/// Projected side-view measurements. Camera orientation is user-confirmed.
class CurlGeometry {
  const CurlGeometry(
      this.elbowAngleDegrees, this.upperArmDegrees, this.trunkDegrees);
  final double elbowAngleDegrees, upperArmDegrees, trunkDegrees;
  static List<PoseLandmark> joints(CurlSide side) => side == CurlSide.left
      ? const [
          PoseLandmark.leftShoulder,
          PoseLandmark.leftElbow,
          PoseLandmark.leftWrist,
          PoseLandmark.leftHip
        ]
      : const [
          PoseLandmark.rightShoulder,
          PoseLandmark.rightElbow,
          PoseLandmark.rightWrist,
          PoseLandmark.rightHip
        ];

  static double confidence(PoseFrame frame, CurlSide side) {
    if (frame.imageWidth <= 0 || frame.imageHeight <= 0 || frame.isMirrored)
      return 0;
    var confidence = frame.posePresence ?? 1.0;
    if (!confidence.isFinite || confidence < 0 || confidence > 1) return 0;
    for (final id in joints(side)) {
      final p = frame.landmark(id);
      if (p == null ||
          ![p.x, p.y, p.z, p.visibility, p.presence ?? 1]
              .every((v) => v.isFinite) ||
          p.x < 0 ||
          p.x > 1 ||
          p.y < 0 ||
          p.y > 1 ||
          p.visibility < 0 ||
          p.visibility > 1 ||
          (p.presence ?? 1) < 0 ||
          (p.presence ?? 1) > 1) return 0;
      confidence =
          math.min(confidence, math.min(p.visibility, p.presence ?? 1));
    }
    return confidence;
  }

  static CurlGeometry? fromFrame(PoseFrame frame, CurlSide side) {
    if (confidence(frame, side) <= 0) return null;
    final points = joints(side).map((id) => frame.landmark(id)!).toList();
    final shoulder = points[0],
        elbow = points[1],
        wrist = points[2],
        hip = points[3];
    final ratio = frame.imageWidth / frame.imageHeight;
    final ax = (shoulder.x - elbow.x) * ratio, ay = shoulder.y - elbow.y;
    final bx = (wrist.x - elbow.x) * ratio, by = wrist.y - elbow.y;
    final a = math.sqrt(ax * ax + ay * ay), b = math.sqrt(bx * bx + by * by);
    final tx = (shoulder.x - hip.x) * ratio, ty = hip.y - shoulder.y;
    final torso = math.sqrt(tx * tx + ty * ty);
    if (torso < .08 ||
        ty <= 0 ||
        a < torso * .12 ||
        b < torso * .12 ||
        a > torso * 1.5 ||
        b > torso * 1.5) return null;
    return CurlGeometry(
        math.acos(((ax * bx + ay * by) / (a * b)).clamp(-1.0, 1.0)) *
            180 /
            math.pi,
        math.atan2(-ax, -ay) * 180 / math.pi,
        math.atan2(tx, ty) * 180 / math.pi);
  }
}
