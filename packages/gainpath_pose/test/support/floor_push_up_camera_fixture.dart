import 'package:gainpath_pose/gainpath_pose.dart';
import 'floor_push_up_trajectory.dart';

/// Analytic camera fixture in physical pixels. Not recovered device landmarks.
PoseFrame floorCameraFrame(int t, double angle,
    {int width = 480,
    int height = 640,
    bool right = false,
    double worldDepth = 0,
    bool conflict = false,
    double scale = 250}) {
  final f = floorFrame(t, angle, right: right, world: true);
  PosePoint image(PosePoint p) => PosePoint(
      x: (20 + p.x * scale) / width,
      y: (30 + p.y * scale) / height,
      z: p.z,
      visibility: p.visibility,
      presence: p.presence);
  final elbow = right ? PoseLandmark.rightElbow : PoseLandmark.leftElbow;
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: f.detectorId,
      modelVersion: f.modelVersion,
      imageWidth: width,
      imageHeight: height,
      posePresence: f.posePresence,
      landmarks: f.landmarks.map((k, v) => MapEntry(k, image(v))),
      worldLandmarks: f.worldLandmarks.map((k, v) => MapEntry(
          k,
          PosePoint(
              x: v.x,
              y: v.y + (conflict && k == elbow ? .5 : 0),
              z: k == elbow ? worldDepth : 0,
              visibility: v.visibility,
              presence: v.presence))));
}
