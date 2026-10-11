/// Versioned engineering defaults, pending labeled-person/device validation.
/// Changing these values requires a new evaluated rule version before release.
class SquatRuleSet {
  SquatRuleSet({
    this.readyAngleDegrees = 160,
    this.depthAngleDegrees = 90,
    this.velocityThreshold = 15,
    this.minimumConfidence = .7,
    this.calibrationMicros = 500000,
    this.calibrationRangeDegrees = 6,
    this.reversalMicros = 150000,
    this.minimumCycleMicros = 600000,
    this.maximumCycleMicros = 10000000,
    this.maximumFrameGapMicros = 250000,
    this.lostAfterMicros = 500000,
    this.trunkLimitDegrees = 45,
    this.deviationDwellMicros = 300000,
  }) {
    if (![
          readyAngleDegrees,
          depthAngleDegrees,
          velocityThreshold,
          minimumConfidence,
          calibrationRangeDegrees,
          trunkLimitDegrees
        ].every((v) => v.isFinite) ||
        depthAngleDegrees <= 0 ||
        readyAngleDegrees <= depthAngleDegrees ||
        readyAngleDegrees >= 180 ||
        velocityThreshold <= 0 ||
        minimumConfidence <= 0 ||
        minimumConfidence > 1 ||
        calibrationRangeDegrees <= 0 ||
        calibrationMicros <= 0 ||
        reversalMicros <= 0 ||
        minimumCycleMicros <= 0 ||
        maximumCycleMicros <= minimumCycleMicros ||
        maximumFrameGapMicros <= 0 ||
        lostAfterMicros < maximumFrameGapMicros ||
        trunkLimitDegrees <= 0 ||
        trunkLimitDegrees >= 90 ||
        deviationDwellMicros <= 0) {
      throw ArgumentError('Invalid provisional squat rule configuration');
    }
  }
  static const version = 'bodyweight-squat-side-v1';
  final double readyAngleDegrees, depthAngleDegrees, velocityThreshold;
  final double minimumConfidence, calibrationRangeDegrees, trunkLimitDegrees;
  final int calibrationMicros, reversalMicros, minimumCycleMicros;
  final int maximumCycleMicros, maximumFrameGapMicros, lostAfterMicros;
  final int deviationDwellMicros;
}
