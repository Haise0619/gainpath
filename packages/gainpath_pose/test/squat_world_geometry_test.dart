import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'squat_analyzer_test.dart' as fixture;

PoseFrame worldFrame(
    {double degrees = 90,
    int time = 100,
    String model = 'analytic-v1',
    int width = 640,
    bool missing = false,
    double confidence = .95,
    double poseConfidence = .95,
    bool mirrored = false,
    bool nonfinite = false,
    bool degenerate = false,
    List<double> Function(List<double>)? transform}) {
  final image = fixture.sample(time, 175, width: width, mirrored: mirrored);
  PosePoint p(List<double> xyz) {
    final q = transform?.call(xyz) ?? xyz;
    return PosePoint(
        x: q[0],
        y: q[1],
        z: q[2],
        visibility: confidence,
        presence: confidence);
  }

  final radians = degrees * math.pi / 180;
  return PoseFrame(
      capturedAtMicros: time,
      detectorId: image.detectorId,
      modelVersion: model,
      imageWidth: width,
      imageHeight: 720,
      isMirrored: mirrored,
      posePresence: poseConfidence,
      landmarks: image.landmarks,
      worldLandmarks: {
        PoseLandmark.leftHip: p(degenerate ? [0, 0, 0] : [-.4, 0, 0]),
        PoseLandmark.leftKnee: p([0, 0, 0]),
        if (!missing)
          PoseLandmark.leftAnkle: p([
            -.4 * math.cos(radians),
            0,
            nonfinite ? double.nan : .4 * math.sin(radians)
          ]),
        PoseLandmark.rightHip: p([0, -.3, 0]),
        PoseLandmark.rightKnee: p([0, 0, 0]),
        PoseLandmark.rightAnkle:
            p([.3 * math.sin(math.pi / 3), -.3 * math.cos(math.pi / 3), 0]),
      });
}

void main() {
  test(
      'estimated world knee angles use complete XYZ, metres and anatomical side',
      () {
    for (final a in [45.0, 90.0, 135.0, 175.0]) {
      final result =
          WorldKneeAngle.measure(worldFrame(degrees: a), SquatSide.left);
      expect(result.angleDegrees, closeTo(a, 1e-8));
      expect(result.status, WorldKneeStatus.available);
    }
    expect(WorldKneeAngle.measure(worldFrame(), SquatSide.right).angleDegrees,
        closeTo(60, 1e-8));
    final f = worldFrame();
    expect(SquatGeometry.fromFrame(f, SquatSide.left)!.kneeAngleDegrees,
        closeTo(175, 1e-8));
    expect(WorldKneeAngle.measure(f, SquatSide.left).angleDegrees,
        closeTo(90, 1e-8));
  });
  test('world angle is translation, rotation and uniform-scale invariant', () {
    for (final scale in [.1, 1.0, 8.0]) {
      final result = WorldKneeAngle.measure(
          worldFrame(
              degrees: 73,
              transform: (v) {
                final t = .71, c = math.cos(t), s = math.sin(t);
                final x = v[0] * c - v[2] * s, z = v[0] * s + v[2] * c;
                return [x * scale - 4, v[1] * scale + 2, z * scale - 3];
              }),
          SquatSide.left);
      expect(result.angleDegrees, closeTo(73, 1e-8));
    }
  });
  test(
      'missing/low-confidence/nonfinite/degenerate world data explicitly abstains',
      () {
    for (final (f, status) in [
      (worldFrame(missing: true), WorldKneeStatus.missingLandmark),
      (worldFrame(confidence: .6), WorldKneeStatus.lowConfidence),
      (worldFrame(confidence: double.nan), WorldKneeStatus.invalidConfidence),
      (worldFrame(confidence: 1.1), WorldKneeStatus.invalidConfidence),
      (worldFrame(confidence: -.1), WorldKneeStatus.invalidConfidence),
      (worldFrame(poseConfidence: .6), WorldKneeStatus.lowConfidence),
      (
        worldFrame(poseConfidence: double.nan),
        WorldKneeStatus.invalidConfidence
      ),
      (worldFrame(poseConfidence: 1.1), WorldKneeStatus.invalidConfidence),
      (worldFrame(poseConfidence: -.1), WorldKneeStatus.invalidConfidence),
      (worldFrame(nonfinite: true), WorldKneeStatus.nonfiniteCoordinate),
      (worldFrame(degenerate: true), WorldKneeStatus.degenerateSegment),
      (worldFrame(mirrored: true), WorldKneeStatus.mirroredFrame)
    ]) {
      final result = WorldKneeAngle.measure(f, SquatSide.left);
      expect(result.angleDegrees, isNull);
      expect(result.status, status);
    }
    final noWorld = fixture.sample(100, 90);
    expect(
        WorldKneeAngle.measure(noWorld, SquatSide.left).angleDegrees, isNull);
  });
  test(
      'raw/filtered comparison preserves same-frame identity and does not manufacture fallback',
      () {
    final raw = worldFrame(time: 100, degrees: 175);
    final filter = PoseFrameFilter();
    filter.filter(raw);
    final next = worldFrame(time: 100100, degrees: 75);
    final filtered = filter.filter(next);
    final pair =
        SquatAngleComparison.fromFrames(next, filtered, SquatSide.left);
    expect(pair.matches(100100, SquatSide.left), true);
    expect(pair.matches(100100, SquatSide.right), false);
    expect(pair.raw3d.angleDegrees, closeTo(75, 1e-8));
    expect(pair.filtered3d.angleDegrees, isNot(closeTo(75, 1e-8)));
    for (final other in [
      worldFrame(time: 99),
      worldFrame(model: 'different'),
      worldFrame(width: 800),
      worldFrame(mirrored: true)
    ]) {
      final mismatch =
          SquatAngleComparison.fromFrames(raw, other, SquatSide.left);
      expect(mismatch.matches(100, SquatSide.left), false);
      expect(mismatch.raw3d.angleDegrees, isNull);
      expect(mismatch.filtered3d.angleDegrees, isNull);
      expect(mismatch.raw3d.status, WorldKneeStatus.frameMismatch);
      expect(mismatch.filtered3d.status, WorldKneeStatus.frameMismatch);
    }
    final missing = fixture.sample(100, 90);
    final unavailable =
        SquatAngleComparison.fromFrames(missing, missing, SquatSide.left);
    expect(unavailable.raw2dDegrees, closeTo(90, 1e-8));
    expect(unavailable.raw3d.angleDegrees, isNull);
  });
}
