import 'package:gainpath_pose/gainpath_pose.dart';
import 'floor_push_up_projection_fixture.dart';

/// Analytic image coordinates with the recording's accepted raw-angle/timestamp
/// samples. Original device coordinates/filter history are not available.
class DwellReplay extends ProjectionReplay {
  DwellReplay({super.right});
  void prepare() {
    t = 31900000;
    start();
    hold(71.78, 4);
    at(34000000, 90);
    at(34100000, 105);
    at(34200000, 115);
  }

  FloorPushUpUpdate at(int capture, double raw, {double confidence = .96}) =>
      feed(raw, delta: capture - t, confidence: confidence);
  void approach({double firstRawTop = 157.30}) {
    at(34310642, 127.99);
    at(34391677, 137.21);
    at(34481982, firstRawTop);
    at(34562043, 158.00);
  }

  void reverse() {
    at(34780402, 152.57);
    at(34921516, 140);
    at(34990162, 128.96);
    at(35045461, 114.58);
  }
}

PoseFrame bentKneeFrame(int t, {double confidence = .99, bool right = false}) {
  final f = projectionFrame(t, 170, right: right);
  final hip = right ? PoseLandmark.rightHip : PoseLandmark.leftHip;
  final ankle = right ? PoseLandmark.rightAnkle : PoseLandmark.leftAnkle;
  final knee = right ? PoseLandmark.rightKnee : PoseLandmark.leftKnee;
  final h = f.landmarks[hip]!, a = f.landmarks[ankle]!;
  final hx = h.x * 640, hy = h.y * 480, ax = a.x * 640, ay = a.y * 480;
  final k = PosePoint(
      x: ((hx + ax) / 2 - (ay - hy) / 2) / 640,
      y: ((hy + ay) / 2 + (ax - hx) / 2) / 480,
      z: 0,
      visibility: confidence,
      presence: confidence);
  return PoseFrame(
      capturedAtMicros: t,
      detectorId: f.detectorId,
      modelVersion: f.modelVersion,
      imageWidth: 640,
      imageHeight: 480,
      posePresence: .99,
      landmarks: {...f.landmarks, knee: k},
      worldLandmarks: f.worldLandmarks);
}
