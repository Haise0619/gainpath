import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/android_workout_report_exporter.dart';
import 'package:gainpath_mobile/features/analytics/domain/member_workout_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('gainpath/workout_report');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'cancel' ? null : true;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  test('isolated native report channel receives complete text and chart data',
      () async {
    const exporter = AndroidWorkoutReportExporter();
    final doc = WorkoutReportDocument(lines: [
      'Selected routine',
      'session-1'
    ], repTrend: [
      const WorkoutReportDay('2026-10-26', 5, 1, 1000000)
    ], formTrends: [
      WorkoutReportFormChart(
          'Squat / rule1', [const WorkoutReportFormPoint('2026-10-26', 82)])
    ]);
    expect(await exporter.save(doc), true);
    expect(await exporter.open(), true);
    await exporter.cancel();
    expect(calls.map((c) => c.method), ['save', 'open', 'cancel']);
    expect(calls.first.arguments, doc.toJson());
  });
  test('save denial propagates to the screen rather than claiming success',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel,
            (call) async => throw PlatformException(code: 'export-failed'));
    const exporter = AndroidWorkoutReportExporter();
    expect(
        () => exporter.save(WorkoutReportDocument(
            lines: ['report'], repTrend: [], formTrends: [])),
        throwsA(isA<PlatformException>()));
    await exporter.cancel();
  });
}
