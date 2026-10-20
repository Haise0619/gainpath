import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'support/pose_joint_trajectory.dart';

void main() {
  test(
      'current filter responds to synthetic irregular-time arm motion and settles at holds',
      () {
    final raw = syntheticArmTrajectory(), filter = PoseFrameFilter();
    final filtered = raw.map(filter.filter).toList();
    // Static interval stays exact; motion trails in its direction; both holds
    // converge. Removing filtering fails the strict directional assertions.
    expect(
        filtered[9].landmarks[PoseLandmark.leftWrist]!.y, closeTo(.85, 1e-12));
    expect(filtered[20].landmarks[PoseLandmark.leftWrist]!.y,
        greaterThan(raw[20].landmarks[PoseLandmark.leftWrist]!.y));
    expect(filtered[50].landmarks[PoseLandmark.leftWrist]!.y,
        lessThan(raw[50].landmarks[PoseLandmark.leftWrist]!.y));
    expect((filtered[39].landmarks[PoseLandmark.leftWrist]!.y - .1).abs(),
        lessThan(.005));
    final summary = <String, Object?>{};
    for (final joint in [PoseLandmark.leftElbow, PoseLandmark.leftWrist]) {
      final d = [
        for (var i = 0; i < raw.length; i++)
          (filtered[i].landmarks[joint]!.y - raw[i].landmarks[joint]!.y).abs() *
              720
      ];
      final crossing = <String, List<int>>{};
      for (var i = 1; i < raw.length; i++) {
        for (final pair in [('raw', raw), ('filtered', filtered)]) {
          final a = pair.$2[i - 1].landmarks[joint]!.y - .35,
              b = pair.$2[i].landmarks[joint]!.y - .35;
          if (a > 0 && b <= 0 || a < 0 && b >= 0) {
            final direction = a > 0 ? 'raise' : 'lower';
            crossing['${pair.$1}-$direction-$i'] = [
              raw[i - 1].capturedAtMicros,
              raw[i].capturedAtMicros
            ];
          }
        }
      }
      summary[joint.name] = {
        'maxDisplacementPixels': d.reduce(math.max),
        'slowRaiseMeanPixels': d.sublist(11, 31).reduce((a, b) => a + b) / 20,
        'fastRaiseMeanPixels': d.sublist(71, 76).reduce((a, b) => a + b) / 5,
        'crossingsInputMicros': crossing
      };
    }
    // Aggregates and timestamp brackets only; the synthetic trajectory itself
    // lives in test scope and cannot create real workout activity.
    // ignore: avoid_print
    print('POSE_LAG_SYNTHETIC ${jsonEncode(summary)}');
  });
}
