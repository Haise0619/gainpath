import 'package:gainpath_pose/gainpath_pose.dart';
import 'calf_raise_trajectory.dart';

/// Engineering projection reproducer, not raw native landmarks from a video.
PoseFrame calfFootArc(PoseFrame source, double lift,
    {CalfSide side = CalfSide.left,
    bool facingLeft = false,
    bool toeArc = true,
    bool shinProjection = true}) {
  final ids = CalfRaiseGeometry.joints(side),
      ratio = source.imageHeight / source.imageWidth;
  final v = (lift / .12).clamp(0.0, 1.0);
  return PoseFrame(
      capturedAtMicros: source.capturedAtMicros,
      detectorId: source.detectorId,
      modelVersion: source.modelVersion,
      imageWidth: source.imageWidth,
      imageHeight: source.imageHeight,
      landmarks: {
        for (final entry in source.landmarks.entries)
          entry.key: PosePoint(
              x: (facingLeft ? 1 - entry.value.x : entry.value.x) +
                  (entry.key == ids[4] && toeArc
                      ? (facingLeft ? -1 : 1) * .020 * v * ratio
                      : 0),
              y: entry.value.y +
                  (entry.key == ids[4] && toeArc ? .014 * v : 0) +
                  (entry.key == ids[2] && shinProjection ? -.034 * v : 0),
              z: entry.value.z,
              visibility: entry.value.visibility,
              presence: entry.value.presence)
      });
}

Iterable<PoseFrame> calfArcTrajectory(
    {int start = 0,
    int step = 50000,
    CalfSide side = CalfSide.left,
    bool facingLeft = false,
    bool toeArc = true,
    bool shinProjection = true,
    double heelNoise = 0}) sync* {
  for (var t = 0; t <= 3500000; t += step) {
    final lift = calfLiftAt(t), sign = (t ~/ step).isEven ? 1.0 : -1.0;
    yield calfFootArc(
        calfPose(start + t, lift, side: side, heelJitter: sign * heelNoise),
        lift,
        side: side,
        facingLeft: facingLeft,
        toeArc: toeArc,
        shinProjection: shinProjection);
  }
}
