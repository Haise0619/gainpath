import 'floor_push_up_geometry.dart';

enum FloorPushUpWorldDecision {
  absent,
  agreed,
  fallback2d,
  pendingContradiction,
  confirmedContradiction
}

/// Image visibility is not an independent estimate of depth reliability. Only
/// persistent, plausible disagreement in BOTH projected and 3D angles can veto
/// otherwise usable image geometry. Every fallback remains unscored.
class FloorPushUpWorldEvidence {
  static const revision = 'floor-world-projection-stability-v2';
  static const minimumConfidence = .85;
  static const confirmationMicros = 300000;
  static const minimumSamples = 3;
  static const maximumResidualChange = 12.0;
  static const maximumLengthChange = .15;
  int? _since, _last;
  int _samples = 0;
  List<double>? _residuals;
  double? _length;
  List<double>? _anchorResiduals;
  double? _anchorLength;
  void reset() {
    _since = null;
    _last = null;
    _samples = 0;
    _residuals = null;
    _length = null;
    _anchorResiduals = null;
    _anchorLength = null;
  }

  Map<String, Object?> get diagnostics => {
        'worldPolicyVersion': revision,
        'worldConflictSinceMicros': _since,
        'worldConflictSamples': _samples,
        'worldMinimumConfidence': minimumConfidence,
        'worldConfirmationMicros': confirmationMicros,
        'worldWindowLengthChange': _length == null || _anchorLength == null
            ? null
            : (_length! / _anchorLength! - 1).abs(),
      };
  FloorPushUpWorldDecision observe(FloorPushUpGeometry? g, int t,
      {required int maximumGapMicros}) {
    if (g == null || g.worldStatus != FloorPushUpWorldStatus.contradictory) {
      reset();
      return g?.worldStatus == FloorPushUpWorldStatus.absent
          ? FloorPushUpWorldDecision.absent
          : g?.worldStatus == FloorPushUpWorldStatus.consistent
              ? FloorPushUpWorldDecision.agreed
              : FloorPushUpWorldDecision.fallback2d;
    }
    if (g.confidence < minimumConfidence ||
        g.worldMinimumConfidence < minimumConfidence) {
      reset();
      return FloorPushUpWorldDecision.fallback2d;
    }
    final residuals = [
      g.worldElbowAngleDegrees! - g.elbowAngleDegrees,
      g.worldProjectedElbowAngle! - g.elbowAngleDegrees,
      g.worldBodyAngleDegrees! - g.bodyAngleDegrees,
      g.worldProjectedBodyAngle! - g.bodyAngleDegrees
    ];
    final length = g.worldBodyLength!;
    final stable = _last != null &&
        t > _last! &&
        t - _last! <= maximumGapMicros &&
        List.generate(
            4,
            (i) =>
                (residuals[i] - _residuals![i]).abs() <=
                    maximumResidualChange &&
                (residuals[i] - _anchorResiduals![i]).abs() <=
                    maximumResidualChange).every((v) => v) &&
        (length / _length! - 1).abs() <= maximumLengthChange &&
        (length / _anchorLength! - 1).abs() <= maximumLengthChange;
    if (!stable) {
      _since = t;
      _samples = 0;
      _anchorResiduals = List.of(residuals);
      _anchorLength = length;
    }
    _samples++;
    _last = t;
    _residuals = residuals;
    _length = length;
    return _samples >= minimumSamples && t - _since! >= confirmationMicros
        ? FloorPushUpWorldDecision.confirmedContradiction
        : FloorPushUpWorldDecision.pendingContradiction;
  }
}
