import 'package:gainpath_pose/gainpath_pose.dart';

/// Synthetic coordinate-only fixture. No camera bytes, human capture, routine,
/// persistence, submission or workout session interfaces are involved.
List<PoseFrame> syntheticArmTrajectory() {
  var time = 1000000;
  final frames = <PoseFrame>[];
  for (var i = 0; i < 95; i++) {
    final progress = i < 10
        ? 0.0
        : i < 30
            ? (i - 10) / 20
            : i < 40
                ? 1.0
                : i < 60
                    ? 1 - (i - 40) / 20
                    : i < 70
                        ? 0.0
                        : i < 75
                            ? (i - 70) / 5
                            : i < 85
                                ? 1.0
                                : i < 90
                                    ? 1 - (i - 85) / 5
                                    : 0.0;
    frames.add(PoseFrame(
        capturedAtMicros: time,
        detectorId: 'diagnostic-fixture',
        modelVersion: 'synthetic-1',
        imageWidth: 480,
        imageHeight: 720,
        landmarks: {
          PoseLandmark.leftShoulder:
              const PosePoint(x: .4, y: .35, z: 0, visibility: 1, presence: 1),
          PoseLandmark.leftElbow: PosePoint(
              x: .5, y: .70 - .55 * progress, z: 0, visibility: 1, presence: 1),
          PoseLandmark.leftWrist: PosePoint(
              x: .6, y: .85 - .75 * progress, z: 0, visibility: 1, presence: 1),
        }));
    time += [90000, 87000, 94000][i % 3];
  }
  return frames;
}
