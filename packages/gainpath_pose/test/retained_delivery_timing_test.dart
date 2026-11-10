import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'curl_analyzer_test.dart' show curlFrame;
import 'support/calf_raise_trajectory.dart';
import 'support/lateral_raise_trajectory.dart';

Iterable<PoseFrame> curlTrajectory() sync* {
  for (var t = 0; t <= 1000000; t += 100000) {
    yield curlFrame(t, 170);
  }
  final angles = [
    160.0,
    130.0,
    100.0,
    70.0,
    45.0,
    45.0,
    70.0,
    100.0,
    130.0,
    160.0,
    170.0,
    170.0
  ];
  for (var i = 0; i < angles.length; i++) {
    yield curlFrame(1100000 + i * 100000, angles[i]);
  }
}

void main() {
  for (final kind in ['curl', 'calf', 'lateral']) {
    for (final delay in [0, 200000, 300000]) {
      test('$kind delivery delay $delay preserves only fresh observed cycles',
          () {
        final dynamic analyzer = switch (kind) {
          'curl' => CurlAnalyzer(),
          'calf' => CalfRaiseAnalyzer(),
          _ => LateralRaiseAnalyzer(),
        };
        final frames = switch (kind) {
          'curl' => curlTrajectory(),
          'calf' => calfTrajectory(step: 100000),
          _ => lateralRaiseTrajectory(stepMicros: 100000),
        };
        var last = 0;
        for (final frame in frames) {
          last = frame.capturedAtMicros;
          analyzer.update(frame, nowMicros: last + delay);
          analyzer.tick(nowMicros: last + delay + 80000);
        }
        expect(analyzer.snapshot.repetitions, delay <= 200000 ? 1 : 0);
        analyzer.tick(nowMicros: last + delay + 600000);
        expect(analyzer.snapshot.health, TrackingStatus.lost);
        expect(analyzer.snapshot.needsCalibration, isTrue);
      });
    }
  }
}
