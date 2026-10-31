import 'dart:math' as math;
import '../pose/pose_frame.dart';

enum RowSide { left, right }

/// Aspect-correct image evidence for a selected arm in a side-view row.
/// No load, spinal alignment, rotation or bench contact is inferred.
class RowGeometry {
  const RowGeometry(
      {required this.elbowAngleDegrees,
      required this.torsoLength,
      required this.torsoInclinationDegrees,
      required this.torsoDirection,
      required this.upperArmProjection,
      required this.upperArmLength,
      required this.forearmLength,
      required this.armVerticality,
      required this.shoulderX,
      required this.shoulderY,
      required this.hipX,
      required this.hipY});

  final double elbowAngleDegrees,
      torsoLength,
      torsoInclinationDegrees,
      torsoDirection,
      upperArmProjection,
      upperArmLength,
      forearmLength,
      armVerticality,
      shoulderX,
      shoulderY,
      hipX,
      hipY;

  static List<PoseLandmark> joints(RowSide side) => side == RowSide.left
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

  static double confidence(PoseFrame frame, RowSide side) {
    if (frame.isMirrored || frame.imageWidth <= 0 || frame.imageHeight <= 0) {
      return 0;
    }
    var result = frame.posePresence ?? 1.0;
    if (!result.isFinite || result < 0 || result > 1) return 0;
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
          (p.presence ?? 1) > 1) {
        return 0;
      }
      result = math.min(result, math.min(p.visibility, p.presence ?? 1));
    }
    return result;
  }

  static RowGeometry? fromFrame(PoseFrame frame, RowSide side) {
    if (confidence(frame, side) <= 0) return null;
    final ids = joints(side);
    final s = frame.landmark(ids[0])!,
        e = frame.landmark(ids[1])!,
        w = frame.landmark(ids[2])!,
        h = frame.landmark(ids[3])!;
    final ratio = frame.imageWidth / frame.imageHeight;
    final tx = (h.x - s.x) * ratio, ty = h.y - s.y;
    final ux = (e.x - s.x) * ratio, uy = e.y - s.y;
    final fx = (w.x - e.x) * ratio, fy = w.y - e.y;
    final torso = math.sqrt(tx * tx + ty * ty),
        upper = math.sqrt(ux * ux + uy * uy),
        forearm = math.sqrt(fx * fx + fy * fy);
    if (torso < .10 ||
        upper < torso * .2 ||
        forearm < torso * .2 ||
        upper > torso * 1.3 ||
        forearm > torso * 1.3) {
      return null;
    }
    final elbow =
        math.acos(((-ux * fx - uy * fy) / (upper * forearm)).clamp(-1.0, 1.0)) *
            180 /
            math.pi;
    return RowGeometry(
        elbowAngleDegrees: elbow,
        torsoLength: torso,
        torsoInclinationDegrees: math.atan2(ty, tx.abs()) * 180 / math.pi,
        torsoDirection: tx.sign,
        upperArmProjection: (ux * tx + uy * ty) / (torso * torso),
        upperArmLength: upper,
        forearmLength: forearm,
        armVerticality: uy / upper,
        shoulderX: s.x * ratio,
        shoulderY: s.y,
        hipX: h.x * ratio,
        hipY: h.y);
  }

  bool get bentTorso => torsoInclinationDegrees.abs() <= 45;
  bool get neutral =>
      bentTorso && elbowAngleDegrees >= 160 && armVerticality >= .94;

  double shoulderDistance(RowGeometry other) =>
      math.sqrt(math.pow(shoulderX - other.shoulderX, 2) +
          math.pow(shoulderY - other.shoulderY, 2)) /
      other.torsoLength;
  double hipDistance(RowGeometry other) =>
      math.sqrt(
          math.pow(hipX - other.hipX, 2) + math.pow(hipY - other.hipY, 2)) /
      other.torsoLength;
}
