import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';

void main() {
  test('the pose package exposes a detector port independent of Flutter',
      () async {
    final frame = await SimulatedPoseDetector()
        .detect(const PoseInput(timestampMicros: 1));

    expect(frame.detectorId, 'simulated');
    expect(frame.landmarks.length, PoseLandmark.values.length);
  });
}
