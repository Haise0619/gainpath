import 'dart:math' as math;
import '../pose/pose_frame.dart';
import 'floor_push_up_rules.dart';
import 'floor_push_up_diagnostics.dart';

enum FloorPushUpSide { left, right }

enum FloorPushUpWorldStatus { absent, unreliable, consistent, contradictory }

class FloorPushUpGeometryObservation {
  FloorPushUpRejection rejection = FloorPushUpRejection.none;
  FloorPushUpWorldStatus worldStatus = FloorPushUpWorldStatus.absent;
  final Map<String, Object?> measurements = {};
  final Map<String, Object?> confidence = {};
  FloorPushUpGeometry? reject(FloorPushUpRejection reason) {
    rejection = reason;
    return null;
  }

  Map<String, Object?> toJson() => {
        'rejection': rejection.name,
        'worldStatus': worldStatus.name,
        'measurements': Map.of(measurements),
        'landmarkConfidence': Map.of(confidence)
      };
}

/// Image coordinates are aspect-corrected before geometry. World metres are
/// checked separately; normalized image z is never mixed with world z.
class FloorPushUpGeometry {
  FloorPushUpGeometry._(
      this.elbowAngleDegrees,
      this.bodyAngleDegrees,
      this.signedHipDisplacement,
      this.bodyLength,
      this.bodySlope,
      this.shoulderWidthRatio,
      this.confidence,
      this.kneeAngleDegrees,
      this.worldElbowAngleDegrees,
      this.worldBodyAngleDegrees,
      this.worldConsistent,
      this.wristX,
      this.wristY,
      this.ankleX,
      this.ankleY,
      this.upperArmLength,
      this.forearmLength,
      this.handBelowShoulder,
      this.worldStatus,
      this.bodyLengthShortSide,
      this.legacyScoreCompatible,
      this.worldProjectedElbowAngle,
      this.worldProjectedBodyAngle,
      this.worldBodyLength,
      this.worldMinimumConfidence);
  final double worldMinimumConfidence;
  final double bodyLengthShortSide;

  /// Newly countable portrait observations are not silently scored under the
  /// historical height-based evidence gate. A reviewed score contract can
  /// explicitly admit them later without pooling unlike evidence.
  final bool legacyScoreCompatible;
  final double? worldProjectedElbowAngle,
      worldProjectedBodyAngle,
      worldBodyLength;
  final double elbowAngleDegrees,
      bodyAngleDegrees,
      signedHipDisplacement,
      bodyLength,
      bodySlope,
      shoulderWidthRatio,
      confidence,
      wristX,
      wristY,
      ankleX,
      ankleY,
      upperArmLength,
      forearmLength,
      handBelowShoulder;
  final double? kneeAngleDegrees, worldElbowAngleDegrees, worldBodyAngleDegrees;
  final bool worldConsistent;
  final FloorPushUpWorldStatus worldStatus;
  static List<PoseLandmark> joints(FloorPushUpSide side) =>
      side == FloorPushUpSide.left
          ? const [
              PoseLandmark.leftShoulder,
              PoseLandmark.leftElbow,
              PoseLandmark.leftWrist,
              PoseLandmark.leftHip,
              PoseLandmark.leftAnkle
            ]
          : const [
              PoseLandmark.rightShoulder,
              PoseLandmark.rightElbow,
              PoseLandmark.rightWrist,
              PoseLandmark.rightHip,
              PoseLandmark.rightAnkle
            ];
  static bool _valid(PosePoint? p, {bool image = true}) =>
      p != null &&
      [p.x, p.y, p.z, p.visibility, p.presence ?? 1].every((v) => v.isFinite) &&
      p.visibility >= 0 &&
      p.visibility <= 1 &&
      (p.presence ?? 1) >= 0 &&
      (p.presence ?? 1) <= 1 &&
      (!image || (p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1));
  static double visibility(PoseFrame f, FloorPushUpSide side) {
    if (f.isMirrored || f.imageWidth <= 0 || f.imageHeight <= 0) return 0;
    var v = f.posePresence ?? 1.0;
    if (!v.isFinite || v < 0 || v > 1) return 0;
    for (final id in joints(side)) {
      final p = f.landmark(id);
      if (!_valid(p)) return 0;
      v = math.min(v, math.min(p!.visibility, p.presence ?? 1));
    }
    return v;
  }

  static double _distance(PosePoint a, PosePoint b, double ratio, bool world) =>
      math.sqrt(math.pow((a.x - b.x) * ratio, 2) +
          math.pow(a.y - b.y, 2) +
          (world ? math.pow(a.z - b.z, 2) : 0));
  static double? _angle(
      PosePoint a, PosePoint b, PosePoint c, double ratio, bool world) {
    final ax = (a.x - b.x) * ratio,
        ay = a.y - b.y,
        az = world ? a.z - b.z : 0.0,
        cx = (c.x - b.x) * ratio,
        cy = c.y - b.y,
        cz = world ? c.z - b.z : 0.0;
    final len = _distance(a, b, ratio, world) * _distance(c, b, ratio, world);
    if (len < 1e-8) return null;
    return math.acos(((ax * cx + ay * cy + az * cz) / len).clamp(-1.0, 1.0)) *
        180 /
        math.pi;
  }

  static FloorPushUpGeometry? fromFrame(PoseFrame f, FloorPushUpSide side,
      {FloorPushUpRules? rules, FloorPushUpGeometryObservation? observation}) {
    final o = observation ?? FloorPushUpGeometryObservation();
    final r = rules ?? FloorPushUpRules(), confidence = visibility(f, side);
    o.measurements.addAll({
      'imageWidth': f.imageWidth,
      'imageHeight': f.imageHeight,
      'isMirrored': f.isMirrored,
      'posePresence': f.posePresence,
      'primaryConfidence': confidence,
      'poseDetected': f.landmarks.isNotEmpty,
      'coordinateSpace': 'upright-unmirrored-image',
    });
    if (f.imageWidth <= 0 || f.imageHeight <= 0) {
      return o.reject(FloorPushUpRejection.invalidImage);
    }
    if (f.isMirrored) return o.reject(FloorPushUpRejection.mirroredInput);
    if (f.landmarks.isEmpty) return o.reject(FloorPushUpRejection.noPose);
    for (final id in joints(side)) {
      final p = f.landmark(id);
      o.confidence[id.name] = {
        'visibility': p?.visibility,
        'presence': p?.presence
      };
    }
    if (!(f.posePresence ?? 1).isFinite ||
        (f.posePresence ?? 1) < r.minimumVisibility) {
      return o.reject(FloorPushUpRejection.lowPoseConfidence);
    }
    if (confidence < r.minimumVisibility) {
      final points = joints(side).map(f.landmark).toList();
      if (points.any((p) => p == null)) {
        return o.reject(FloorPushUpRejection.missingLandmark);
      }
      if (points.any((p) => p!.x < 0 || p.x > 1 || p.y < 0 || p.y > 1)) {
        return o.reject(FloorPushUpRejection.outsideImage);
      }
      return o.reject(FloorPushUpRejection.lowLandmarkConfidence);
    }
    final j = joints(side), p = j.map((id) => f.landmark(id)!).toList();
    final s = p[0], e = p[1], w = p[2], h = p[3], a = p[4];
    final ratio = f.imageWidth / f.imageHeight;
    final dx = (a.x - s.x) * ratio, dy = a.y - s.y;
    final len = _distance(s, a, ratio, false);
    final pixelLength = len * f.imageHeight;
    final shortSide = math.min(f.imageWidth, f.imageHeight).toDouble();
    final shortRatio = pixelLength / shortSide;
    final elbow = _angle(s, e, w, ratio, false),
        body = _angle(s, h, a, ratio, false);
    o.measurements.addAll({
      'bodyLength': len,
      'bodyLengthHeight': len,
      'bodyLengthPixels': pixelLength,
      'bodyLengthShortSide': shortRatio,
      'bodyLengthThreshold': r.minimumBodyLength,
      'bodyLengthNormalization': 'short-image-side',
      'shortImageSidePixels': shortSide,
      'elbow2d': elbow,
      'bodyAngle2d': body,
      'legacyScoreCompatible': len >= r.minimumBodyLength
    });
    if (shortRatio < r.minimumBodyLength) {
      return o.reject(FloorPushUpRejection.bodyTooSmall);
    }
    if (dx.abs() < 1e-6) return o.reject(FloorPushUpRejection.degenerateBody);
    final upper = _distance(s, e, ratio, false),
        fore = _distance(e, w, ratio, false);
    if (elbow == null ||
        body == null ||
        upper < len * .08 ||
        fore < len * .08 ||
        upper > len * .65 ||
        fore > len * .65) {
      return o.reject(FloorPushUpRejection.armGeometry);
    }
    final projection =
        (((h.x - s.x) * ratio * dx + (h.y - s.y) * dy) / (len * len));
    o.measurements.addAll({
      'elbow2d': elbow,
      'bodyAngle2d': body,
      'upperArmLength': upper,
      'forearmLength': fore,
      'hipProjection': projection
    });
    if (projection < .15 || projection > .85) {
      return o.reject(FloorPushUpRejection.hipProjection);
    }
    // Normal points toward image-down regardless of which way the person faces.
    final displacement =
        ((h.y - s.y) - (h.x - s.x) * ratio * dy / dx) * dx.abs() / (len * len);
    final other = f.landmark(side == FloorPushUpSide.left
        ? PoseLandmark.rightShoulder
        : PoseLandmark.leftShoulder);
    // Side-view evidence cannot be manufactured from a single isolated arm.
    if (!_valid(other) ||
        other!.visibility < .35 ||
        (other.presence ?? 1) < .35) {
      return o.reject(FloorPushUpRejection.farShoulderUnavailable);
    }
    final shoulderWidth = _distance(s, other, ratio, false) / len;
    final k = f.landmark(side == FloorPushUpSide.left
        ? PoseLandmark.leftKnee
        : PoseLandmark.rightKnee);
    final knee = _valid(k) &&
            k!.visibility >= r.minimumVisibility &&
            (k.presence ?? 1) >= r.minimumVisibility
        ? _angle(h, k, a, ratio, false)
        : null;
    o.measurements.addAll({
      'kneeRawAngle': _valid(k) ? _angle(h, k!, a, ratio, false) : null,
      'kneeAngle': knee,
      'kneeVisibility': k?.visibility,
      'kneePresence': k?.presence,
      'kneeSupportThreshold': 125,
      'kneeSide': side.name,
    });
    double? we, wb, projectedElbow, projectedBody, worldLength;
    var worldConfidence = 0.0;
    var consistent = true;
    var worldStatus = FloorPushUpWorldStatus.absent;
    if (f.worldLandmarks.isNotEmpty) {
      final wp = j.map((id) => f.worldLandmarks[id]).toList();
      if (wp.every((v) =>
          _valid(v, image: false) &&
          v!.visibility >= r.minimumVisibility &&
          (v.presence ?? 1) >= r.minimumVisibility)) {
        worldConfidence = wp.fold(
            1.0,
            (value, p) =>
                math.min(value, math.min(p!.visibility, p.presence ?? 1)));
        we = _angle(wp[0]!, wp[1]!, wp[2]!, 1, true);
        wb = _angle(wp[0]!, wp[3]!, wp[4]!, 1, true);
        worldLength = _distance(wp[0]!, wp[4]!, 1, true);
        projectedElbow = _angle(wp[0]!, wp[1]!, wp[2]!, 1, false);
        projectedBody = _angle(wp[0]!, wp[3]!, wp[4]!, 1, false);
        consistent = we != null &&
            wb != null &&
            projectedElbow != null &&
            projectedBody != null &&
            worldLength >= .25 &&
            worldLength <= 3 &&
            (we - elbow).abs() <= r.worldAngleTolerance &&
            (wb - body).abs() <= r.worldAngleTolerance &&
            (projectedElbow - elbow).abs() <= r.worldAngleTolerance &&
            (projectedBody - body).abs() <= r.worldAngleTolerance;
        // Visibility is copied from IMAGE landmarks by the adapter; it is not
        // a confidence estimate for inferred depth. A 3D-vs-2D angle difference
        // alone is not a contradiction. Require disagreement in both spaces.
        final comparable = we != null &&
            wb != null &&
            projectedElbow != null &&
            projectedBody != null &&
            worldLength >= .25 &&
            worldLength <= 3;
        final contradictory = comparable &&
            (((we - elbow).abs() > r.worldAngleTolerance &&
                    (projectedElbow - elbow).abs() > r.worldAngleTolerance) ||
                ((wb - body).abs() > r.worldAngleTolerance &&
                    (projectedBody - body).abs() > r.worldAngleTolerance));
        worldStatus = consistent
            ? FloorPushUpWorldStatus.consistent
            : contradictory
                ? FloorPushUpWorldStatus.contradictory
                : FloorPushUpWorldStatus.unreliable;
      } else {
        consistent = false;
        worldStatus = FloorPushUpWorldStatus.unreliable;
      }
    }
    o.worldStatus = worldStatus;
    o.measurements.addAll({
      'elbowWorld': we,
      'bodyAngleWorld': wb,
      'worldAgreement': consistent,
      'worldProjectedElbow': projectedElbow,
      'worldProjectedBody': projectedBody,
      'worldMinimumConfidence': worldConfidence,
      'worldBodyLength': worldLength,
      'worldConfidenceIndependent': false,
      'worldElbowDisagreement': we == null ? null : (we - elbow).abs(),
      'worldProjectedElbowDisagreement':
          projectedElbow == null ? null : (projectedElbow - elbow).abs(),
      'signedHipDisplacement': displacement,
      'bodySlope': dy.abs() / dx.abs(),
      'shoulderWidthRatio': shoulderWidth,
      'handBelowShoulder': (w.y - s.y) / len,
      'kneeAngle': knee
    });
    final result = FloorPushUpGeometry._(
        elbow,
        body,
        displacement,
        len,
        dy.abs() / dx.abs(),
        shoulderWidth,
        confidence,
        knee,
        we,
        wb,
        consistent,
        w.x * ratio,
        w.y,
        a.x * ratio,
        a.y,
        upper,
        fore,
        (w.y - s.y) / len,
        worldStatus,
        shortRatio,
        len >= r.minimumBodyLength,
        projectedElbow,
        projectedBody,
        worldLength,
        worldConfidence);
    o.rejection = result.rejection(r);
    return result;
  }

  FloorPushUpRejection imageRejection(FloorPushUpRules r) {
    if (bodySlope > r.maximumBodySlope) {
      return FloorPushUpRejection.bodyNotHorizontal;
    }
    if (shoulderWidthRatio > r.maximumShoulderWidthRatio) {
      return FloorPushUpRejection.notSideView;
    }
    if (handBelowShoulder <= .05) return FloorPushUpRejection.wristPosition;
    if (kneeAngleDegrees != null && kneeAngleDegrees! < 125) {
      return FloorPushUpRejection.kneeSupport;
    }
    return FloorPushUpRejection.none;
  }

  FloorPushUpRejection rejection(FloorPushUpRules r) {
    final image = imageRejection(r);
    if (image != FloorPushUpRejection.none) return image;
    if (!worldConsistent) {
      return worldStatus == FloorPushUpWorldStatus.unreliable
          ? FloorPushUpRejection.unreliableWorld
          : FloorPushUpRejection.contradictoryWorld;
    }
    return FloorPushUpRejection.none;
  }

  // Optional world estimates cannot veto sound image tracking merely because
  // they are incomplete/low-confidence. Such attempts remain unscored.
  bool usableView(FloorPushUpRules r) => const {
        FloorPushUpRejection.none,
        FloorPushUpRejection.unreliableWorld
      }.contains(rejection(r));
}
