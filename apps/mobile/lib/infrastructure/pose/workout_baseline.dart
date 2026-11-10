import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import '../../features/workout/application/guided_workout_progress.dart';
import '../../features/workout/application/measured_workout_session.dart';
import '../../features/workout/application/workout_audio_controller.dart';
import '../../features/workout/domain/workout_audio_trace.dart';
import '../../features/workout/domain/workout_performance_diagnostics.dart';

export '../../features/workout/domain/workout_performance_diagnostics.dart';

const workoutBaselineEnabled =
    !kReleaseMode && bool.fromEnvironment('GAINPATH_WORKOUT_BASELINE');

WorkoutPerformanceDiagnostics? createWorkoutBaseline(
        WorkoutBaselineExercise exercise, int Function() clock) =>
    !workoutBaselineEnabled
        ? null
        : WorkoutPerformanceDiagnostics(
            exercise: exercise,
            clockMicros: clock,
            onReport: (value) =>
                debugPrint('WORKOUT_BASELINE ${jsonEncode(value)}'));

WorkoutAudioTrace? baselineAudioTrace(
        WorkoutPerformanceDiagnostics? baseline, int Function() clock) =>
    baseline == null
        ? null
        : WorkoutAudioTrace(clockMicros: clock, onRecord: baseline.audio);

/// Observes the existing session snapshots after analyzer delivery. Never feeds
/// the held/display pose back into analysis or changes readiness/counting.
class WorkoutBaselineBinding {
  WorkoutBaselineBinding(
      {required this.session,
      required this.baseline,
      required WorkoutAudioController audio,
      required WorkoutAudioTrace trace}) {
    session.preview.baseline = baseline;
    audio.trace = trace;
    session.addListener(_observe);
    session.preview.addListener(_observe);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      try {
        baseline.sample(WorkoutMetric.rssBytes, ProcessInfo.currentRss);
      } catch (_) {/* RSS is not supported by every test/runtime platform. */}
      baseline.report();
    });
  }
  final MeasuredWorkoutSession session;
  final WorkoutPerformanceDiagnostics baseline;
  Timer? _timer;
  bool _disposed = false;
  void _observe() {
    final working = session.viewPhase == MeasuredWorkoutPhase.active &&
        !session.isPaused &&
        (session.guidance == null ||
            session.guidance!.stage == GuidedWorkoutStage.working);
    baseline.setWorking(working);
    final analysis = session.analysis, frame = session.preview.frame;
    if (working &&
        frame != null &&
        session.analysisAvailable &&
        analysis != null &&
        analysis.health == TrackingStatus.healthy &&
        !analysis.needsCalibration) {
      baseline.accepted(frame.capturedAtMicros);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    session.removeListener(_observe);
    session.preview.removeListener(_observe);
    baseline.setWorking(false);
    baseline.report(force: true);
    // Native/camera teardown reports resource closure asynchronously. Do not
    // freeze the recorder before those existing owners finish disposing.
  }
}
