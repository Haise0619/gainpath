import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/infrastructure/pose/move_catch_pose_camera.dart';

PoseFrame frame(
        {double visibility = .9,
        String detector = 'blazepose-tflite',
        double x = .2}) =>
    PoseFrame(
        capturedAtMicros: 100,
        detectorId: detector,
        modelVersion: 'test',
        landmarks: {
          PoseLandmark.leftShoulder:
              PosePoint(x: x, y: .2, z: 0, visibility: visibility),
          PoseLandmark.rightShoulder:
              const PosePoint(x: .5, y: .2, z: 0, visibility: .9),
          PoseLandmark.leftHip:
              const PosePoint(x: .2, y: .6, z: 0, visibility: .9),
          PoseLandmark.rightHip:
              const PosePoint(x: .5, y: .6, z: 0, visibility: .9),
        });
void main() {
  test(
      'both visible sides preserve left/right direction for mirrored and rear views',
      () {
    for (final mirrored in [false, true]) {
      for (final rawCenter in [.03, .97]) {
        final tracker = MoveCatchTorsoTracker();
        tracker.sample(frame(), mirrored: mirrored, nowMicros: 100);
        final rightSide = rawCenter < .5;
        final x = rightSide ? rawCenter + .15 : rawCenter - .15;
        final partial = PoseFrame(
            capturedAtMicros: 50100,
            detectorId: 'blazepose-tflite',
            modelVersion: 'test',
            landmarks: {
              rightSide
                      ? PoseLandmark.rightShoulder
                      : PoseLandmark.leftShoulder:
                  PosePoint(x: x, y: .2, z: 0, visibility: .9),
              rightSide ? PoseLandmark.rightHip : PoseLandmark.leftHip:
                  PosePoint(x: x, y: .6, z: 0, visibility: .9),
            });
        final sample =
            tracker.sample(partial, mirrored: mirrored, nowMicros: 50100)!;
        expect(sample.centerX,
            closeTo(mirrored ? 1 - rawCenter : rawCenter, .001));
      }
    }
  });
  test(
      'visible side tracks the same torso center when the other side exits view',
      () {
    final tracker = MoveCatchTorsoTracker();
    final full = tracker.sample(frame(), mirrored: false, nowMicros: 100)!;
    final partial = PoseFrame(
        capturedAtMicros: 50100,
        detectorId: 'blazepose-tflite',
        modelVersion: 'test',
        landmarks: {
          PoseLandmark.rightShoulder:
              const PosePoint(x: .18, y: .2, z: 0, visibility: .9),
          PoseLandmark.rightHip:
              const PosePoint(x: .18, y: .6, z: 0, visibility: .9),
        });
    final side = tracker.sample(partial, mirrored: false, nowMicros: 50100)!;
    expect(full.fullTorso, isTrue);
    expect(side.fullTorso, isFalse);
    expect(side.centerX, closeTo(.03, .001));
    expect(side.shoulderWidth, full.shoulderWidth);
    final noBaseline = MoveCatchTorsoTracker();
    expect(
        noBaseline.sample(partial, mirrored: false, nowMicros: 50100), isNull);
  });
  test(
      'partial pose needs a real same-side shoulder and hip; no stale or one-point movement',
      () {
    final tracker = MoveCatchTorsoTracker();
    tracker.sample(frame(), mirrored: true, nowMicros: 100);
    final one = PoseFrame(
        capturedAtMicros: 50100,
        detectorId: 'blazepose-tflite',
        modelVersion: 'test',
        landmarks: {
          PoseLandmark.rightShoulder:
              const PosePoint(x: .2, y: .2, z: 0, visibility: .9)
        });
    expect(tracker.sample(one, mirrored: true, nowMicros: 50100), isNull);
    expect(tracker.sample(frame(), mirrored: true, nowMicros: 1000000), isNull);
    tracker.reset();
    expect(tracker.sample(one, mirrored: true, nowMicros: 50100), isNull);
  });
  test('torso center mirrors once and preserves capture identity', () {
    final plain = moveCatchTorsoSample(frame(), mirrored: false)!;
    final mirror = moveCatchTorsoSample(frame(), mirrored: true)!;
    expect(plain.centerX, closeTo(.35, .0001));
    expect(mirror.centerX, closeTo(.65, .0001));
    expect(mirror.shoulderWidth, .3);
    expect(mirror.capturedAtMicros, 100);
  });
  test('unseen, invalid and simulated torso cannot control real play', () {
    expect(
        moveCatchTorsoSample(frame(visibility: .4), mirrored: false), isNull);
    expect(moveCatchTorsoSample(frame(detector: 'simulated'), mirrored: false),
        isNull);
    expect(moveCatchTorsoSample(frame(x: double.nan), mirrored: false), isNull);
    expect(moveCatchTorsoSample(frame(x: .49), mirrored: false), isNull);
  });
}
