import '../pose/audio_cue_arbiter.dart';
import '../pose/tracking_health.dart';
import 'squat_geometry.dart';

enum SquatPhase { ready, eccentric, inflection, concentric }

enum SquatDeviationKind { trunkLean, incompleteDepth }

class SquatDeviation {
  const SquatDeviation(this.kind, this.degrees);
  final SquatDeviationKind kind;
  final double degrees;
}

/// One finished assessable attempt. Partial attempts are distinct from reps.
class SquatAttempt {
  SquatAttempt(
      {required this.number,
      required this.complete,
      required this.minimumKneeAngleDegrees,
      required this.durationMicros,
      required this.scorePercent,
      required List<SquatDeviation> deviations})
      : deviations = List.unmodifiable(deviations);
  final int number, durationMicros;
  final bool complete;
  final double minimumKneeAngleDegrees, scorePercent;
  final List<SquatDeviation> deviations;
}

/// Bounded state snapshot: no recorded landmark trajectory or persistence claim.
class SquatUpdate {
  SquatUpdate(
      {required this.capturedAtMicros,
      required this.health,
      required this.needsCalibration,
      required this.phase,
      required this.selectedSide,
      required this.geometry,
      required this.angularVelocityDegreesPerSecond,
      required this.repetitions,
      required this.partialRepetitions,
      required this.trackedDurationMicros,
      required this.rejectedDurationMicros,
      required this.formScorePercent,
      required this.trackingConfidence,
      required this.completedAttempt,
      required List<CueRequest> cues})
      : cues = List.unmodifiable(cues);
  final int capturedAtMicros, repetitions, partialRepetitions;
  final int trackedDurationMicros, rejectedDurationMicros;
  final TrackingStatus health;
  final bool needsCalibration;
  final SquatPhase phase;
  final SquatSide? selectedSide;
  final SquatGeometry? geometry;
  final double? angularVelocityDegreesPerSecond, formScorePercent;
  final double trackingConfidence;
  final SquatAttempt? completedAttempt;
  final List<CueRequest> cues;
}
