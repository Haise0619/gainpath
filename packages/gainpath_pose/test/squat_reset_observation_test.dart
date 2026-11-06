import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'squat_analyzer_test.dart' show Rig;

void main() {
  test('brief missing landmark preserves confirmed bottom, watchdog reset records the lost phase', () {
    final r=Rig()..calibrate()..ramp(175,75)..hold(75,8);
    expect(r.analyzer.trackingSnapshot['bottomCredit'],true);
    final missing=r.step(75,missing:true);
    expect(missing.health,TrackingStatus.degraded);
    expect(missing.needsCalibration,false);
    expect(r.analyzer.trackingSnapshot['bottomCredit'],true);
    final oldPhase=missing.phase.name;
    final reset=r.analyzer.tick(nowMicros:r.time+300000);
    expect(reset.needsCalibration,true);
    expect(r.analyzer.trackingSnapshot['bottomCredit'],false);
    final reason=r.analyzer.trackingSnapshot['lastReset'] as Map;
    expect(reason['reason'],'watchdog_stale');
    expect(reason['fromPhase'],oldPhase);
    expect(reason['hadBottomCredit'],true);
    expect(reset.repetitions,0);
  });
}
