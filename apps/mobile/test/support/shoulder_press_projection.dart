import 'package:gainpath_pose/gainpath_pose.dart';

/// Controlled projection/elevation perturbations, NOT raw recovered video.
PoseFrame pressProjection(PoseFrame f,
    {double elevation = 0,
    double upperScale = 1,
    double forearmScale = 1,
    double spanScale = 1,
    double hipShift = 0,
    double jitter = 0,
    double confidence = .99}) {
  final points = Map<PoseLandmark, PosePoint>.of(f.landmarks);
  final cx = (points[PoseLandmark.leftShoulder]!.x +
          points[PoseLandmark.rightShoulder]!.x) /
      2;
  for (final ids in [
    [
      PoseLandmark.leftShoulder,
      PoseLandmark.leftElbow,
      PoseLandmark.leftWrist,
      PoseLandmark.leftHip
    ],
    [
      PoseLandmark.rightShoulder,
      PoseLandmark.rightElbow,
      PoseLandmark.rightWrist,
      PoseLandmark.rightHip
    ],
  ]) {
    final s = points[ids[0]]!,
        e = points[ids[1]]!,
        w = points[ids[2]]!,
        h = points[ids[3]]!;
    final sx = cx + (s.x - cx) * spanScale, sy = s.y - elevation;
    final ex = sx + (e.x - s.x) * upperScale,
        ey = sy + (e.y - s.y) * upperScale;
    PosePoint p(double x, double y) => PosePoint(
        x: x + jitter,
        y: y + jitter,
        z: 0,
        visibility: confidence,
        presence: confidence);
    points[ids[0]] = p(sx, sy);
    points[ids[1]] = p(ex, ey);
    points[ids[2]] =
        p(ex + (w.x - e.x) * forearmScale, ey + (w.y - e.y) * forearmScale);
    points[ids[3]] = p(h.x + hipShift, h.y);
  }
  return PoseFrame(
      capturedAtMicros: f.capturedAtMicros,
      detectorId: f.detectorId,
      modelVersion: f.modelVersion,
      imageWidth: f.imageWidth,
      imageHeight: f.imageHeight,
      landmarks: points);
}
