import 'dart:math' as math;
import '../pose/pose_frame.dart';

/// Aspect-correct front-view observations. No load, spinal alignment,
/// three-dimensional shoulder mechanics or seated/standing status is inferred.
class ShoulderPressGeometry {
  const ShoulderPressGeometry(
      this.angles,
      this.wristHeights,
      this.elbowHeights,
      this.upperLengths,
      this.forearmLengths,
      this.torsoLength,
      this.shoulderWidth,
      this.centerX,
      this.centerY,
      this.hipX,
      this.hipY,
      this.frontUpright);
  static const joints = [
    PoseLandmark.leftShoulder,
    PoseLandmark.rightShoulder,
    PoseLandmark.leftElbow,
    PoseLandmark.rightElbow,
    PoseLandmark.leftWrist,
    PoseLandmark.rightWrist,
    PoseLandmark.leftHip,
    PoseLandmark.rightHip
  ];
  final List<double> angles,
      wristHeights,
      elbowHeights,
      upperLengths,
      forearmLengths;
  final double torsoLength, shoulderWidth, centerX, centerY, hipX, hipY;
  final bool frontUpright;
  // Admission is based on usable image resolution, not the former 12%-height
  // framing assumption. Relative limb/torso checks below remain scale invariant.
  static const minimumTorsoPixels = 24;
  static const minimumTorsoFraction = .04;

  static double _pointConfidence(PosePoint? p) {
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
    return math.min(p.visibility, p.presence ?? 1);
  }

  static double _torsoFraction(PoseFrame frame) {
    final ls = frame.landmark(joints[0])!,
        rs = frame.landmark(joints[1])!,
        lh = frame.landmark(joints[6])!,
        rh = frame.landmark(joints[7])!;
    final dx = (ls.x + rs.x - lh.x - rh.x) *
            frame.imageWidth /
            frame.imageHeight /
            2,
        dy = (ls.y + rs.y - lh.y - rh.y) / 2;
    return math.sqrt(dx * dx + dy * dy);
  }

  static bool _enoughResolution(double torso, int imageHeight) =>
      torso >= minimumTorsoFraction &&
      torso * imageHeight >= minimumTorsoPixels;

  /// A rejected frame must explain its actual gate, rather than asserting
  /// already-visible joints are absent. Called only on rejected analysis frames.
  static String rejectionCue(PoseFrame frame, ShoulderPressGeometry? geometry) {
    if (frame.isMirrored || frame.imageWidth <= 0 || frame.imageHeight <= 0) {
      return 'Camera geometry unavailable · reposition and recalibrate';
    }
    for (final id in joints) {
      if (_pointConfidence(frame.landmark(id)) < .65) {
        final name = id.name.replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]!.toLowerCase()}');
        return 'Show $name clearly · adjust framing or lighting';
      }
    }
    if (confidence(frame) < .65) {
      return 'Body tracking uncertain · improve lighting and hold still';
    }
    if (!_enoughResolution(_torsoFraction(frame), frame.imageHeight)) {
      return 'Move closer · keep both hips and overhead hands in view';
    }
    if (geometry != null && !geometry.frontUpright) {
      return 'Face the camera straight on · keep your torso upright';
    }
    return 'Keep both forearms upward · hands above elbows';
  }

  static double confidence(PoseFrame frame) {
    if (frame.isMirrored || frame.imageWidth <= 0 || frame.imageHeight <= 0) {
      return 0;
    }
    var result = frame.posePresence ?? 1.0;
    if (!result.isFinite || result < 0 || result > 1) return 0;
    for (final id in joints) {
      result = math.min(result, _pointConfidence(frame.landmark(id)));
    }
    return result;
  }

  static ShoulderPressGeometry? fromFrame(PoseFrame frame) {
    if (confidence(frame) < .65) return null;
    final aspect = frame.imageWidth / frame.imageHeight;
    final ls = frame.landmark(joints[0])!,
        rs = frame.landmark(joints[1])!,
        lh = frame.landmark(joints[6])!,
        rh = frame.landmark(joints[7])!;
    final sx = (ls.x + rs.x) * aspect / 2,
        sy = (ls.y + rs.y) / 2,
        hx = (lh.x + rh.x) * aspect / 2,
        hy = (lh.y + rh.y) / 2;
    final torso = math.sqrt(math.pow(sx - hx, 2) + math.pow(sy - hy, 2));
    final shoulderWidth = (ls.x - rs.x).abs() * aspect;
    if (!_enoughResolution(torso, frame.imageHeight)) return null;
    // Shoulder elevation/narrowing during an overhead reach changes this 2-D
    // ratio. Exclude a collapsed side view without freezing the bottom span.
    final frontal = shoulderWidth / torso >= .30 &&
        shoulderWidth / torso <= 1.5 &&
        (ls.y - rs.y).abs() / torso <= .18 &&
        (lh.y - rh.y).abs() / torso <= .20 &&
        (hy - sy) / torso >= .94 &&
        (hx - sx).abs() / torso <= .25;
    final angles = <double>[],
        wrists = <double>[],
        elbows = <double>[],
        upper = <double>[],
        forearms = <double>[];
    for (var i = 0; i < 2; i++) {
      final s = frame.landmark(joints[i])!,
          e = frame.landmark(joints[i + 2])!,
          w = frame.landmark(joints[i + 4])!;
      final ux = (e.x - s.x) * aspect,
          uy = e.y - s.y,
          fx = (w.x - e.x) * aspect,
          fy = w.y - e.y;
      final u = math.sqrt(ux * ux + uy * uy), f = math.sqrt(fx * fx + fy * fy);
      if (u < torso * .2 ||
          f < torso * .2 ||
          u > torso * .85 ||
          f > torso * .85 ||
          -fy / f < .72) {
        return null;
      }
      if ((w.x - s.x) * aspect * (s.x < sx / aspect ? -1 : 1) < -.08 * torso) {
        return null;
      }
      angles.add(math.acos(((-ux * fx - uy * fy) / (u * f)).clamp(-1.0, 1.0)) *
          180 /
          math.pi);
      wrists.add((s.y - w.y) / torso);
      elbows.add((s.y - e.y) / torso);
      upper.add(u);
      forearms.add(f);
    }
    return ShoulderPressGeometry(
        List.unmodifiable(angles),
        List.unmodifiable(wrists),
        List.unmodifiable(elbows),
        List.unmodifiable(upper),
        List.unmodifiable(forearms),
        torso,
        shoulderWidth,
        sx,
        sy,
        hx,
        hy,
        frontal);
  }

  bool get neutral =>
      frontUpright &&
      angles.every((v) => v >= 70 && v <= 112) &&
      wristHeights.every((v) => v >= .22 && v <= .65) &&
      elbowHeights.every((v) => v >= -.25 && v <= .18);
  bool get overhead {
    for (var i = 0; i < 2; i++) {
      if (angles[i] < 155 ||
          wristHeights[i] * torsoLength <
              .75 * (upperLengths[i] + forearmLengths[i]) ||
          elbowHeights[i] * torsoLength < .65 * upperLengths[i]) {
        return false;
      }
    }
    return true;
  }

  bool get symmetric =>
      (angles[0] - angles[1]).abs() <= 28 &&
      (wristHeights[0] - wristHeights[1]).abs() <= .23;
  double distanceFrom(ShoulderPressGeometry other) =>
      math.max(
          math.sqrt(math.pow(centerX - other.centerX, 2) +
              math.pow(centerY - other.centerY, 2)),
          math.sqrt(math.pow(hipX - other.hipX, 2) +
              math.pow(hipY - other.hipY, 2))) /
      other.torsoLength;

  /// A press legitimately elevates the shoulders and changes projected limb
  /// lengths. Keep camera/body translation checks independent of moving arms.
  bool bodyStableFrom(ShoulderPressGeometry other) =>
      math.sqrt(math.pow(hipX - other.hipX, 2) +
                  math.pow(hipY - other.hipY, 2)) /
              other.torsoLength <=
          .20 &&
      (centerX - other.centerX).abs() / other.torsoLength <= .18 &&
      (centerY - other.centerY).abs() / other.torsoLength <= .32 &&
      (torsoLength / other.torsoLength - 1).abs() <= .28;
  bool stableFrom(ShoulderPressGeometry other, {bool calibration = false}) {
    if (distanceFrom(other) > (calibration ? .06 : .16) ||
        (torsoLength / other.torsoLength - 1).abs() >
            (calibration ? .07 : .18) ||
        (shoulderWidth / other.shoulderWidth - 1).abs() >
            (calibration ? .08 : .22)) {
      return false;
    }
    for (var i = 0; i < 2; i++) {
      if ((upperLengths[i] / other.upperLengths[i] - 1).abs() > .23 ||
          (forearmLengths[i] / other.forearmLengths[i] - 1).abs() > .23 ||
          (calibration && (angles[i] - other.angles[i]).abs() > 6)) {
        return false;
      }
    }
    return true;
  }
}
