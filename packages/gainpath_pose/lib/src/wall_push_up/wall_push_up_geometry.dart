import 'dart:math' as math;
import '../pose/pose_frame.dart';

enum WallPushUpSide { left, right }

/// Side-view arm/body evidence. Wall contact, force and symmetry are not inferred.
class WallPushUpGeometry {
  const WallPushUpGeometry(
      {required this.elbowAngleDegrees,
      required this.bodyAngleDegrees,
      required this.torsoLength,
      required this.torsoAngleDegrees,
      required this.wristX,
      required this.wristY,
      required this.reach,
      required this.horizontalReach,
      required this.handHeight});
  final double elbowAngleDegrees,
      bodyAngleDegrees,
      torsoLength,
      torsoAngleDegrees,
      wristX,
      wristY,
      reach,
      horizontalReach,
      handHeight;
  static List<PoseLandmark> joints(WallPushUpSide side) =>
      side == WallPushUpSide.left
          ? const [
              PoseLandmark.leftShoulder,
              PoseLandmark.leftElbow,
              PoseLandmark.leftWrist,
              PoseLandmark.leftHip,
              PoseLandmark.leftKnee
            ]
          : const [
              PoseLandmark.rightShoulder,
              PoseLandmark.rightElbow,
              PoseLandmark.rightWrist,
              PoseLandmark.rightHip,
              PoseLandmark.rightKnee
            ];
  static double confidence(PoseFrame f, WallPushUpSide side) {
    if (f.isMirrored || f.imageWidth <= 0 || f.imageHeight <= 0) return 0;
    var confidence = f.posePresence ?? 1.0;
    if (!confidence.isFinite || confidence < 0 || confidence > 1) return 0;
    for (final id in joints(side)) {
      final p = f.landmark(id);
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
      confidence =
          math.min(confidence, math.min(p.visibility, p.presence ?? 1));
    }
    return confidence;
  }

  static double? _angle(double ax, double ay, double bx, double by) {
    final a = math.sqrt(ax * ax + ay * ay), b = math.sqrt(bx * bx + by * by);
    if (a < .02 || b < .02) return null;
    return math.acos(((ax * bx + ay * by) / (a * b)).clamp(-1.0, 1.0)) *
        180 /
        math.pi;
  }

  static WallPushUpGeometry? fromFrame(PoseFrame f, WallPushUpSide side) {
    if (confidence(f, side) <= 0) return null;
    final j = joints(side).map((id) => f.landmark(id)!).toList();
    final s = j[0],
        e = j[1],
        w = j[2],
        h = j[3],
        k = j[4],
        ratio = f.imageWidth / f.imageHeight;
    final tx = (s.x - h.x) * ratio, ty = s.y - h.y;
    final torso = math.sqrt(tx * tx + ty * ty);
    if (torso < .10 || ty >= 0 || k.y <= h.y) return null;
    final ux = (s.x - e.x) * ratio,
        uy = s.y - e.y,
        fx = (w.x - e.x) * ratio,
        fy = w.y - e.y;
    final upper = math.sqrt(ux * ux + uy * uy),
        forearm = math.sqrt(fx * fx + fy * fy);
    if (upper < torso * .2 ||
        forearm < torso * .2 ||
        upper > torso * 1.5 ||
        forearm > torso * 1.5) {
      return null;
    }
    final elbow = _angle(ux, uy, fx, fy),
        body = _angle(tx, ty, (k.x - h.x) * ratio, k.y - h.y);
    if (elbow == null || body == null) return null;
    final dx = (w.x - s.x) * ratio, dy = w.y - s.y;
    return WallPushUpGeometry(
        elbowAngleDegrees: elbow,
        bodyAngleDegrees: body,
        torsoLength: torso,
        torsoAngleDegrees: math.atan2(tx, -ty) * 180 / math.pi,
        wristX: w.x * ratio,
        wristY: w.y,
        reach: math.sqrt(dx * dx + dy * dy),
        horizontalReach: dx,
        handHeight: dy / torso);
  }

  bool get neutral =>
      elbowAngleDegrees >= 155 &&
      bodyAngleDegrees >= 160 &&
      torsoAngleDegrees.abs() <= 55 &&
      horizontalReach.abs() / torsoLength >= .55 &&
      handHeight.abs() <= .65;
  double wristDistance(WallPushUpGeometry other) =>
      math.sqrt(math.pow(wristX - other.wristX, 2) +
          math.pow(wristY - other.wristY, 2)) /
      other.torsoLength;
  static String setupCue(PoseFrame frame, WallPushUpSide? selected) {
    final side = selected ??
        (confidence(frame, WallPushUpSide.left) >=
                confidence(frame, WallPushUpSide.right)
            ? WallPushUpSide.left
            : WallPushUpSide.right);
    if (confidence(frame, side) < .65) {
      return 'Keep shoulder, elbow, wrist, hip and knee clearly in view';
    }
    final g = fromFrame(frame, side);
    if (g == null) {
      return 'Move into view · show your arm and body from the side';
    }
    if (g.horizontalReach.abs() / g.torsoLength < .55) {
      return 'Turn side-on · face the wall with palms at chest height';
    }
    if (g.elbowAngleDegrees < 155) {
      return 'Start with arms extended and palms on the wall';
    }
    if (g.bodyAngleDegrees < 160 || g.torsoAngleDegrees.abs() > 55) {
      return 'Keep your body in line · use the standing wall setup';
    }
    if (g.handHeight.abs() > .65) {
      return 'Place palms on the wall at chest height';
    }
    return 'Hold your starting position · palms steady on the wall';
  }
}
