import 'package:test/test.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'squat_analyzer_test.dart' show sample;

void main() {
  test('steady 200ms inference latency does not masquerade as result dropout', () {
    final a=SquatAnalyzer();
    SquatUpdate? u;
    for(var t=100000;t<=2000000;t+=100000){
      u=a.update(sample(t,175),nowMicros:t+200000);
      u=a.tick(nowMicros:t+280000);
    }
    expect(u!.needsCalibration,false);
    expect(u.health,TrackingStatus.healthy);
    final lost=a.tick(nowMicros:2800000);
    expect(lost.needsCalibration,true);
    expect(lost.health,TrackingStatus.lost);
  });
  test('stale captures still cannot calibrate despite recent delivery', () {
    final a=SquatAnalyzer();
    for(var t=100000;t<=1000000;t+=100000){
      expect(a.update(sample(t,175),nowMicros:t+300000).needsCalibration,true);
    }
  });
}
