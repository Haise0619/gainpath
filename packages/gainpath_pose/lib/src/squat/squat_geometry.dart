import 'dart:math' as math;
import '../pose/pose_frame.dart';

enum SquatSide { left, right }

/// Sagittal image geometry. Requires a side view and an upright, fixed camera.
/// It does not estimate camera yaw, gravity, or medical/biomechanical ground truth.
class SquatGeometry {
  const SquatGeometry(this.kneeAngleDegrees, this.trunkLeanDegrees);
  final double kneeAngleDegrees;
  final double trunkLeanDegrees;

  static List<PoseLandmark> joints(SquatSide side) => side == SquatSide.left
      ? const [
          PoseLandmark.leftShoulder,
          PoseLandmark.leftHip,
          PoseLandmark.leftKnee,
          PoseLandmark.leftAnkle
        ]
      : const [
          PoseLandmark.rightShoulder,
          PoseLandmark.rightHip,
          PoseLandmark.rightKnee,
          PoseLandmark.rightAnkle
        ];

  /// Minimum required-joint confidence; face/other-side points cannot mask loss.
  static double confidence(PoseFrame frame, SquatSide side) {
    if (frame.imageWidth <= 0 || frame.imageHeight <= 0 || frame.isMirrored) {
      return 0;
    }
    final pose = frame.posePresence ?? 1.0;
    if (!pose.isFinite || pose < 0 || pose > 1) return 0;
    var result = pose;
    for (final joint in joints(side)) {
      final p = frame.landmarks[joint];
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

  static SquatGeometry? fromFrame(PoseFrame frame, SquatSide side) {
    if (confidence(frame, side) <= 0) return null;
    final points = joints(side).map((id) => frame.landmarks[id]!).toList();
    (double, double) vector(PosePoint a, PosePoint b) =>
        ((a.x - b.x) * frame.imageWidth, (a.y - b.y) * frame.imageHeight);
    final thigh = vector(points[1], points[2]);
    final shin = vector(points[3], points[2]);
    final trunk = vector(points[0], points[1]);
    double length((double, double) v) => math.sqrt(v.$1 * v.$1 + v.$2 * v.$2);
    final a = length(thigh), b = length(shin), c = length(trunk);
    if (![a, b, c].every((v) => v.isFinite && v >= 1)) return null;
    final knee = math.acos(((thigh.$1 * shin.$1 + thigh.$2 * shin.$2) / (a * b))
            .clamp(-1.0, 1.0)) *
        180 /
        math.pi;
    final lean = math.acos((-trunk.$2 / c).clamp(-1.0, 1.0)) * 180 / math.pi;
    return SquatGeometry(knee, lean);
  }
}
