import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/infrastructure/pose/reach_tap_pose_camera.dart';
import 'reach_tap_camera_test.dart' show reachFrame;

PoseFrame without(PoseLandmark id) {
  final f = reachFrame();
  return PoseFrame(
      capturedAtMicros: f.capturedAtMicros,
      imageWidth: f.imageWidth,
      imageHeight: f.imageHeight,
      detectorId: f.detectorId,
      modelVersion: f.modelVersion,
      landmarks: {...f.landmarks}..remove(id));
}

void main() {
  test(
      'weak or cropped wrist is hidden independently without lowering confidence',
      () {
    for (final bad in [
      const PosePoint(x: .3, y: .5, z: 0, visibility: .64, presence: .99),
      const PosePoint(x: .3, y: .5, z: 0, visibility: .99, presence: .64),
      const PosePoint(x: -.01, y: .5, z: 0, visibility: .99, presence: .99),
    ]) {
      final f = reachFrame();
      final frame = PoseFrame(
          capturedAtMicros: f.capturedAtMicros,
          imageWidth: f.imageWidth,
          imageHeight: f.imageHeight,
          detectorId: f.detectorId,
          modelVersion: f.modelVersion,
          landmarks: {...f.landmarks, PoseLandmark.leftWrist: bad});
      final s = reachTapSample(frame,
          boardWidth: 400,
          boardHeight: 800,
          previewWidth: 400,
          previewHeight: 800,
          mirrored: false);
      expect(s, isNotNull);
      expect(s!.leftHand, isNull);
      expect(s.rightHand, isNotNull);
    }
  });
  test('one missing hand does not erase the other real hand or visible body',
      () {
    final s = reachTapSample(without(PoseLandmark.leftWrist),
        boardWidth: 400,
        boardHeight: 800,
        previewWidth: 400,
        previewHeight: 800,
        mirrored: true);
    expect(s, isNotNull);
    expect(s!.leftHand, isNull);
    expect(s.rightHand, isNotNull);
    expect(s.leftShoulder, isNotNull);
    expect(s.leftHip, isNotNull);
  });
  test('an occluded elbow is not a prerequisite for a real visible wrist', () {
    final s = reachTapSample(without(PoseLandmark.rightElbow),
        boardWidth: 400,
        boardHeight: 800,
        previewWidth: 400,
        previewHeight: 800,
        mirrored: false);
    expect(s, isNotNull);
    expect(s!.rightElbow, isNull);
    expect(s.rightHand, isNotNull);
    expect(s.leftHand, isNotNull);
  });
  test('missing real torso anchor still rejects body tracking', () {
    expect(
        reachTapSample(without(PoseLandmark.leftHip),
            boardWidth: 400,
            boardHeight: 800,
            previewWidth: 400,
            previewHeight: 800,
            mirrored: false),
        isNull);
  });
}
