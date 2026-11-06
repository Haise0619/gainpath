import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';

/// Analytic triangle with independently specified projected segment lengths and
/// elbow angle. This is not a recovered recording or human accuracy reference.
PoseFrame projectionFrame(int t, double angle,
    {double upper = 1,
    double forearm = 1,
    bool right = false,
    bool world = true,
    double confidence = .96,
    bool swapped = false}) {
  final u = 45 * upper, f = 45 * forearm;
  final d =
      math.sqrt(u * u + f * f - 2 * u * f * math.cos(angle * math.pi / 180));
  final along = (u * u + d * d - f * f) / (2 * d);
  final across = math.sqrt(math.max(0, u * u - along * along));
  final sy = 250 - d;
  final ids = FloorPushUpGeometry.joints(
      right ? FloorPushUpSide.right : FloorPushUpSide.left);
  PosePoint p(double x, double y) => PosePoint(
      x: x / 640,
      y: y / 480,
      z: 0,
      visibility: confidence,
      presence: confidence);
  double line(double x) => sy + (x - 70) / 270 * (235 - sy);
  final points = <PoseLandmark, PosePoint>{
    ids[0]: p(70, sy),
    ids[1]: p(70 + across, sy + along),
    ids[2]: p(70, 250),
    ids[3]: p(190, line(190)),
    ids[4]: p(340, 235),
    right ? PoseLandmark.rightKnee : PoseLandmark.leftKnee: p(275, line(275)),
    right ? PoseLandmark.leftShoulder : PoseLandmark.rightShoulder:
        p(74, sy + 2),
  };
  if (swapped) {
    final e = points[ids[1]]!;
    points[ids[1]] = points[ids[2]]!;
    points[ids[2]] = e;
  }
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: 'projection-fixture',
      modelVersion: '1',
      imageWidth: 640,
      imageHeight: 480,
      posePresence: .99,
      landmarks: points,
      worldLandmarks: world
          ? points.map((k, v) => MapEntry(
              k,
              PosePoint(
                  x: v.x * 640 / 250,
                  y: v.y * 480 / 250,
                  z: 0,
                  visibility: confidence,
                  presence: confidence)))
          : const {});
}

class ProjectionReplay {
  ProjectionReplay({this.right = false});
  final bool right;
  final a = FloorPushUpAnalyzer();
  int t = 0;
  FloorPushUpUpdate feed(double angle,
      {double upper = 1,
      double forearm = 1,
      int delta = 60000,
      bool world = true,
      double confidence = .96,
      bool swapped = false}) {
    t += delta;
    return a.update(
        projectionFrame(t, angle,
            upper: upper,
            forearm: forearm,
            right: right,
            world: world,
            confidence: confidence,
            swapped: swapped),
        nowMicros: t);
  }

  void hold(double angle, int n, {double upper = 1, double forearm = 1}) {
    for (var i = 0; i < n; i++) {
      feed(angle, upper: upper, forearm: forearm);
    }
  }

  void start({bool bottom = true}) {
    hold(170, 10);
    hold(150, 4);
    hold(130, 4);
    hold(110, 4);
    if (bottom) hold(85, 8);
  }

  void finishCycle() {
    for (final angle in [90.0, 110.0, 130.0, 150.0, 170.0]) {
      hold(angle, 6);
    }
  }
}
