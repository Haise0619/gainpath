import 'dart:async';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';

PoseFrame pose(int time, double x, {bool missing = false}) => PoseFrame(
      capturedAtMicros: time,
      detectorId: 'fixture',
      modelVersion: '1',
      imageWidth: 640,
      imageHeight: 480,
      posePresence: 0.9,
      landmarks: missing
          ? {}
          : {
              PoseLandmark.nose: PosePoint(
                  x: x, y: 0.5, z: -0.2, visibility: 0.8, presence: 0.9)
            },
      worldLandmarks: missing
          ? {}
          : {
              PoseLandmark.nose:
                  PosePoint(x: x, y: 0, z: -0.5, visibility: 0.8, presence: 0.9)
            },
    );

void main() {
  test(
      'One Euro smoothing preserves presence, dimensions and separate world depth',
      () {
    final filter = PoseFrameFilter();
    filter.filter(pose(1, 0));
    final result = filter.filter(pose(33001, 1));
    expect(result.landmark(PoseLandmark.nose)!.x, inExclusiveRange(0, 1));
    expect(result.landmark(PoseLandmark.nose)!.presence, 0.9);
    expect(result.landmark(PoseLandmark.nose)!.z, -0.2);
    expect(result.worldLandmarks[PoseLandmark.nose]!.z, -0.5);
    expect(result.imageWidth, 640);
  });
  test(
      'missing points and long gaps reset smoothing rather than resurrecting a skeleton',
      () {
    final filter = PoseFrameFilter();
    filter.filter(pose(1, 0));
    expect(filter.filter(pose(33001, 0, missing: true)).landmarks, isEmpty);
    expect(filter.filter(pose(66001, 1)).landmark(PoseLandmark.nose)!.x, 1);
    expect(filter.filter(pose(1000001, 0)).landmark(PoseLandmark.nose)!.x, 0);
    expect(() => filter.filter(pose(999999, 1)), throwsArgumentError);
  });
  test(
      'latest scheduler retains only newest pending frame and invalidates late completions',
      () async {
    var now = 0;
    final first = Completer<int>();
    final seen = <int>[];
    final results = <int>[];
    final scheduler = LatestPoseProcessor<int, int>(
      clockMicros: () => now,
      timestampMicros: (v) => v,
      process: (v) {
        seen.add(v);
        return v == 1 ? first.future : Future.value(v);
      },
      onResult: results.add,
      onError: (e, s) => fail('$e'),
    );
    scheduler.add(1);
    scheduler.add(2);
    scheduler.add(3);
    first.complete(1);
    await scheduler.drain();
    expect(seen, [1, 3]);
    expect(results, [1, 3]);
    expect(scheduler.droppedFrames, 1);
    now = 1000000;
    scheduler.add(4);
    await scheduler.drain();
    expect(seen, [1, 3]);
    expect(scheduler.staleFrames, 1);
  });
  test(
      'suspend/dispose discard pending and in-flight results without closing active resources',
      () async {
    final gate = Completer<int>();
    final results = <int>[];
    final scheduler = LatestPoseProcessor<int, int>(
      clockMicros: () => 10,
      timestampMicros: (v) => v,
      process: (_) => gate.future,
      onResult: results.add,
      onError: (e, s) => fail('$e'),
    );
    scheduler.add(1);
    scheduler.add(2);
    scheduler.suspend();
    gate.complete(1);
    await scheduler.drain();
    expect(results, isEmpty);
    scheduler.dispose();
    scheduler.add(3);
    await scheduler.drain();
    expect(results, isEmpty);
  });
}
