import 'package:flutter/services.dart';
import '../features/analytics/domain/member_workout_report.dart';

class AndroidWorkoutReportExporter implements WorkoutReportExporter {
  const AndroidWorkoutReportExporter();
  static const _channel = MethodChannel('gainpath/workout_report');
  @override
  Future<bool> save(WorkoutReportDocument document) async =>
      await _channel.invokeMethod<bool>('save', document.toJson()) ?? false;
  @override
  Future<bool> open() async =>
      await _channel.invokeMethod<bool>('open') ?? false;
  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on MissingPluginException {
      // Disposing an untouched report is also supported in non-Android tests.
    } on PlatformException {/* No pending picker needs cancellation. */}
  }
}
