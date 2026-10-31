import 'package:gainpath_pose/gainpath_pose.dart';

/// Synthetic image projection only, never physical validation or floor proof.
PoseFrame calfPose(int t, double lift,
    {CalfSide side = CalfSide.left,
    double scale = 1,
    double confidence = .99,
    double heelJitter = 0,
    double toeJitter = 0,
    double ankleJitter = 0,
    double toeShift = 0,
    bool bent = false,
    int width = 400,
    int height = 800}) {
  PosePoint p(double x, double y) => PosePoint(
      x: (.25 + (x - .25) * scale) * height / width,
      y: .55 + (y - .55) * scale,
      z: 0,
      visibility: confidence,
      presence: confidence);
  final ids = CalfRaiseGeometry.joints(side);
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: 'synthetic-calf',
      modelVersion: '1',
      imageWidth: width,
      imageHeight: height,
      landmarks: {
        ids[0]: p(bent ? .36 : .20, .35 - lift * .2),
        ids[1]: p(.20, .55 - lift * .2),
        ids[2]: p(.20, .75 - lift * .2 + ankleJitter),
        ids[3]: p(.19, .80 - lift * .2 + heelJitter),
        ids[4]: p(.26 + toeJitter, .80 + toeShift),
      });
}

double calfLiftAt(int t) => t < 1100000
    ? 0
    : t < 1900000
        ? (t - 1100000) / 800000 * .12
        : t < 2300000
            ? .12
            : t < 3100000
                ? (1 - (t - 2300000) / 800000) * .12
                : 0;
Iterable<PoseFrame> calfTrajectory(
    {int start = 0,
    int step = 50000,
    CalfSide side = CalfSide.left,
    double scale = 1,
    bool jitter = false,
    double amplitude = 1}) sync* {
  for (var t = 0; t <= 3500000; t += step) {
    final sign = (t ~/ step).isEven ? 1.0 : -1.0;
    yield calfPose(start + t, calfLiftAt(t) * amplitude,
        side: side,
        scale: scale,
        heelJitter: jitter ? sign * .006 : 0,
        toeJitter: jitter ? sign * .008 : 0,
        ankleJitter: jitter ? -sign * .002 : 0);
  }
}
