import 'dart:math' as math;
import '../pose/pose_frame.dart';
import 'squat_geometry.dart';

enum WorldKneeStatus {
  available,
  missingLandmark,
  lowConfidence,
  invalidConfidence,
  nonfiniteCoordinate,
  degenerateSegment,
  invalidGeometry,
  mirroredFrame,
  frameMismatch;

  String get wire =>
      name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}

/// A model-estimated world angle, not an anatomical ground-truth claim.
final class WorldKneeAngle {
  const WorldKneeAngle._(this.angleDegrees, this.status);
  const WorldKneeAngle.unavailable(this.status) : angleDegrees = null;
  final double? angleDegrees;
  final WorldKneeStatus status;
  static WorldKneeAngle measure(PoseFrame frame, SquatSide side,
      {double minimumConfidence = .7}) {
    if (!minimumConfidence.isFinite ||
        minimumConfidence <= 0 ||
        minimumConfidence > 1) {
      return const WorldKneeAngle.unavailable(
          WorldKneeStatus.invalidConfidence);
    }
    if (frame.isMirrored) {
      return const WorldKneeAngle.unavailable(WorldKneeStatus.mirroredFrame);
    }
    final pose = frame.posePresence ?? 1.0;
    if (!pose.isFinite || pose < 0 || pose > 1) {
      return const WorldKneeAngle.unavailable(
          WorldKneeStatus.invalidConfidence);
    }
    if (pose < minimumConfidence) {
      return const WorldKneeAngle.unavailable(WorldKneeStatus.lowConfidence);
    }
    final keys = side == SquatSide.left
        ? const [
            PoseLandmark.leftHip,
            PoseLandmark.leftKnee,
            PoseLandmark.leftAnkle
          ]
        : const [
            PoseLandmark.rightHip,
            PoseLandmark.rightKnee,
            PoseLandmark.rightAnkle
          ];
    final points = <PosePoint>[];
    for (final key in keys) {
      final p = frame.worldLandmarks[key];
      if (p == null) {
        return const WorldKneeAngle.unavailable(
            WorldKneeStatus.missingLandmark);
      }
      if (![p.x, p.y, p.z].every((v) => v.isFinite)) {
        return const WorldKneeAngle.unavailable(
            WorldKneeStatus.nonfiniteCoordinate);
      }
      final confidence = [p.visibility, p.presence ?? 1.0];
      if (!confidence.every((v) => v.isFinite && v >= 0 && v <= 1)) {
        return const WorldKneeAngle.unavailable(
            WorldKneeStatus.invalidConfidence);
      }
      if (confidence.any((v) => v < minimumConfidence)) {
        return const WorldKneeAngle.unavailable(WorldKneeStatus.lowConfidence);
      }
      points.add(p);
    }
    final h = points[0], k = points[1], a = points[2];
    final u = [h.x - k.x, h.y - k.y, h.z - k.z],
        v = [a.x - k.x, a.y - k.y, a.z - k.z];
    double norm(List<double> xyz) =>
        math.sqrt(xyz.fold<double>(0, (s, x) => s + x * x));
    final un = norm(u), vn = norm(v);
    if (!un.isFinite || !vn.isFinite) {
      return const WorldKneeAngle.unavailable(WorldKneeStatus.invalidGeometry);
    }
    // Metres, not the image-space one-pixel degeneracy threshold.
    if (un <= 1e-9 || vn <= 1e-9) {
      return const WorldKneeAngle.unavailable(
          WorldKneeStatus.degenerateSegment);
    }
    var dot = 0.0;
    for (var i = 0; i < 3; i++) {
      dot += (u[i] / un) * (v[i] / vn);
    }
    if (!dot.isFinite) {
      return const WorldKneeAngle.unavailable(WorldKneeStatus.invalidGeometry);
    }
    return WorldKneeAngle._(math.acos(dot.clamp(-1.0, 1.0)) * 180 / math.pi,
        WorldKneeStatus.available);
  }
}

/// Scalar pair. Input frames are read during calculation, never retained.
final class SquatAngleComparison {
  const SquatAngleComparison._(this.time, this.side, this.sameFrame,
      this.raw2dDegrees, this.filtered2dDegrees, this.raw3d, this.filtered3d);
  final int time;
  final SquatSide side;
  final bool sameFrame;
  final double? raw2dDegrees, filtered2dDegrees;
  final WorldKneeAngle raw3d, filtered3d;
  bool matches(int captureTime, SquatSide evaluatedSide) =>
      sameFrame && time == captureTime && side == evaluatedSide;
  factory SquatAngleComparison.fromFrames(
      PoseFrame raw, PoseFrame filtered, SquatSide side,
      {double minimumConfidence = .7}) {
    final matched = raw.capturedAtMicros == filtered.capturedAtMicros &&
        raw.detectorId == filtered.detectorId &&
        raw.modelVersion == filtered.modelVersion &&
        raw.imageWidth == filtered.imageWidth &&
        raw.imageHeight == filtered.imageHeight &&
        raw.isMirrored == filtered.isMirrored &&
        raw.posePresence == filtered.posePresence;
    if (!matched) {
      return SquatAngleComparison._(
          raw.capturedAtMicros,
          side,
          false,
          null,
          null,
          const WorldKneeAngle.unavailable(WorldKneeStatus.frameMismatch),
          const WorldKneeAngle.unavailable(WorldKneeStatus.frameMismatch));
    }
    double? imageAngle(PoseFrame f) =>
        SquatGeometry.confidence(f, side) >= minimumConfidence
            ? SquatGeometry.fromFrame(f, side)?.kneeAngleDegrees
            : null;
    return SquatAngleComparison._(
        raw.capturedAtMicros,
        side,
        true,
        imageAngle(raw),
        imageAngle(filtered),
        WorldKneeAngle.measure(raw, side, minimumConfidence: minimumConfidence),
        WorldKneeAngle.measure(filtered, side,
            minimumConfidence: minimumConfidence));
  }
}
