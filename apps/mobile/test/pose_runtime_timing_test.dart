import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_runtime_timing.dart';

void main() {
  test(
      'bounded aggregate reports distinguish processing, delivery gaps and discards',
      () {
    final reports = <Map<String, Object>>[];
    final t = PoseRuntimeTiming(onReport: reports.add, maximumReports: 2);
    t.processed(180000);
    t.delivered(200000, 200000);
    t.discarded('stale_result');
    t.delivered(1300000, 220000);
    expect(reports.last['maximumDeliveryGapMicros'], 1100000);
    expect(reports.last['maximumProcessingMicros'], 180000);
    expect(reports.last['staleResults'], 1);
    for (var i = 2; i < 20; i++) {
      t.delivered(i * 1000000, 100000);
    }
    expect(reports.length, 2);
  });
}
