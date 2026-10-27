import 'dart:math' as math;
import '../pose/pose_frame.dart';

enum CalfSide { left, right }

/// Aspect-correct image-plane evidence, not load, balance or bilateral symmetry.
class CalfRaiseGeometry {
  const CalfRaiseGeometry(
      {required this.shinLength,
      required this.kneeAngleDegrees,
      required this.heelHeight,
      required this.ankleY,
      required this.toeX,
      required this.toeY});
  final double shinLength, kneeAngleDegrees, heelHeight, ankleY, toeX, toeY;
  static List<PoseLandmark> joints(CalfSide side) => side == CalfSide.left
      ? const [
          PoseLandmark.leftHip,
          PoseLandmark.leftKnee,
          PoseLandmark.leftAnkle,
          PoseLandmark.leftHeel,
          PoseLandmark.leftFootIndex
        ]
      : const [
          PoseLandmark.rightHip,
          PoseLandmark.rightKnee,
          PoseLandmark.rightAnkle,
          PoseLandmark.rightHeel,
          PoseLandmark.rightFootIndex
        ];
  static double confidence(PoseFrame frame, CalfSide side) {
    if (frame.isMirrored || frame.imageWidth <= 0 || frame.imageHeight <= 0) {
      return 0;
    }
    var value = frame.posePresence ?? 1.0;
    if (!value.isFinite || value < 0 || value > 1) return 0;
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
      value = math.min(value, math.min(p.visibility, p.presence ?? 1));
    }
    return value;
  }

  /// Actionable setup feedback; visible skeleton lines alone do not imply
  /// sufficient heel/foot landmark confidence.
  static String setupCue(PoseFrame frame, CalfSide? selectedSide) {
    if (frame.isMirrored) {
      return 'Camera alignment changed · reposition the phone';
    }
    final side = selectedSide ??
        (confidence(frame, CalfSide.left) >= confidence(frame, CalfSide.right)
            ? CalfSide.left
            : CalfSide.right);
    if (confidence(frame, side) < .7) {
      return 'Foot tracking is weak · light your feet and keep heels and toes visible';
    }
    final g = fromFrame(frame, side);
    if (g == null) {
      final ids = joints(side),
          knee = frame.landmark(joints(side)[1])!,
          ankle = frame.landmark(joints(side)[2])!;
      final ratio = frame.imageWidth / frame.imageHeight;
      final shin = math.sqrt(math.pow((knee.x - ankle.x) * ratio, 2) +
          math.pow(knee.y - ankle.y, 2));
      if (shin < .10) {
        return 'Move a little closer · keep hips and feet fully in view';
      }
      final heel = frame.landmark(ids[3])!, toe = frame.landmark(ids[4])!;
      if (((toe.x - heel.x) * ratio).abs() < shin * .1) {
        return 'Turn fully side-on · show the heel-to-toe outline';
      }
      return 'Stand tall and side-on · keep hips, knees and feet in view';
    }
    if (g.kneeAngleDegrees < 165) {
      return 'Stand tall · keep knees straight and relaxed';
    }
    return 'Hold still with heels down';
  }

  static CalfRaiseGeometry? fromFrame(PoseFrame frame, CalfSide side) {
    if (confidence(frame, side) <= 0) return null;
    final p = joints(side).map((id) => frame.landmark(id)!).toList();
    final hip = p[0], knee = p[1], ankle = p[2], heel = p[3], toe = p[4];
    final ratio = frame.imageWidth / frame.imageHeight;
    final ax = (hip.x - knee.x) * ratio, ay = hip.y - knee.y;
    final bx = (ankle.x - knee.x) * ratio, by = ankle.y - knee.y;
    final thigh = math.sqrt(ax * ax + ay * ay),
        shin = math.sqrt(bx * bx + by * by);
    final footX = (toe.x - heel.x) * ratio, footY = toe.y - heel.y;
    final foot = math.sqrt(footX * footX + footY * footY);
    if (shin < .10 ||
        thigh < .08 ||
        ay >= 0 ||
        by <= 0 ||
        thigh / shin < .4 ||
        thigh / shin > 2 ||
        foot < shin * .1 ||
        foot > shin * .9 ||
        footX.abs() < shin * .1) {
      return null;
    }
    return CalfRaiseGeometry(
        shinLength: shin,
        kneeAngleDegrees:
            math.acos(((ax * bx + ay * by) / (thigh * shin)).clamp(-1.0, 1.0)) *
                180 /
                math.pi,
        heelHeight: toe.y - heel.y,
        ankleY: ankle.y,
        toeX: toe.x * ratio,
        toeY: toe.y);
  }
}
