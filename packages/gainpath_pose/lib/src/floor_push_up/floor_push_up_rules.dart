import 'dart:convert';

/// Development parameters, NOT validated biomechanical standards. A changed
/// configuration must have a different version so history cannot pool scores.
class FloorPushUpRules {
  FloorPushUpRules({
    this.version = defaultVersion,
    this.topAngle = 155,
    this.bottomAngle = 105,
    this.leaveTopAngle = 145,
    this.reversalDegrees = 8,
    this.minimumExcursion = 25,
    this.minimumVisibility = .65,
    this.maximumBodySlope = .65,
    this.maximumShoulderWidthRatio = .35,
    this.minimumBodyLength = .30,
    this.hipTolerance = .045,
    this.hipMaximumPenalty = .14,
    this.worldAngleTolerance = 25,
    this.maximumAngularSpeed = 500,
    this.maximumLimbChange = .25,
    this.maximumAnchorDrift = .18,
    this.smoothingCutoff = 3,
    this.smoothingBeta = .015,
    this.readyHoldMicros = 300000,
    this.phaseHoldMicros = 120000,
    this.minimumRepMicros = 900000,
    this.minimumTravelMicros = 150000,
    this.maximumAttemptMicros = 60000000,
    this.maximumFrameAgeMicros = 250000,
    this.romWeight = .40,
    this.alignmentWeight = .35,
    this.controlWeight = .15,
    this.extensionWeight = .10,
  }) {
    final values = toJson().values.whereType<num>();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(version) ||
        values.any((v) => !v.isFinite || v <= 0) ||
        !(bottomAngle < leaveTopAngle &&
            leaveTopAngle < topAngle &&
            topAngle < 180) ||
        minimumVisibility > 1 ||
        maximumShoulderWidthRatio > 1 ||
        hipTolerance >= hipMaximumPenalty ||
        (romWeight + alignmentWeight + controlWeight + extensionWeight - 1)
                .abs() >
            1e-9 ||
        maximumFrameAgeMicros < phaseHoldMicros ||
        maximumAttemptMicros <= minimumRepMicros) {
      throw ArgumentError('Invalid floor push-up rules.');
    }
    if (version == defaultVersion &&
        jsonEncode(toJson()) != jsonEncode(defaults)) {
      throw ArgumentError('Changed rules require a new scoring version.');
    }
  }
  static const defaultVersion = 'standard-floor-push-up-side-v1';
  static const sourceVersion = 'floor-push-up-2d-crosscheck-v1';
  static final Map<String, Object> defaults = Map.unmodifiable(_defaultJson());
  // Kept independent of constructor validation to avoid static recursion.
  static Map<String, Object> _defaultJson() => {
        'version': defaultVersion,
        'topAngle': 155.0,
        'bottomAngle': 105.0,
        'leaveTopAngle': 145.0,
        'reversalDegrees': 8.0,
        'minimumExcursion': 25.0,
        'minimumVisibility': .65,
        'maximumBodySlope': .65,
        'maximumShoulderWidthRatio': .35,
        'minimumBodyLength': .30,
        'hipTolerance': .045,
        'hipMaximumPenalty': .14,
        'worldAngleTolerance': 25.0,
        'maximumAngularSpeed': 500.0,
        'maximumLimbChange': .25,
        'maximumAnchorDrift': .18,
        'smoothingCutoff': 3.0,
        'smoothingBeta': .015,
        'readyHoldMicros': 300000,
        'phaseHoldMicros': 120000,
        'minimumRepMicros': 900000,
        'minimumTravelMicros': 150000,
        'maximumAttemptMicros': 60000000,
        'maximumFrameAgeMicros': 250000,
        'romWeight': .40,
        'alignmentWeight': .35,
        'controlWeight': .15,
        'extensionWeight': .10,
      };
  final String version;
  final double topAngle,
      bottomAngle,
      leaveTopAngle,
      reversalDegrees,
      minimumExcursion,
      minimumVisibility,
      maximumBodySlope,
      maximumShoulderWidthRatio,
      minimumBodyLength,
      hipTolerance,
      hipMaximumPenalty,
      worldAngleTolerance,
      maximumAngularSpeed,
      maximumLimbChange,
      maximumAnchorDrift,
      smoothingCutoff,
      smoothingBeta,
      romWeight,
      alignmentWeight,
      controlWeight,
      extensionWeight;
  final int readyHoldMicros,
      phaseHoldMicros,
      minimumRepMicros,
      minimumTravelMicros,
      maximumAttemptMicros,
      maximumFrameAgeMicros;
  Map<String, Object> toJson() => {
        'version': version,
        'topAngle': topAngle,
        'bottomAngle': bottomAngle,
        'leaveTopAngle': leaveTopAngle,
        'reversalDegrees': reversalDegrees,
        'minimumExcursion': minimumExcursion,
        'minimumVisibility': minimumVisibility,
        'maximumBodySlope': maximumBodySlope,
        'maximumShoulderWidthRatio': maximumShoulderWidthRatio,
        'minimumBodyLength': minimumBodyLength,
        'hipTolerance': hipTolerance,
        'hipMaximumPenalty': hipMaximumPenalty,
        'worldAngleTolerance': worldAngleTolerance,
        'maximumAngularSpeed': maximumAngularSpeed,
        'maximumLimbChange': maximumLimbChange,
        'maximumAnchorDrift': maximumAnchorDrift,
        'smoothingCutoff': smoothingCutoff,
        'smoothingBeta': smoothingBeta,
        'readyHoldMicros': readyHoldMicros,
        'phaseHoldMicros': phaseHoldMicros,
        'minimumRepMicros': minimumRepMicros,
        'minimumTravelMicros': minimumTravelMicros,
        'maximumAttemptMicros': maximumAttemptMicros,
        'maximumFrameAgeMicros': maximumFrameAgeMicros,
        'romWeight': romWeight,
        'alignmentWeight': alignmentWeight,
        'controlWeight': controlWeight,
        'extensionWeight': extensionWeight,
      };
}
