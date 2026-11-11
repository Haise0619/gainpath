import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FrameTiming;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import '../../features/workout/application/guided_workout_progress.dart';
import '../../features/workout/application/measured_workout_session.dart';
import '../../features/workout/application/pose_preview_controller.dart';
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
    WidgetsBinding.instance.addTimingsCallback(_recordFrameTimings);
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

  // Frame timings are app-wide engine samples delivered in batches while the
  // route is bound. They do not isolate the skeleton or measure display present.
  void _recordFrameTimings(List<FrameTiming> frames) {
    if (_disposed || session.viewPhase != MeasuredWorkoutPhase.active) return;
    final refreshRate = WidgetsBinding
        .instance.platformDispatcher.implicitView?.display.refreshRate;
    final budget =
        refreshRate != null && refreshRate.isFinite && refreshRate > 0
            ? (1000000 / refreshRate).round()
            : null;
    for (final frame in frames) {
      baseline.sample(
          WorkoutMetric.uiBuildMicros, frame.buildDuration.inMicroseconds);
      baseline.sample(
          WorkoutMetric.rasterMicros, frame.rasterDuration.inMicroseconds);
      baseline.sample(
          WorkoutMetric.frameSpanMicros, frame.totalSpan.inMicroseconds);
      if (budget != null) {
        baseline.sample(WorkoutMetric.frameBudgetMicros, budget);
        if (frame.buildDuration.inMicroseconds > budget) {
          baseline.count(WorkoutSignal.uiBuildOverBudget);
        }
        if (frame.rasterDuration.inMicroseconds > budget) {
          baseline.count(WorkoutSignal.rasterOverBudget);
        }
      }
    }
  }

  void _observe() {
    final working = session.viewPhase == MeasuredWorkoutPhase.active &&
        !session.isPaused &&
        (session.guidance == null ||
            session.guidance!.stage == GuidedWorkoutStage.working);
    baseline.setWorking(working);
    baseline.setResting(session.viewPhase == MeasuredWorkoutPhase.active &&
        session.preview.phase == PosePreviewPhase.tracking &&
        session.guidance?.stage == GuidedWorkoutStage.resting);
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
    WidgetsBinding.instance.removeTimingsCallback(_recordFrameTimings);
    baseline.setWorking(false);
    baseline.setResting(false);
    baseline.report(force: true);
    // Native/camera teardown reports resource closure asynchronously. Do not
    // freeze the recorder before those existing owners finish disposing.
  }
}
