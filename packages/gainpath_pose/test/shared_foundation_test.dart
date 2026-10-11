import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';

void main() {
  test('the detector-neutral vocabulary covers all 33 anatomical landmarks',
      () {
    expect(PoseLandmark.values.length, 33);
    expect(
        PoseLandmark.values.map((p) => p.name),
        containsAll([
          'leftElbow',
          'rightElbow',
          'leftWrist',
          'rightWrist',
          'leftHeel',
          'rightHeel',
          'leftFootIndex',
          'rightFootIndex',
        ]));
  });
}
