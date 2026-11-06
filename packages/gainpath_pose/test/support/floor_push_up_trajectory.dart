import 'dart:math' as math;
import 'package:gainpath_pose/gainpath_pose.dart';

/// Analytic landmarks, never recorded video or human accuracy evidence.
PoseFrame floorFrame(int t, double angle,
    {bool right = false,
    bool facingLeft = false,
    double hipOffset = 0,
    double visibility = .99,
    bool wrongView = false,
    bool world = false,
    double worldElbowOffset = 0,
    bool omitKnee = false,
    int width = 1000,
    int height = 1000,
    String detector = 'fixture'}) {
  final radians = angle * math.pi / 180;
  final sy = .72 - .36 * math.sin(radians / 2);
  final ex = .2 + .18 * math.cos(radians / 2);
  double line(double x) => sy + (x - .2) / .65 * (.68 - sy);
  PosePoint p(double x, double y, [double v = .99]) => PosePoint(
      x: (facingLeft ? 1 - x : x) * height / width,
      y: y,
      z: 0,
      visibility: v,
      presence: v);
  final j = right
      ? [
          PoseLandmark.rightShoulder,
          PoseLandmark.rightElbow,
          PoseLandmark.rightWrist,
          PoseLandmark.rightHip,
          PoseLandmark.rightKnee,
          PoseLandmark.rightAnkle
        ]
      : [
          PoseLandmark.leftShoulder,
          PoseLandmark.leftElbow,
          PoseLandmark.leftWrist,
          PoseLandmark.leftHip,
          PoseLandmark.leftKnee,
          PoseLandmark.leftAnkle
        ];
  final other = right ? PoseLandmark.leftShoulder : PoseLandmark.rightShoulder;
  final points = {
    j[0]: p(.2, sy),
    j[1]: p(ex, (sy + .72) / 2, visibility),
    j[2]: p(.2, .72),
    j[3]: p(.5, line(.5) + hipOffset),
    if (!omitKnee) j[4]: p(.7, line(.7)),
    j[5]: p(.85, .68),
    other: p(wrongView ? .5 : .225, sy + .005, .9),
  };
  final worldPoints = <PoseLandmark, PosePoint>{};
  if (world) {
    for (final entry in points.entries) {
      final v = entry.value;
      worldPoints[entry.key] = PosePoint(
          x: v.x * width / height,
          y: v.y + (entry.key == j[1] ? worldElbowOffset : 0),
          z: 0,
          visibility: v.visibility,
          presence: v.presence);
    }
  }
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: detector,
      modelVersion: '1',
      imageWidth: width,
      imageHeight: height,
      posePresence: .99,
      landmarks: points,
      worldLandmarks: worldPoints);
}

class FloorReplay {
  FloorReplay(
      {this.right = false, this.facingLeft = false, FloorPushUpRules? rules})
      : analyzer = FloorPushUpAnalyzer(rules: rules);
  final FloorPushUpAnalyzer analyzer;
  final bool right, facingLeft;
  int t = 0;
  final phases = <FloorPushUpPhase>{};
  final issues = <FloorPushUpIssue>{};
  final cues = <String>{};
  void hold(double angle, int millis,
      {double hipOffset = 0,
      double visibility = .99,
      bool wrongView = false,
      bool world = false,
      double worldElbowOffset = 0}) {
    for (var i = 0; i < millis; i += 50) {
      t += 50000;
      final u = analyzer.update(
          floorFrame(t, angle,
              right: right,
              facingLeft: facingLeft,
              hipOffset: hipOffset,
              visibility: visibility,
              wrongView: wrongView,
              world: world,
              worldElbowOffset: worldElbowOffset),
          nowMicros: t);
      phases.add(u.phase);
      issues.addAll(u.issues);
      cues.addAll(u.cues.map((c) => c.text));
    }
  }

  void cycle(
      {double bottom = 90,
      double top = 170,
      double hipOffset = 0,
      int stepMillis = 200,
      int bottomMillis = 400}) {
    for (final a in [150.0, 130.0, 110.0, bottom]) {
      hold(a, stepMillis, hipOffset: hipOffset);
    }
    hold(bottom, bottomMillis, hipOffset: hipOffset);
    for (final a in [110.0, 130.0, 150.0, top]) {
      hold(a, stepMillis, hipOffset: hipOffset);
    }
    hold(top, 400, hipOffset: hipOffset);
  }
}
