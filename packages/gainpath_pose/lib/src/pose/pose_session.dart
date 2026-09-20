import 'audio_cue_arbiter.dart';
import 'form_score.dart';
import 'pose_detector.dart';
import 'pose_frame.dart';
import 'repetition_fsm.dart';
import 'tracking_health.dart';

class PoseSessionResult {
  const PoseSessionResult({
    required this.frame,
    required this.health,
    required this.repetition,
    required this.score,
  });

  final PoseFrame frame;
  final TrackingHealth health;
  final RepetitionUpdate repetition;
  final FormScore score;
}

/// Coordinates pure pose processing without depending on Flutter, camera
/// plugins, Firebase or audio playback.
class PoseSessionCoordinator {
  PoseSessionCoordinator({
    required this.detector,
    required this.healthMonitor,
    required this.repetition,
    this.cues,
  });

  final PoseDetector detector;
  final TrackingHealthMonitor healthMonitor;
  final RepetitionFsm repetition;
  final AudioCueArbiter? cues;
  int? _trackedFromMicros;
  int _repCount = 0;

  Future<PoseSessionResult> process(
    PoseInput input, {
    required double movementMetric,
    double deviation = 0,
  }) async {
    final frame = await detector.detect(input);
    final health = healthMonitor.update(frame);
    if (health.status == TrackingStatus.healthy) {
      _trackedFromMicros ??= frame.capturedAtMicros;
      final repetition = this.repetition.update(movementMetric);
      _repCount = repetition.count;
      final score = FormScore.calculate(
        confidence: health.visibleLandmarks / frame.landmarks.length,
        deviation: deviation,
        trackedDurationMicros: frame.capturedAtMicros - _trackedFromMicros!,
      );
      return PoseSessionResult(
        frame: frame,
        health: health,
        repetition: repetition,
        score: score,
      );
    }
    return PoseSessionResult(
      frame: frame,
      health: health,
      repetition: RepetitionUpdate(
        count: _repCount,
        phase: RepetitionPhase.ready,
        completed: false,
      ),
      score: FormScore.calculate(
        confidence: health.visibleLandmarks / frame.landmarks.length,
        deviation: 1,
        trackedDurationMicros: 0,
      ),
    );
  }
}
