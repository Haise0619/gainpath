import 'dart:math' as math;
import 'dart:typed_data';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'blazepose_geometry.dart';

/// Bounded same-input scalar comparison. Never retains tensors or coordinates.
/// Limits are provisional diagnostic gates, not clinical accuracy claims.
class PoseBackendAgreement {
  PoseBackendAgreement({this.limit = 12});
  final int limit;
  int fullBodyPairs = 0;
  int frames = 0,
      nonfinite = 0,
      flips = 0,
      boundaryFlips = 0,
      poseFlips = 0,
      roiFlips = 0;
  double pixels = 0, world = 0, confidence = 0, roiPixels = 0, roiAngle = 0;
  final _tensorMax = <String, double>{};
  bool get complete => frames >= limit;

  void observeTensor(String key, Float32List cpu, Float32List gpu) {
    if (complete) return;
    if (cpu.length != gpu.length) throw ArgumentError('Tensor length mismatch');
    var max = 0.0;
    for (var i = 0; i < cpu.length; i++) {
      if (!cpu[i].isFinite || !gpu[i].isFinite) {
        nonfinite++;
        continue;
      }
      max = math.max(max, (cpu[i] - gpu[i]).abs());
    }
    _tensorMax.update(key, (v) => math.max(v, max), ifAbsent: () => max);
  }

  void observeRoi(TensorImageTransform? cpu, TensorImageTransform? gpu) {
    if (complete) return;
    if (cpu == null || gpu == null) {
      if ((cpu == null) != (gpu == null)) roiFlips++;
      return;
    }
    roiPixels = math.max(
        roiPixels,
        math.max(
            math.sqrt(math.pow(cpu.centerX - gpu.centerX, 2) +
                math.pow(cpu.centerY - gpu.centerY, 2)),
            (cpu.side - gpu.side).abs()));
    var delta = (cpu.rotation - gpu.rotation).abs() % (2 * math.pi);
    delta = math.min(delta, 2 * math.pi - delta);
    roiAngle = math.max(roiAngle, delta * 180 / math.pi);
  }

  void observeFrames(PoseFrame cpu, PoseFrame gpu) {
    if (complete) return;
    if (cpu.capturedAtMicros != gpu.capturedAtMicros ||
        cpu.imageWidth != gpu.imageWidth ||
        cpu.imageHeight != gpu.imageHeight ||
        cpu.modelVersion != gpu.modelVersion ||
        cpu.isMirrored != gpu.isMirrored) {
      throw ArgumentError(
          'Agreement requires same timestamp and coordinate space');
    }
    frames++;
    bool finite(PosePoint p) =>
        [p.x, p.y, p.z, p.visibility, p.presence ?? 1].every((v) => v.isFinite);
    bool accepted(PosePoint p) =>
        finite(p) && p.visibility >= .5 && (p.presence ?? 1) >= .5;
    if ([11, 12, 23, 24, 25, 26, 27, 28].every((i) {
      final a = cpu.landmarks[PoseLandmark.values[i]],
          b = gpu.landmarks[PoseLandmark.values[i]];
      return a != null && b != null && accepted(a) && accepted(b);
    })) {
      fullBodyPairs++;
    }
    if (![(cpu.posePresence ?? 0), (gpu.posePresence ?? 0)]
        .every((v) => v.isFinite)) {
      nonfinite++;
      return;
    }
    confidence = math.max(
        confidence, ((cpu.posePresence ?? 0) - (gpu.posePresence ?? 0)).abs());
    if (cpu.landmarks.isEmpty != gpu.landmarks.isEmpty) poseFlips++;
    for (final joint in PoseLandmark.values) {
      final a = cpu.landmarks[joint], b = gpu.landmarks[joint];
      if (a == null || b == null) {
        continue;
      }
      if (!finite(a) || !finite(b)) {
        nonfinite++;
        continue;
      }
      pixels = math.max(
          pixels,
          math.sqrt(math.pow((a.x - b.x) * cpu.imageWidth, 2) +
              math.pow((a.y - b.y) * cpu.imageHeight, 2)));
      confidence = math.max(
          confidence,
          math.max((a.visibility - b.visibility).abs(),
              ((a.presence ?? 1) - (b.presence ?? 1)).abs()));
      if (accepted(a) != accepted(b)) {
        flips++;
        if ([a.visibility, b.visibility, a.presence ?? 1, b.presence ?? 1]
            .any((v) => (v - .5).abs() <= .01)) {
          boundaryFlips++;
        }
      }
      final wa = cpu.worldLandmarks[joint], wb = gpu.worldLandmarks[joint];
      if (wa != null && wb != null && finite(wa) && finite(wb)) {
        world = math.max(
            world,
            math.sqrt(math.pow(wa.x - wb.x, 2) +
                math.pow(wa.y - wb.y, 2) +
                math.pow(wa.z - wb.z, 2)));
      }
    }
  }

  Map<String, Object> get snapshot => {
        'framePairs': frames,
        'fullBodyAcceptedPairs': fullBodyPairs,
        'limit': limit,
        'complete': complete,
        'nonfiniteValues': nonfinite,
        'tensorMaxAbsoluteDifference': Map.of(_tensorMax),
        'maxImagePixelDistance': pixels,
        'maxWorldMetreDistance': world,
        'maxConfidenceDifference': confidence,
        'acceptanceFlips': flips,
        'boundaryAcceptanceFlips': boundaryFlips,
        'wholePoseFlips': poseFlips,
        'roiAvailabilityFlips': roiFlips,
        'maxRoiPixelDifference': roiPixels,
        'maxRoiAngleDegrees': roiAngle,
        'withinProvisionalLimits': nonfinite == 0 &&
            poseFlips == 0 &&
            flips == 0 &&
            roiFlips == 0 &&
            pixels <= 1 &&
            world <= .001 &&
            confidence <= .001 &&
            roiPixels <= 1 &&
            roiAngle <= .5,
        'performanceExcludedWhileComparing': true
      };
}
