import 'dart:math' as math;
import '../pose/pose_frame.dart';
import 'floor_push_up_geometry.dart';
import 'floor_push_up_rules.dart';

/// A TOP projection is not a bone-length measurement. A baseline departure may
/// be accepted for 2D counting only when a fresh accepted trajectory and usable
/// world-XY projection support it. Such evidence never authorizes a form score.
class FloorPushUpProjectionEvidence {
  static const revision = 'floor-projected-limb-trajectory-v1';
  static const minimumConfidence = .85;
  static const maximumImageJointStep = .12;
  static const maximumWorldXYJointStep = .18;
  _ProjectionSample? _last;
  final Map<String, Object?> diagnostics = {};
  void reset() {
    _last = null;
    diagnostics.clear();
  }

  bool validate(PoseFrame f, FloorPushUpSide side, FloorPushUpGeometry g,
      int now, FloorPushUpRules rules) {
    final p = _last, c = _ProjectionSample.from(f, side, g, now, rules);
    diagnostics.clear();
    diagnostics.addAll({
      'projectionPolicy': revision,
      'trajectoryMinimumConfidence': minimumConfidence,
      'trajectoryImageStepLimit': maximumImageJointStep,
      'trajectoryWorldXYStepLimit': maximumWorldXYJointStep
    });
    bool reject(String reason) {
      diagnostics['trajectoryValidation'] = reason;
      return false;
    }

    if (p == null) return reject('no_accepted_predecessor');
    final captureGap = f.capturedAtMicros - p.capture,
        deliveryGap = now - p.delivery;
    diagnostics.addAll({
      'trajectoryCaptureGapMicros': captureGap,
      'trajectoryDeliveryGapMicros': deliveryGap
    });
    if (c.source != p.source) return reject('source_changed');
    if (captureGap <= 0 ||
        captureGap > rules.maximumFrameAgeMicros ||
        deliveryGap < 0 ||
        deliveryGap > rules.maximumFrameAgeMicros) {
      return reject('trajectory_expired');
    }
    if (c.confidence < minimumConfidence || p.confidence < minimumConfidence) {
      return reject('trajectory_low_confidence');
    }
    final upper = (c.upper / p.upper - 1).abs(),
        fore = (c.fore / p.fore - 1).abs();
    final imageStep = _step(c.image, p.image) / p.body;
    diagnostics.addAll({
      'upperArmTemporalChange': upper,
      'forearmTemporalChange': fore,
      'trajectoryImageJointStep': imageStep,
      'trajectoryElbowSpeed': (c.angle - p.angle).abs() * 1e6 / captureGap
    });
    if (upper > rules.maximumLimbChange + 1e-9 ||
        fore > rules.maximumLimbChange + 1e-9) {
      return reject('abrupt_segment_change');
    }
    if (imageStep > maximumImageJointStep) return reject('abrupt_joint_motion');
    if ((c.angle - p.angle).abs() * 1e6 / captureGap >
        rules.maximumAngularSpeed) {
      return reject('abrupt_elbow_motion');
    }
    if (c.bend * p.bend <= 0) return reject('elbow_orientation_changed');
    if (c.worldXY == null || p.worldXY == null) {
      return reject('world_xy_unreliable');
    }
    final worldStep = _step(c.worldXY!, p.worldXY!);
    diagnostics['trajectoryWorldXYJointStep'] = worldStep;
    if (worldStep > maximumWorldXYJointStep) {
      return reject('world_xy_motion_disagrees');
    }
    diagnostics['trajectoryValidation'] = 'validated';
    return true;
  }

  // Rejected observations can never seed/advance this trajectory.
  void accept(PoseFrame f, FloorPushUpSide side, FloorPushUpGeometry g, int now,
      FloorPushUpRules rules) {
    _last = _ProjectionSample.from(f, side, g, now, rules);
  }

  static double _step(List<(double, double)> a, List<(double, double)> b) {
    var maximum = 0.0;
    for (var i = 0; i < a.length; i++) {
      maximum = math.max(
          maximum,
          math.sqrt(
              math.pow(a[i].$1 - b[i].$1, 2) + math.pow(a[i].$2 - b[i].$2, 2)));
    }
    return maximum;
  }
}

class _ProjectionSample {
  _ProjectionSample(
      this.source,
      this.capture,
      this.delivery,
      this.confidence,
      this.upper,
      this.fore,
      this.body,
      this.angle,
      this.bend,
      this.image,
      this.worldXY);
  final String source;
  final int capture, delivery;
  final double confidence, upper, fore, body, angle, bend;
  final List<(double, double)> image;
  final List<(double, double)>? worldXY;
  factory _ProjectionSample.from(PoseFrame f, FloorPushUpSide side,
      FloorPushUpGeometry g, int now, FloorPushUpRules rules) {
    final ids = FloorPushUpGeometry.joints(side);
    final image = ids.map((k) {
      final p = f.landmark(k)!;
      return (p.x * f.imageWidth / f.imageHeight, p.y);
    }).toList();
    final s = image[0], e = image[1], w = image[2];
    final bend = (s.$1 - e.$1) * (w.$2 - e.$2) - (s.$2 - e.$2) * (w.$1 - e.$1);
    List<(double, double)>? world;
    // Image visibility copied into world landmarks is not independent depth
    // confidence. Use XY only; retain the analyzer's separate 3D veto policy.
    if (g.worldMinimumConfidence >=
            FloorPushUpProjectionEvidence.minimumConfidence &&
        g.worldBodyLength != null &&
        g.worldBodyLength! >= .25 &&
        g.worldBodyLength! <= 3 &&
        g.worldProjectedElbowAngle != null &&
        g.worldProjectedBodyAngle != null &&
        (g.worldProjectedElbowAngle! - g.elbowAngleDegrees).abs() <=
            rules.worldAngleTolerance &&
        (g.worldProjectedBodyAngle! - g.bodyAngleDegrees).abs() <=
            rules.worldAngleTolerance) {
      final points = ids.map((k) => f.worldLandmarks[k]!).toList();
      final root = points[0], ankle = points[4];
      final length = math
          .sqrt(math.pow(ankle.x - root.x, 2) + math.pow(ankle.y - root.y, 2));
      if (length > 1e-6) {
        world = points
            .map((p) => ((p.x - root.x) / length, (p.y - root.y) / length))
            .toList();
      }
    }
    return _ProjectionSample(
        '${f.detectorId}/${f.modelVersion}/${f.imageWidth}/${f.imageHeight}/${side.name}',
        f.capturedAtMicros,
        now,
        g.confidence,
        g.upperArmLength,
        g.forearmLength,
        g.bodyLength,
        g.elbowAngleDegrees,
        bend,
        image,
        world);
  }
}
