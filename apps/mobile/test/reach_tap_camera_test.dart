import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/infrastructure/pose/reach_tap_pose_camera.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_contract.dart';

PoseFrame reachFrame(
        {double visibility = .99,
        bool missing = false,
        String? model,
        bool mirrored = false}) =>
    PoseFrame(
        capturedAtMicros: 100000,
        imageWidth: 400,
        imageHeight: 800,
        detectorId: 'blazepose-tflite',
        modelVersion: model ?? BlazePoseModelContract.version,
        isMirrored: mirrored,
        landmarks: {
          for (final id in [
            PoseLandmark.leftShoulder,
            PoseLandmark.rightShoulder,
            PoseLandmark.leftElbow,
            PoseLandmark.rightElbow,
            PoseLandmark.leftWrist,
            PoseLandmark.rightWrist,
            PoseLandmark.leftHip,
            PoseLandmark.rightHip
          ])
            if (!missing || id != PoseLandmark.leftWrist)
              id: PosePoint(
                  x: id.name.startsWith('left') ? .3 : .7,
                  y: id.name.endsWith('Hip')
                      ? .65
                      : id.name.endsWith('Shoulder')
                          ? .35
                          : .5,
                  z: 0,
                  visibility: visibility,
                  presence: visibility)
        });
void main() {
  test('upright source is mirrored once through centered cover crop', () {
    final s = reachTapSample(reachFrame(),
        boardWidth: 400,
        boardHeight: 400,
        previewWidth: 400,
        previewHeight: 800,
        mirrored: true)!;
    expect(s.leftHand!.x, closeTo(.7, .0001));
    expect(s.leftHand!.y, closeTo(.5, .0001));
    expect(s.leftShoulder!.y, closeTo(.2, .0001));
    expect(s.leftHip!.y, closeTo(.8, .0001));
  });
  test('rear view preserves anatomical left hand source direction', () {
    final s = reachTapSample(reachFrame(),
        boardWidth: 400,
        boardHeight: 800,
        previewWidth: 400,
        previewHeight: 800,
        mirrored: false)!;
    expect(s.leftHand!.x, closeTo(.3, .0001));
  });
  test(
      'weak body confidence, changed model and mismatched fields of view fail closed',
      () {
    for (final f in [
      reachFrame(visibility: .4),
      reachFrame(model: 'other'),
      reachFrame(mirrored: true)
    ]) {
      expect(
          reachTapSample(f,
              boardWidth: 400,
              boardHeight: 800,
              previewWidth: 400,
              previewHeight: 800,
              mirrored: true),
          isNull);
    }
    expect(
        reachTapSample(reachFrame(),
            boardWidth: 400,
            boardHeight: 800,
            previewWidth: 800,
            previewHeight: 400,
            mirrored: true),
        isNull);
    expect(
        reachTapSample(reachFrame(),
            boardWidth: 0,
            boardHeight: 800,
            previewWidth: 400,
            previewHeight: 800,
            mirrored: true),
        isNull);
  });
}
