import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'support/shoulder_press_trajectory.dart';

void main() {
  test('200ms delivery latency plus watchdog ticks preserves observed cycle', () {
    final a = ShoulderPressAnalyzer();
    for (final f in shoulderPressTrajectory(stepMicros: 100000)) {
      a.update(f, nowMicros: f.capturedAtMicros + 200000);
      a.tick(nowMicros: f.capturedAtMicros + 280000);
    }
    expect(a.snapshot.repetitions, 1);
    expect(a.snapshot.needsCalibration, false);
    final lost = a.tick(nowMicros: 3900000);
    expect(lost.health, TrackingStatus.lost);
    expect(lost.needsCalibration, true);
  });
  test('recent delivery never authorizes stale capture', () {
    final a = ShoulderPressAnalyzer();
    for (final f in shoulderPressTrajectory()) {
      a.update(f, nowMicros: f.capturedAtMicros + 300000);
    }
    expect(a.snapshot.repetitions, 0);
    expect(a.snapshot.needsCalibration, true);
  });
}
