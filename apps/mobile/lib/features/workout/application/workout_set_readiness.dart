import 'dart:math' as math;

import 'package:gainpath_pose/gainpath_pose.dart';

import 'workout_set_continuation.dart';

/// Isolated calibration during preparation. No counts, timings, form scores,
/// or audio from these analyzers enter the live workout.
abstract final class WorkoutSetReadiness {
  static SetReadinessProbe squat(SquatSide? side) {
    final analyzer = SquatAnalyzer(preferredSide: side);
    return (frame, now) {
      if (!_uprightProfile(frame)) {
        analyzer.pause();
        analyzer.resume();
        return false;
      }
      final pose = analyzer.update(frame, nowMicros: now);
      return !pose.needsCalibration &&
          pose.health == TrackingStatus.healthy &&
          pose.phase == SquatPhase.ready &&
          (pose.geometry?.kneeAngleDegrees ?? 0) >=
              analyzer.rules.readyAngleDegrees;
    };
  }

  static SetReadinessProbe curl(CurlSide side) {
    final analyzer = CurlAnalyzer(side: side);
    return (frame, now) {
      if (!_uprightProfile(frame)) {
        analyzer.pause();
        return false;
      }
      final pose = analyzer.update(frame, nowMicros: now);
      final geometry = pose.geometry;
      return !pose.needsCalibration &&
          pose.health == TrackingStatus.healthy &&
          pose.phase == CurlPhase.ready &&
          geometry != null &&
          geometry.elbowAngleDegrees >= 150 &&
          geometry.upperArmDegrees.abs() <= 30 &&
          geometry.trunkDegrees.abs() <= 15;
    };
  }

  static SetReadinessProbe calf(CalfSide? side) {
    final analyzer = CalfRaiseAnalyzer();
    return (frame, now) {
      final candidate = side ??
          (CalfRaiseGeometry.confidence(frame, CalfSide.left) >=
                  CalfRaiseGeometry.confidence(frame, CalfSide.right)
              ? CalfSide.left
              : CalfSide.right);
      final joints = CalfRaiseGeometry.joints(candidate);
      if (!_profile(frame, PoseLandmark.leftHip, PoseLandmark.rightHip,
          joints[1], joints[2])) {
        analyzer.pause();
        return false;
      }
      final pose = analyzer.update(frame, nowMicros: now);
      final selected = pose.selectedSide;
      if (selected != candidate) return false;
      return !pose.needsCalibration &&
          pose.health == TrackingStatus.healthy &&
          pose.phase == CalfRaisePhase.ready &&
          !pose.requiresHeelReset &&
          pose.decision == 'ready' &&
          (CalfRaiseGeometry.fromFrame(frame, candidate)?.kneeAngleDegrees ??
                  0) >=
              165;
    };
  }

  static SetReadinessProbe floor(
      FloorPushUpSide? side, FloorPushUpRules rules) {
    final analyzer = FloorPushUpAnalyzer(rules: rules);
    return (frame, now) {
      final pose = analyzer.update(frame, nowMicros: now);
      return pose.observationAccepted &&
          pose.health == TrackingStatus.healthy &&
          pose.phase == FloorPushUpPhase.top &&
          (side == null || pose.selectedSide == side) &&
          (pose.geometry?.elbowAngleDegrees ?? 0) >= rules.topAngle;
    };
  }

  static SetReadinessProbe lateral() {
    final analyzer = LateralRaiseAnalyzer();
    return (frame, now) {
      final pose = analyzer.update(frame, nowMicros: now);
      final geometry = LateralRaiseGeometry.fromFrame(frame);
      return !pose.needsCalibration &&
          pose.health == TrackingStatus.healthy &&
          pose.phase == LateralRaisePhase.ready &&
          !pose.requiresBottomReset &&
          geometry != null &&
          geometry.neutral &&
          geometry.symmetric;
    };
  }

  static SetReadinessProbe press() {
    final analyzer = ShoulderPressAnalyzer();
    return (frame, now) {
      final pose = analyzer.update(frame, nowMicros: now);
      final geometry = ShoulderPressGeometry.fromFrame(frame);
      return !pose.needsCalibration &&
          pose.health == TrackingStatus.healthy &&
          pose.phase == ShoulderPressPhase.ready &&
          !pose.requiresBottomReset &&
          geometry != null &&
          geometry.neutral &&
          geometry.symmetric;
    };
  }

  static bool _uprightProfile(PoseFrame frame) =>
      _profile(frame, PoseLandmark.leftShoulder, PoseLandmark.rightShoulder,
          PoseLandmark.leftShoulder, PoseLandmark.leftHip) &&
      _profile(frame, PoseLandmark.leftHip, PoseLandmark.rightHip,
          PoseLandmark.rightShoulder, PoseLandmark.rightHip);

  /// Conservative projected view evidence for automatic start only. Side-view
  /// rep analyzers can use one visible flank, but that alone cannot establish
  /// a side profile. Manual start remains available with ambiguous framing.
  static bool _profile(
      PoseFrame frame,
      PoseLandmark acrossLeft,
      PoseLandmark acrossRight,
      PoseLandmark segmentTop,
      PoseLandmark segmentEnd) {
    if (frame.imageWidth <= 0 || frame.imageHeight <= 0) return false;
    final points = [acrossLeft, acrossRight, segmentTop, segmentEnd]
        .map((joint) => frame.landmarks[joint])
        .toList();
    if (points.any((p) =>
        p == null ||
        !p.x.isFinite ||
        !p.y.isFinite ||
        !(p.visibility >= .5) ||
        !((p.presence ?? 1) >= .5))) {
      return false;
    }
    double separation(PosePoint a, PosePoint b) {
      final x = (a.x - b.x) * frame.imageWidth;
      final y = (a.y - b.y) * frame.imageHeight;
      return math.sqrt(x * x + y * y);
    }

    final segment = separation(points[2]!, points[3]!);
    return segment > 0 && separation(points[0]!, points[1]!) / segment <= .35;
  }
}
