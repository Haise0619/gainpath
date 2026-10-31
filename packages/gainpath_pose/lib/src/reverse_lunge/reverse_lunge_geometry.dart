import 'dart:math' as math;
import '../pose/pose_frame.dart';

/// Anatomical front working leg, which stays planted for the entire set.
enum LungeSide { left, right }

/// Aspect-correct selected-front-leg projection. The rear knee is unmeasured;
/// no rear knee angle, depth, balance or load is inferred.
class ReverseLungeGeometry {
  ReverseLungeGeometry._(
      this.frontHip,
      this.rearHip,
      this.frontKnee,
      this.frontAnkle,
      this.rearAnkle,
      this.frontHeel,
      this.frontToe,
      this.shoulder,
      this.frontAngle,
      this.frontThigh,
      this.frontShin,
      this.torsoLength,
      this.facing);

  final (double, double) frontHip,
      rearHip,
      frontKnee,
      frontAnkle,
      rearAnkle,
      frontHeel,
      frontToe,
      shoulder;
  final double frontAngle, frontThigh, frontShin, torsoLength, facing;
  double get legLength => frontThigh + frontShin;
  double get hipY => (frontHip.$2 + rearHip.$2) / 2;
  bool get upright =>
      (shoulder.$1 - frontHip.$1).abs() <= torsoLength * .5 &&
      shoulder.$2 < frontHip.$2;
  bool get neutral =>
      upright &&
      frontAngle >= 160 &&
      (frontHip.$2 - rearHip.$2).abs() <= legLength * .08 &&
      _neutralFeet;
  // A small visible ankle gap avoids requiring side-view foot occlusion.
  // Both ankle heights must still indicate the same standing ground level.
  bool get _neutralFeet =>
      (frontAnkle.$1 - rearAnkle.$1).abs() <= legLength * .30 &&
      (frontAnkle.$2 - rearAnkle.$2).abs() <= legLength * .08;

  static double distance((double, double) a, (double, double) b) =>
      math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));
  static double _angle(
      (double, double) hip, (double, double) knee, (double, double) ankle) {
    final a = distance(hip, knee), b = distance(knee, ankle);
    if (a == 0 || b == 0) return 0;
    return math.acos((((hip.$1 - knee.$1) * (ankle.$1 - knee.$1) +
                    (hip.$2 - knee.$2) * (ankle.$2 - knee.$2)) /
                (a * b))
            .clamp(-1.0, 1.0)) *
        180 /
        math.pi;
  }

  static bool canSetup(PoseFrame frame, LungeSide side) =>
      fromFrame(frame, side)?.neutral ?? false;

  static ReverseLungeGeometry? fromFrame(PoseFrame frame, LungeSide side) =>
      _measure(frame, side).geometry;

  /// Scalar decision only; no landmarks are retained or exposed by feedback.
  static String? rejectionReason(PoseFrame frame, LungeSide side) =>
      _measure(frame, side).reason;

  /// Null means the observed pose can begin a neutral calibration hold.
  static String? setupCue(PoseFrame frame, LungeSide side) {
    final measured = _measure(frame, side);
    if (measured.cue != null) return measured.cue;
    final g = measured.geometry!;
    if (g.frontAngle < 160) {
      return 'Straighten the selected front knee to start · keep that foot planted';
    }
    if ((g.frontHip.$2 - g.rearHip.$2).abs() > g.legLength * .08) {
      return 'Stand tall with both hips level to start';
    }
    if (!g._neutralFeet) {
      return 'Stand with feet comfortably apart on the same level · show both ankles';
    }
    return null;
  }

  static ({ReverseLungeGeometry? geometry, String? reason, String? cue})
      _measure(PoseFrame frame, LungeSide side) {
    ({ReverseLungeGeometry? geometry, String? reason, String? cue}) rejected(
            String reason, String cue) =>
        (geometry: null, reason: reason, cue: cue);
    if (frame.isMirrored ||
        frame.imageWidth <= 0 ||
        frame.imageHeight <= 0 ||
        !(frame.posePresence ?? 1).isFinite ||
        (frame.posePresence ?? 1) < 0 ||
        (frame.posePresence ?? 1) > 1) {
      return rejected('invalid_camera_frame',
          'Use a clear, unmirrored side-on camera view');
    }
    if ((frame.posePresence ?? 1) < .7) {
      return rejected('pose_unclear',
          'Keep your whole body clearly visible in the side-on camera view');
    }
    final points = <(double, double)>[];
    final left = side == LungeSide.left;
    final front = left
        ? const [
            PoseLandmark.leftHip,
            PoseLandmark.leftKnee,
            PoseLandmark.leftAnkle,
            PoseLandmark.leftHeel,
            PoseLandmark.leftFootIndex,
            PoseLandmark.leftShoulder
          ]
        : const [
            PoseLandmark.rightHip,
            PoseLandmark.rightKnee,
            PoseLandmark.rightAnkle,
            PoseLandmark.rightHeel,
            PoseLandmark.rightFootIndex,
            PoseLandmark.rightShoulder
          ];
    // The camera-far knee can be fully occluded in a valid side view. Rear hip
    // and ankle provide observed hip drop/backstep/return without inventing it.
    final rear = left
        ? const [
            PoseLandmark.rightHip,
            PoseLandmark.rightAnkle,
          ]
        : const [
            PoseLandmark.leftHip,
            PoseLandmark.leftAnkle,
          ];
    for (final id in [...front, ...rear]) {
      final p = frame.landmark(id);
      if (p == null ||
          ![p.x, p.y, p.z, p.visibility, p.presence ?? 1]
              .every((v) => v.isFinite) ||
          p.x < 0 ||
          p.x > 1 ||
          p.y < 0 ||
          p.y > 1 ||
          p.visibility < .7 ||
          p.visibility > 1 ||
          (p.presence ?? 1) < .7 ||
          (p.presence ?? 1) > 1) {
        final name = id.name
            .replaceAllMapped(
                RegExp(r'[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}')
            .replaceAll('foot index', 'toes');
        return rejected('required_${id.name}_unclear',
            'Show your $name clearly · adjust the side-on camera view');
      }
      points.add((p.x * frame.imageWidth / frame.imageHeight, p.y));
    }
    final h = points[0],
        k = points[1],
        a = points[2],
        heel = points[3],
        toe = points[4],
        s = points[5];
    final rh = points[6], ra = points[7];
    final thigh = distance(h, k), shin = distance(k, a), torso = distance(s, h);
    if ([thigh, shin].any((v) => v * frame.imageHeight < 24 || v < .025) ||
        torso * frame.imageHeight < 24 ||
        torso < .04) {
      return rejected('body_too_small',
          'Move the camera closer · keep both legs and the selected front foot visible');
    }
    if (thigh / shin < .55 ||
        thigh / shin > 1.8 ||
        distance(h, rh) > (thigh + shin) * .3) {
      return rejected('side_on_projection',
          'Turn side-on · show the selected front knee, both hips and both ankles');
    }
    if ((toe.$1 - heel.$1).abs() < (thigh + shin) * .06) {
      return rejected('front_foot_direction_unclear',
          'Turn side-on so the selected front heel and toes are visible');
    }
    final result = ReverseLungeGeometry._(h, rh, k, a, ra, heel, toe, s,
        _angle(h, k, a), thigh, shin, torso, (toe.$1 - heel.$1).sign);
    if (!result.upright) {
      return rejected('torso_not_upright',
          'Stand upright with your shoulder above your hip');
    }
    return (geometry: result, reason: null, cue: null);
  }
}
