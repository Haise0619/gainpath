import 'dart:math' as math;
import '../pose/pose_frame.dart';
import '../pose/one_euro_filter.dart';
import '../pose/tracking_health.dart';
import '../pose/audio_cue_arbiter.dart';
import 'floor_push_up_geometry.dart';
import 'floor_push_up_rules.dart';
import 'floor_push_up_diagnostics.dart';
import 'floor_push_up_world_evidence.dart';
import 'floor_push_up_projection_evidence.dart';
import 'floor_push_up_top_evidence.dart';

enum FloorPushUpPhase { ready, top, descending, bottom, ascending }

enum FloorPushUpIssue {
  insufficientDescent,
  hipSagging,
  hipPiking,
  incompleteExtension,
  unstableTracking,
  interrupted,
  movementTooFast
}

class FloorPushUpComponents {
  const FloorPushUpComponents(this.rangeOfMotion, this.bodyAlignment,
      this.movementControl, this.armExtension);
  final double rangeOfMotion, bodyAlignment, movementControl, armExtension;
  double weighted(FloorPushUpRules r) =>
      rangeOfMotion * r.romWeight +
      bodyAlignment * r.alignmentWeight +
      movementControl * r.controlWeight +
      armExtension * r.extensionWeight;
  Map<String, double> toJson() => {
        'rangeOfMotion': rangeOfMotion,
        'bodyAlignment': bodyAlignment,
        'movementControl': movementControl,
        'armExtension': armExtension
      };
}

class FloorPushUpUpdate {
  const FloorPushUpUpdate(
      {required this.repetitions,
      required this.partialRepetitions,
      required this.trackedDurationMicros,
      required this.rejectedDurationMicros,
      required this.health,
      required this.selectedSide,
      required this.phase,
      required this.formScorePercent,
      required this.components,
      required this.calibrationProgress,
      required this.geometry,
      required this.issues,
      required this.issueCounts,
      required this.cues,
      this.observationAccepted = false,
      this.rejection = FloorPushUpRejection.none,
      this.temporaryDropout = false});
  final bool temporaryDropout;
  /// Geometry acceptance is independent of READY/phase reacquisition.
  final bool observationAccepted;
  final FloorPushUpRejection rejection;
  final int repetitions,
      partialRepetitions,
      trackedDurationMicros,
      rejectedDurationMicros;
  final TrackingStatus health;
  final FloorPushUpSide? selectedSide;
  final FloorPushUpPhase phase;
  final double? formScorePercent;
  final FloorPushUpComponents? components;
  final double calibrationProgress;
  final FloorPushUpGeometry? geometry;
  final Set<FloorPushUpIssue> issues;
  final Map<FloorPushUpIssue, int> issueCounts;
  final List<CueRequest> cues;
  bool get needsCalibration => phase == FloorPushUpPhase.ready;
  String get calibrationCue => floorPushUpReadinessMessage(rejection);
}

/// A full count requires a continuously observed TOP→BOTTOM→TOP cycle.
/// Poor alignment affects quality, not depth/extension count validity.
class FloorPushUpAnalyzer {
  FloorPushUpAnalyzer({FloorPushUpRules? rules})
      : rules = rules ?? FloorPushUpRules();
  static const version = FloorPushUpRules.defaultVersion;
  static const maximumFrameAgeMicros = 250000;
  // Development continuity policy, separate from the unchanged scoring rules.
  // The recorded recovery endpoints differ by 6.49 and 18.74 degrees. Only a
  // single rejected projection at an already observed bottom can use this bound.
  static const limbContinuityVersion = 'floor-phase-limb-continuity-v2';
  static const maximumLimbRecoveryAngleChange = 20.0;
  final FloorPushUpRules rules;
  FloorPushUpSide? _side;
  FloorPushUpGeometry? _geometry, _baseline;
  FloorPushUpPhase _phase = FloorPushUpPhase.ready;
  TrackingStatus _health = TrackingStatus.degraded;
  OneEuroFilter? _filter;
  int? _lastCapture,
      _lastNow,
      _holdSince,
      _attemptStart,
      _bottomAt,
      _ascendAt,
      _turnSince;
  String? _detector, _model;
  (int, int)? _dimensions;
  int _reps = 0, _partial = 0, _tracked = 0, _rejected = 0, _scored = 0;
  double _angle = 180,
      _minimum = 180,
      _returnMaximum = 0,
      _maxHip = 0,
      _peakSpeed = 0,
      _topAngle = 180,
      _startAngle = 180;
  final _totals = [0.0, 0.0, 0.0, 0.0];
  bool _bottomValid = false, _unscoredAttempt = false;
  Set<FloorPushUpIssue> _issues = {};
  final Map<FloorPushUpIssue, int> _issueCounts = {};
  final Set<FloorPushUpIssue> _attemptIssues = {};
  List<CueRequest> _cues = [];
  FloorPushUpRejection _rejection = FloorPushUpRejection.waitingTop;
  FloorPushUpGeometryObservation _observation =
      FloorPushUpGeometryObservation();
  int? _lastAcceptedCapture;
  int? _lastAcceptedDelivery;
  int? _lastFrameDelivery;
  double? _lastAcceptedRawAngle;
  bool _temporarilyMissing = false;
  bool _pendingLimbRecovery = false;
  bool _projectionValidated = false;
  bool _projectionTrajectoryActive = false;
  final _projectionEvidence = FloorPushUpProjectionEvidence();
  String _limbContinuityDecision = 'none';
  bool _sideLocked = false;
  final _worldEvidence = FloorPushUpWorldEvidence();
  FloorPushUpWorldDecision _worldDecision = FloorPushUpWorldDecision.absent;
  bool _worldFallback = false, _baselineUnscored = false;
  String? _resetReason;
  String? _resetFromPhase;
  int? _resetCaptureMicros;
  FloorPushUpRejection _currentGeometryRejection = FloorPushUpRejection.noPose;
  final _topEvidence = FloorPushUpTopEvidence();
  Map<String, Object?> _lastTopEvidence = {};
  int? _kneeSince, _kneeLast;
  int _kneeSamples = 0;
  FloorPushUpSide? _kneeSide;

  /// Explicitly requested local inspection only; never logged or persisted.
  Map<String, Object?> get diagnostics => {
        'trackingRevision': 'floor-geometry-recovery-v6',
        'geometryVersion': 'floor-short-side-v2',
        'poseDetection': _observation.measurements['poseDetected'] == true
            ? 'detected'
            : 'missing',
        'geometryAcceptance':
            _lastAcceptedCapture != null && _lastAcceptedCapture == _lastCapture
                ? 'accepted'
                : 'rejected',
        'geometryRejection': _currentGeometryRejection.name,
        'capturedAtMicros': _lastCapture,
        'deliveredAtMicros': _lastNow,
        'lastAcceptedCaptureMicros': _lastAcceptedCapture,
        'lastAcceptedDeliveryMicros': _lastAcceptedDelivery,
        'acceptedCaptureAgeMicros':
            _lastAcceptedCapture == null || _lastCapture == null
                ? null
                : _lastCapture! - _lastAcceptedCapture!,
        'acceptedDeliveryAgeMicros':
            _lastAcceptedDelivery == null || _lastNow == null
                ? null
                : _lastNow! - _lastAcceptedDelivery!,
        'selectedSide': _side?.name,
        'phase': _phase.name,
        'health': _health.name,
        'sideLocked': _sideLocked,
        'smoothedElbow': _filter == null ? null : _angle,
        'dwellSinceMicros': _holdSince,
        'dwellObservedMicros':
            _holdSince == null || _lastAcceptedCapture == null
                ? 0
                : _lastAcceptedCapture! - _holdSince!,
        'bottomCredit': _bottomValid,
        'resetReason': _resetReason,
        'resetFromPhase': _resetFromPhase,
        'resetCaptureMicros': _resetCaptureMicros,
        ..._topEvidence.diagnostics,
        'topRequiredDwellMicros': rules.phaseHoldMicros,
        'topAngleThreshold': rules.topAngle,
        'bottomAngleThreshold': rules.bottomAngle,
        ..._lastTopEvidence,
        'kneeCandidateSamples': _kneeSamples,
        'kneeCandidateSpanMicros': _kneeLast == null || _kneeSince == null
            ? 0
            : _kneeLast! - _kneeSince!,
        'repetitions': _reps,
        'partialRepetitions': _partial,
        'temporaryDropout': _temporarilyMissing,
        'limbContinuityVersion': limbContinuityVersion,
        'limbRecoveryPending': _pendingLimbRecovery,
        'limbContinuityDecision': _limbContinuityDecision,
        'limbRecoveryMaximumAngleChange': maximumLimbRecoveryAngleChange,
        'limbRecoveryMaximumGapMicros': rules.maximumFrameAgeMicros,
        'formUnavailable': _unscoredAttempt,
        'projectionRevalidated': _projectionValidated,
        'projectionTrajectoryActive': _projectionTrajectoryActive,
        ..._projectionEvidence.diagnostics,
        ..._observation.toJson(),
        ..._worldEvidence.diagnostics,
        'worldDecision': _worldDecision.name,
        'unscoredFallback':
            _worldFallback || _geometry?.legacyScoreCompatible == false,
        'rejection': _rejection.name,
      };
  FloorPushUpComponents? get _components => _scored == 0 || _unscoredAttempt
      ? null
      : FloorPushUpComponents(_totals[0] / _scored, _totals[1] / _scored,
          _totals[2] / _scored, _totals[3] / _scored);
  FloorPushUpUpdate get snapshot => FloorPushUpUpdate(
      repetitions: _reps,
      partialRepetitions: _partial,
      trackedDurationMicros: _tracked,
      rejectedDurationMicros: _rejected,
      health: _health,
      selectedSide: _side,
      phase: _phase,
      formScorePercent: _components?.weighted(rules),
      components: _components,
      calibrationProgress: _phase != FloorPushUpPhase.ready
          ? 1
          : _holdSince == null || _lastCapture == null
              ? 0
              : ((_lastCapture! - _holdSince!) / rules.readyHoldMicros)
                  .clamp(0, 1),
      geometry: _geometry,
      issues: Set.unmodifiable(_issues),
      issueCounts: Map.unmodifiable(_issueCounts),
      cues: List.unmodifiable(_cues),
      observationAccepted: _lastAcceptedCapture != null &&
          _lastAcceptedCapture == _lastCapture &&
          _health != TrackingStatus.lost,
      rejection: _rejection,
      temporaryDropout: _temporarilyMissing);
  void _issue(FloorPushUpIssue issue) {
    _issues.add(issue);
    if (_attemptStart != null) _attemptIssues.add(issue);
  }

  void _reset({bool interrupted = false, String? reason}) {
    if (reason != null) _resetReason = reason;
    _resetFromPhase = _phase.name;
    _resetCaptureMicros = _lastCapture;
    _topEvidence.reset();
    if (_pendingLimbRecovery) _limbContinuityDecision = 'interrupted';
    _pendingLimbRecovery = false;
    _projectionValidated = false;
    _projectionTrajectoryActive = false;
    _projectionEvidence.reset();
    if (_attemptStart != null &&
        interrupted &&
        _startAngle - _minimum >= rules.minimumExcursion) {
      _partial++;
      _unscoredAttempt = true;
      _attemptIssues.add(FloorPushUpIssue.interrupted);
      if (_phase == FloorPushUpPhase.ascending && _bottomValid) {
        _attemptIssues.add(FloorPushUpIssue.incompleteExtension);
      }
      for (final i in _attemptIssues) {
        _issueCounts[i] = (_issueCounts[i] ?? 0) + 1;
      }
      _issues.addAll(_attemptIssues);
    }
    _attemptStart = null;
    _bottomAt = null;
    _ascendAt = null;
    _holdSince = null;
    _turnSince = null;
    _bottomValid = false;
    _phase = FloorPushUpPhase.ready;
    _filter = null;
    _baseline = null;
    _geometry = null;
    _health = TrackingStatus.degraded;
    _temporarilyMissing = false;
    if (const {
      FloorPushUpRejection.none,
      FloorPushUpRejection.unreliableWorld,
      FloorPushUpRejection.stabilizingTop
    }.contains(_rejection)) {
      _rejection = FloorPushUpRejection.waitingTop;
    }
  }

  void pause() {
    _issues = {};
    _cues = [];
    _projectionValidated = false;
    _rejection = FloorPushUpRejection.waitingTop;
    _resetReason = 'pause';
    _reset(interrupted: true);
    _lastNow = null;
    _lastCapture = null;
    _worldEvidence.reset();
  }

  /// Finalizes an observed unfinished attempt once; never invents a return.
  void finish() {
    _resetReason = 'finish';
    _reset(interrupted: true);
  }

  void _warning() {
    _issue(FloorPushUpIssue.unstableTracking);
    _cues = const [
      CueRequest(
          id: 'floor_tracking',
          text: 'Adjust your camera position.',
          priority: CuePriority.warning)
    ];
  }

  FloorPushUpUpdate tick({required int nowMicros}) {
    if (_lastNow == null || nowMicros <= _lastNow!) return snapshot;
    final elapsed = nowMicros - _lastNow!;
    // Frame age is checked at delivery. A sustainable inference stream can
    // have 200ms latency without being a 200ms result dropout. The watchdog
    // measures absence of accepted results; capture gaps still gate update().
    final lastDelivery = _lastAcceptedDelivery ?? _lastFrameDelivery;
    if (lastDelivery == null ||
        nowMicros - lastDelivery > rules.maximumFrameAgeMicros) {
      _rejected += elapsed;
      _reset(interrupted: true);
      _health = TrackingStatus.lost;
      if (_lastFrameDelivery == null ||
          nowMicros - _lastFrameDelivery! > rules.maximumFrameAgeMicros) {
        _rejection = FloorPushUpRejection.trackingLost;
      }
      _resetReason = 'accepted_result_timeout';
      _warning();
    } else if (_health == TrackingStatus.healthy &&
        _phase != FloorPushUpPhase.ready) {
      _tracked += elapsed;
    } else {
      _rejected += elapsed;
    }
    _lastNow = nowMicros;
    return snapshot;
  }

  bool _held(bool condition, int t, int duration) {
    if (!condition) {
      _holdSince = null;
      return false;
    }
    _holdSince ??= t;
    return t - _holdSince! >= duration;
  }

  void _transition(FloorPushUpPhase phase) {
    _topEvidence.reset();
    _phase = phase;
    _holdSince = null;
  }

  FloorPushUpUpdate update(PoseFrame frame, {required int nowMicros}) {
    final t = frame.capturedAtMicros;
    if (t < 0 ||
        t > nowMicros ||
        (_lastCapture != null && t <= _lastCapture!) ||
        (_lastNow != null && nowMicros < _lastNow!)) {
      return snapshot;
    }
    final elapsed = _lastNow == null ? 0 : nowMicros - _lastNow!;
    final incomingPhase = _phase;
    final gap =
        _lastCapture != null && t - _lastCapture! > rules.maximumFrameAgeMicros;
    final modelChanged = _detector != null &&
        (_detector != frame.detectorId || _model != frame.modelVersion);
    final changed = (_dimensions != null &&
            _dimensions != (frame.imageWidth, frame.imageHeight)) ||
        modelChanged;
    _issues = {};
    _cues = [];
    if (gap || changed) {
      _reset(interrupted: true);
      _worldEvidence.reset();
    }
    _dimensions = (frame.imageWidth, frame.imageHeight);
    _detector = frame.detectorId;
    _model = frame.modelVersion;
    _projectionValidated = false;
    _projectionEvidence.diagnostics.clear();
    final captureElapsed =
        _lastAcceptedCapture == null ? 0 : t - _lastAcceptedCapture!;
    _lastCapture = t;
    _lastNow = nowMicros;
    _lastFrameDelivery = nowMicros;
    final candidate = _side == null
        ? null
        : FloorPushUpGeometry.fromFrame(frame, _side!, rules: rules);
    if (_side == null ||
        (!_sideLocked &&
            _phase == FloorPushUpPhase.ready &&
            (candidate == null || !candidate.usableView(rules)))) {
      final choices = FloorPushUpSide.values.toList()
        ..sort((a, b) => FloorPushUpGeometry.visibility(frame, b)
            .compareTo(FloorPushUpGeometry.visibility(frame, a)));
      for (final side in choices) {
        final g = FloorPushUpGeometry.fromFrame(frame, side, rules: rules);
        if (g != null && g.imageRejection(rules) == FloorPushUpRejection.none) {
          if (_side != side) {
            _filter = null;
            _holdSince = null;
            _temporarilyMissing = false;
            _worldEvidence.reset();
          }
          _side = side;
          break;
        }
      }
    }
    _observation = FloorPushUpGeometryObservation();
    final diagnosticSide = _side ??
        (FloorPushUpGeometry.visibility(frame, FloorPushUpSide.left) >=
                FloorPushUpGeometry.visibility(frame, FloorPushUpSide.right)
            ? FloorPushUpSide.left
            : FloorPushUpSide.right);
    final g = _side == null
        ? FloorPushUpGeometry.fromFrame(frame, diagnosticSide,
            rules: rules, observation: _observation)
        : FloorPushUpGeometry.fromFrame(frame, _side!,
            rules: rules, observation: _observation);
    final kneeCandidate = !gap &&
        !changed &&
        nowMicros - t <= rules.maximumFrameAgeMicros &&
        g?.kneeAngleDegrees != null &&
        g!.kneeAngleDegrees! < 125;
    if (kneeCandidate) {
      if (_kneeLast == null ||
          t - _kneeLast! > rules.maximumFrameAgeMicros ||
          _kneeSide != diagnosticSide) {
        _kneeSince = t;
        _kneeSamples = 0;
      }
      _kneeSamples++;
      _kneeLast = t;
      _kneeSide = diagnosticSide;
    } else {
      _kneeSince = null;
      _kneeLast = null;
      _kneeSamples = 0;
    }
    _worldDecision = _worldEvidence.observe(
        g?.imageRejection(rules) == FloorPushUpRejection.none &&
                nowMicros - t <= rules.maximumFrameAgeMicros &&
                !gap &&
                !changed
            ? g
            : null,
        t,
        maximumGapMicros: rules.maximumFrameAgeMicros);
    _worldFallback = _worldDecision == FloorPushUpWorldDecision.fallback2d ||
        _worldDecision == FloorPushUpWorldDecision.pendingContradiction;
    final acceptedGeometry = g != null &&
        g.imageRejection(rules) == FloorPushUpRejection.none &&
        _worldDecision != FloorPushUpWorldDecision.confirmedContradiction;
    var unstable = false,
        limbChanged = false,
        anchorChanged = false,
        trajectoryFailed = false;
    final base = _baseline;
    if (g != null && base != null) {
      double drift(double x, double y, double bx, double by) =>
          math.sqrt(math.pow(x - bx, 2) + math.pow(y - by, 2)) /
          base.bodyLength;
      final upperChange = (g.upperArmLength / base.upperArmLength - 1).abs();
      final forearmChange = (g.forearmLength / base.forearmLength - 1).abs();
      limbChanged = upperChange > rules.maximumLimbChange ||
          forearmChange > rules.maximumLimbChange;
      anchorChanged = drift(g.wristX, g.wristY, base.wristX, base.wristY) >
              rules.maximumAnchorDrift ||
          drift(g.ankleX, g.ankleY, base.ankleX, base.ankleY) >
              rules.maximumAnchorDrift;
      unstable = limbChanged || anchorChanged;
      _observation.measurements.addAll({
        'upperArmRelativeChange': upperChange,
        'forearmRelativeChange': forearmChange,
        'upperArmSignedChange': g.upperArmLength / base.upperArmLength - 1,
        'forearmSignedChange': g.forearmLength / base.forearmLength - 1,
        'limbChangeSegments': [
          if (upperChange > rules.maximumLimbChange) 'shoulder-elbow',
          if (forearmChange > rules.maximumLimbChange) 'elbow-wrist',
        ],
        'limbChangeThreshold': rules.maximumLimbChange,
        'limbBaselinePhase': 'top',
        'upperArmBaselineLength': base.upperArmLength,
        'forearmBaselineLength': base.forearmLength,
        'limbLengthUnits': 'image-height',
        'wristAnchorDrift': drift(g.wristX, g.wristY, base.wristX, base.wristY),
        'ankleAnchorDrift': drift(g.ankleX, g.ankleY, base.ankleX, base.ankleY),
      });
      final requiresTrajectory = limbChanged || _projectionTrajectoryActive;
      _projectionValidated = requiresTrajectory &&
          acceptedGeometry &&
          !anchorChanged &&
          _projectionEvidence.validate(frame, _side!, g, nowMicros, rules);
      trajectoryFailed = requiresTrajectory &&
          acceptedGeometry &&
          !anchorChanged &&
          !_projectionValidated;
      if (_projectionValidated) {
        _projectionTrajectoryActive = true;
      }
      unstable = (limbChanged && !_projectionValidated) ||
          trajectoryFailed ||
          anchorChanged;
    }
    if (nowMicros - t > rules.maximumFrameAgeMicros ||
        g == null ||
        !acceptedGeometry ||
        unstable ||
        gap ||
        changed) {
      _rejection = nowMicros - t > rules.maximumFrameAgeMicros
          ? FloorPushUpRejection.staleFrame
          : changed
              ? (modelChanged
                  ? FloorPushUpRejection.modelChanged
                  : FloorPushUpRejection.cameraGeometryChanged)
              : gap
                  ? FloorPushUpRejection.frameGap
                  : limbChanged || trajectoryFailed
                      ? FloorPushUpRejection.limbChange
                      : unstable
                          ? FloorPushUpRejection.anchorDrift
                          : _observation.rejection;
      _resetReason = _rejection.name;
      _currentGeometryRejection = _rejection;
      _topEvidence.reset();
      _rejected += elapsed;
      final freshContinuity = !gap &&
          !changed &&
          nowMicros - t <= rules.maximumFrameAgeMicros &&
          _lastAcceptedCapture != null &&
          t - _lastAcceptedCapture! <= rules.maximumFrameAgeMicros &&
          _lastAcceptedDelivery != null &&
          nowMicros - _lastAcceptedDelivery! <= rules.maximumFrameAgeMicros;
      final recoverableLimbChange = freshContinuity &&
          _rejection == FloorPushUpRejection.limbChange &&
          acceptedGeometry &&
          !anchorChanged &&
          g.confidence >= FloorPushUpProjectionEvidence.minimumConfidence &&
          (_phase == FloorPushUpPhase.top ||
              _phase == FloorPushUpPhase.descending ||
              (_phase == FloorPushUpPhase.bottom &&
                  _bottomValid &&
                  _lastAcceptedRawAngle! <= rules.bottomAngle &&
                  g.elbowAngleDegrees <= rules.bottomAngle &&
                  (g.elbowAngleDegrees - _lastAcceptedRawAngle!).abs() <=
                      maximumLimbRecoveryAngleChange));
      final temporary = recoverableLimbChange ||
          (freshContinuity &&
              !_pendingLimbRecovery &&
              const {
                FloorPushUpRejection.noPose,
                FloorPushUpRejection.lowPoseConfidence,
                FloorPushUpRejection.lowLandmarkConfidence,
                FloorPushUpRejection.missingLandmark
              }.contains(_rejection));
      if (temporary) {
        if (recoverableLimbChange) {
          _pendingLimbRecovery = true;
          _projectionTrajectoryActive = true;
          _unscoredAttempt = true;
          _limbContinuityDecision = 'pending_${_phase.name}';
          _resetReason = null; // No phase reset occurred.
        }
        _temporarilyMissing = true;
        _health = TrackingStatus.degraded;
        _geometry = null;
        _cues = [];
        // A missing observation never supplies bottom/return/reversal dwell.
        // TOP acquisition may retain matching extended endpoints only.
        if (_phase != FloorPushUpPhase.ready &&
            _phase != FloorPushUpPhase.top) {
          _holdSince = null;
          _turnSince = null;
        }
        if (recoverableLimbChange) {
          _holdSince = null;
          _turnSince = null;
        }
        if (_attemptStart != null) {
          _unscoredAttempt = true;
          _attemptIssues.add(FloorPushUpIssue.unstableTracking);
        }
        return snapshot;
      }
      if (_pendingLimbRecovery) {
        _resetReason = 'limb_recovery_rejected_${_rejection.name}';
      }
      _issue(FloorPushUpIssue.unstableTracking);
      _reset(interrupted: true);
      _resetFromPhase = incomingPhase.name;
      _resetCaptureMicros = t;
      _warning();
      return snapshot;
    }
    if (_temporarilyMissing) {
      final previousRaw = _lastAcceptedRawAngle!;
      final sameSupportedPhase =
          captureElapsed <= rules.maximumFrameAgeMicros &&
              (_pendingLimbRecovery
                  ? nowMicros - _lastAcceptedDelivery! <=
                          rules.maximumFrameAgeMicros &&
                      _projectionEvidence.validate(
                          frame, _side!, g, nowMicros, rules) &&
                      (_phase == FloorPushUpPhase.top ||
                              _phase == FloorPushUpPhase.descending
                          ? g.elbowAngleDegrees <=
                              previousRaw + rules.reversalDegrees
                          : _phase == FloorPushUpPhase.bottom &&
                              _bottomValid &&
                              previousRaw <= rules.bottomAngle &&
                              g.elbowAngleDegrees <= rules.bottomAngle &&
                              (g.elbowAngleDegrees - previousRaw).abs() <=
                                  maximumLimbRecoveryAngleChange)
                  : _phase == FloorPushUpPhase.ready ||
                          _phase == FloorPushUpPhase.top
                      ? previousRaw >= rules.topAngle &&
                          g.elbowAngleDegrees >= rules.topAngle
                      : (g.elbowAngleDegrees - previousRaw).abs() <=
                              rules.reversalDegrees &&
                          !(_phase == FloorPushUpPhase.descending &&
                              previousRaw > rules.bottomAngle &&
                              g.elbowAngleDegrees <= rules.bottomAngle) &&
                          !(_phase == FloorPushUpPhase.ascending &&
                              previousRaw < rules.topAngle &&
                              g.elbowAngleDegrees >= rules.topAngle));
      if (!sameSupportedPhase) {
        _rejected += elapsed;
        _rejection = FloorPushUpRejection.frameGap;
        _currentGeometryRejection = _rejection;
        _resetReason = _pendingLimbRecovery
            ? 'movement_during_limb_recovery'
            : 'movement_during_dropout';
        _reset(interrupted: true);
        _warning();
        return snapshot;
      }
      if (_pendingLimbRecovery) {
        _limbContinuityDecision = 'recovered_${_phase.name}';
        _pendingLimbRecovery = false;
        _resetReason = null;
      }
      _temporarilyMissing = false;
    }
    _geometry = g;
    _currentGeometryRejection = FloorPushUpRejection.none;
    _lastAcceptedCapture = t;
    _lastAcceptedDelivery = nowMicros;
    _lastAcceptedRawAngle = g.elbowAngleDegrees;
    _projectionEvidence.accept(frame, _side!, g, nowMicros, rules);
    _health = TrackingStatus.healthy;
    _rejection = _worldFallback
        ? FloorPushUpRejection.unreliableWorld
        : FloorPushUpRejection.none;
    if (_projectionValidated) {
      _unscoredAttempt = true;
      _limbContinuityDecision = 'validated_projection';
      _issue(FloorPushUpIssue.unstableTracking);
    }
    if (_attemptStart != null && (_worldFallback || !g.legacyScoreCompatible)) {
      _unscoredAttempt = true;
    }
    final previous = _angle;
    _filter ??= OneEuroFilter(
        minCutoff: rules.smoothingCutoff, beta: rules.smoothingBeta);
    _angle = _filter!.filter(g.elbowAngleDegrees, timestampSeconds: t / 1e6);
    if (_phase == FloorPushUpPhase.ready) {
      _rejection = _angle >= rules.topAngle
          ? FloorPushUpRejection.stabilizingTop
          : FloorPushUpRejection.waitingTop;
      _rejected += elapsed;
      if (_held(_angle >= rules.topAngle, t, rules.readyHoldMicros)) {
        _baseline = g;
        _baselineUnscored = _worldFallback || !g.legacyScoreCompatible;
        _transition(FloorPushUpPhase.top);
        _topAngle = _angle;
        _sideLocked = true;
        _rejection = FloorPushUpRejection.none;
      }
      return snapshot;
    }
    _tracked += elapsed;
    if (_phase == FloorPushUpPhase.top) {
      if (_angle >= rules.topAngle) _topAngle = _angle;
      if (_held(_angle <= rules.leaveTopAngle, t, rules.phaseHoldMicros)) {
        _attemptStart = _holdSince;
        _minimum = _angle;
        _returnMaximum = 0;
        _startAngle = _topAngle;
        _maxHip = 0;
        _peakSpeed = 0;
        _attemptIssues.clear();
        if (_worldFallback || !g.legacyScoreCompatible || _baselineUnscored) {
          _unscoredAttempt = true;
        }
        _bottomValid = false;
        _bottomAt = null;
        _ascendAt = null;
        _transition(FloorPushUpPhase.descending);
      }
      return snapshot;
    }
    _minimum = math.min(_minimum, _angle);
    _maxHip = math.max(_maxHip, g.signedHipDisplacement.abs());
    if (captureElapsed > 0) {
      _peakSpeed = math.max(
          _peakSpeed, (_angle - previous).abs() * 1e6 / captureElapsed);
    }
    if (g.signedHipDisplacement > rules.hipTolerance) {
      _issue(FloorPushUpIssue.hipSagging);
      _cues.add(const CueRequest(
          id: 'floor_sag',
          text: 'Keep your hips aligned.',
          priority: CuePriority.correction));
    } else if (g.signedHipDisplacement < -rules.hipTolerance) {
      _issue(FloorPushUpIssue.hipPiking);
      _cues.add(const CueRequest(
          id: 'floor_pike',
          text: 'Lower your hips slightly.',
          priority: CuePriority.correction));
    }
    if (t - _attemptStart! > rules.maximumAttemptMicros) {
      _reset(interrupted: true, reason: 'attempt_timeout');
      return snapshot;
    }
    if (_phase == FloorPushUpPhase.descending) {
      if (_held(_angle <= rules.bottomAngle, t, rules.phaseHoldMicros)) {
        _bottomValid = true;
        _bottomAt = t;
        _transition(FloorPushUpPhase.bottom);
      } else if (_angle >= _minimum + rules.reversalDegrees &&
          _angle > rules.bottomAngle) {
        _ascendAt = t;
        _transition(FloorPushUpPhase.ascending);
      }
    } else if (_phase == FloorPushUpPhase.bottom) {
      if (_held(_angle >= _minimum + rules.reversalDegrees, t,
          rules.phaseHoldMicros)) {
        _ascendAt = _holdSince;
        _transition(FloorPushUpPhase.ascending);
      }
    } else if (_phase == FloorPushUpPhase.ascending) {
      _returnMaximum = math.max(_returnMaximum, _angle);
      final strictTop =
          _held(_angle >= rules.topAngle, t, rules.phaseHoldMicros);
      final observedTop = _bottomValid &&
          _topEvidence.observe(t,
              rawAngle: g.elbowAngleDegrees,
              smoothedAngle: _angle,
              confidence: g.confidence,
              topAngle: rules.topAngle,
              dwellMicros: rules.phaseHoldMicros,
              maximumGapMicros: rules.maximumFrameAgeMicros);
      if (strictTop || observedTop) {
        _lastTopEvidence = {
          'lastTopConfirmation':
              strictTop ? 'smoothed_dwell' : 'observed_raw_dwell',
          'lastTopConfirmedCaptureMicros': t,
          'lastTopEvidenceStartMicros':
              _topEvidence.diagnostics['topRawHoldSinceMicros'],
          'lastTopEvidenceSpanMicros': _topEvidence.spanMicros,
          'lastTopRawSamples': _topEvidence.diagnostics['topRawSamples'],
        };
        // Expanded counting evidence does not silently enter v1 form groups.
        if (!strictTop) _unscoredAttempt = true;
        _complete(t, extended: true);
        _transition(FloorPushUpPhase.top);
      } else if (_returnMaximum - _minimum >= rules.reversalDegrees &&
          _angle <= _returnMaximum - rules.reversalDegrees) {
        _turnSince ??= t;
        if (t - _turnSince! >= rules.phaseHoldMicros) {
          _complete(t, extended: false);
          _reset(reason: 'incomplete_extension_reversal');
        }
      } else {
        _turnSince = null;
      }
    }
    return snapshot;
  }

  void _complete(int t, {required bool extended}) {
    final duration = t - _attemptStart!;
    // Ignore small/noisy departures; they are not classified as attempts.
    if (_startAngle - _minimum < rules.minimumExcursion) {
      _attemptStart = null;
      return;
    }
    final fast = duration < rules.minimumRepMicros ||
        (_bottomAt != null &&
            _bottomAt! - _attemptStart! < rules.minimumTravelMicros) ||
        (_ascendAt != null && t - _ascendAt! < rules.minimumTravelMicros);
    if (!_bottomValid) {
      _issue(FloorPushUpIssue.insufficientDescent);
      _cues.add(const CueRequest(
          id: 'floor_depth',
          text: 'Lower your chest a little more.',
          priority: CuePriority.correction));
    }
    if (!extended) {
      _issue(FloorPushUpIssue.incompleteExtension);
      _cues.add(const CueRequest(
          id: 'floor_extension',
          text: 'Extend your arms fully.',
          priority: CuePriority.correction));
    }
    if (fast) _issue(FloorPushUpIssue.movementTooFast);
    final full = _bottomValid && extended && !fast;
    if (full) {
      _reps++;
    } else {
      _partial++;
    }
    final c = FloorPushUpComponents(
        (100 - math.max(0, _minimum - rules.bottomAngle) / 50 * 100)
            .clamp(0, 100),
        (100 -
                math.max(0, _maxHip - rules.hipTolerance) /
                    (rules.hipMaximumPenalty - rules.hipTolerance) *
                    100)
            .clamp(0, 100),
        fast
            ? 0
            : (100 -
                    math.max(0, _peakSpeed - rules.maximumAngularSpeed / 2) /
                        (rules.maximumAngularSpeed / 2) *
                        100)
                .clamp(0, 100),
        extended
            ? 100.0
            : (100 - math.max(0, rules.topAngle - _returnMaximum) * 4)
                .clamp(0, 100)
                .toDouble());
    final v = c.toJson().values.toList();
    for (var i = 0; i < 4; i++) {
      _totals[i] += v[i];
    }
    _scored++;
    for (final i in _attemptIssues) {
      _issueCounts[i] = (_issueCounts[i] ?? 0) + 1;
    }
    if (full && _attemptIssues.isEmpty) {
      _cues.add(const CueRequest(
          id: 'floor_good',
          text: 'Good repetition.',
          priority: CuePriority.encouragement));
    }
    _attemptStart = null;
    _bottomAt = null;
    _ascendAt = null;
    // Keep temporal checks through a return into the baseline band. They may
    // stop only after a fully observed TOP return, never on its first frame.
    final g = _geometry, base = _baseline;
    if (extended &&
        g != null &&
        base != null &&
        (g.upperArmLength / base.upperArmLength - 1).abs() <=
            rules.maximumLimbChange &&
        (g.forearmLength / base.forearmLength - 1).abs() <=
            rules.maximumLimbChange) {
      _projectionTrajectoryActive = false;
    }
  }
}
