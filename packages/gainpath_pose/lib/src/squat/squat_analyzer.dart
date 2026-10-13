import 'dart:math' as math;
import '../pose/audio_cue_arbiter.dart';
import '../pose/pose_frame.dart';
import '../pose/pose_stream.dart';
import '../pose/tracking_health.dart';
import 'squat_geometry.dart';
import 'squat_rule_set.dart';
import 'squat_update.dart';
import 'squat_diagnostics.dart';

/// Provisional side-view squat engine. Feed refined (not already smoothed)
/// upright, unmirrored frames, with a stationary upright camera. This is not
/// a detector, a view classifier, or an authority to persist real activity.
class SquatAnalyzer {
  SquatAnalyzer({SquatRuleSet? rules, this.preferredSide, this.diagnostics})
      : rules = rules ?? SquatRuleSet() {
    diagnostics?.configure(this.rules);
  }
  final SquatDiagnosticRecorder? diagnostics;
  final SquatRuleSet rules;
  final SquatSide? preferredSide;
  final _filter = PoseFrameFilter();
  SquatSide? _side;
  SquatPhase _phase = SquatPhase.ready;
  TrackingStatus _health = TrackingStatus.degraded;
  bool _needsCalibration = true, _paused = false, _previousValid = false;
  int? _lastCapture, _lastNow, _accountedUntil, _lostSince, _standingSince;
  int? _previousAngleTime,
      _cycleStart,
      _depthSince,
      _ascendingSince,
      _leanSince;
  double? _previousAngle, _lastRawAngle;
  double _standingMin = 180, _standingMax = 0, _minimumAngle = 180;
  double _maxLeanDeviation = 0, _scoreSum = 0;
  bool _depthReached = false, _leanCueIssued = false;
  int _reps = 0, _partials = 0, _tracked = 0, _rejected = 0;
  (int, int, String, String, bool)? _identity;
  SquatGeometry? _geometry;
  double? _velocity;
  double _confidence = 0;

  SquatUpdate update(PoseFrame frame, {required int nowMicros}) {
    final time = frame.capturedAtMicros;
    if (time < 0 ||
        nowMicros < time ||
        (_lastNow != null && nowMicros < _lastNow!) ||
        (_lastCapture != null && time <= _lastCapture!)) {
      throw ArgumentError('Squat timestamps must be monotonic and not future');
    }
    final oldCapture = _lastCapture;
    _lastCapture = time;
    _lastNow = nowMicros;
    if (_paused) return _snapshot(time);
    final gap =
        oldCapture != null && time - oldCapture > rules.maximumFrameGapMicros;
    final identity = (
      frame.imageWidth,
      frame.imageHeight,
      frame.detectorId,
      frame.modelVersion,
      frame.isMirrored
    );
    final changed = _identity != null && _identity != identity;
    _identity = identity;
    if (gap || changed) {
      _invalidateCalibration(
          diagnosticReason: changed
              ? SquatDiagnosticReason.geometryChanged
              : SquatDiagnosticReason.frameGap);
    }
    if (nowMicros - time > rules.maximumFrameGapMicros) {
      return _unavailable(time, nowMicros: nowMicros);
    }
    if (_side == null) {
      double usableConfidence(SquatSide side) =>
          SquatGeometry.fromFrame(frame, side) == null
              ? 0
              : SquatGeometry.confidence(frame, side);
      final left = usableConfidence(SquatSide.left);
      final right = usableConfidence(SquatSide.right);
      _side =
          preferredSide ?? (left >= right ? SquatSide.left : SquatSide.right);
    }
    _confidence = SquatGeometry.confidence(frame, _side!);
    final raw = SquatGeometry.fromFrame(frame, _side!);
    if (_confidence < rules.minimumConfidence || raw == null) {
      return _unavailable(time, nowMicros: nowMicros);
    }
    final recovering = _lostSince != null;
    final evaluatedSide = _side!;
    // A short occlusion may retain the phase, but cannot hide an entire ascent.
    if (recovering &&
        (time - _lostSince! >= rules.lostAfterMicros ||
            (_lastRawAngle != null &&
                (raw.kneeAngleDegrees - _lastRawAngle!).abs() > 10))) {
      _invalidateCalibration(
          diagnosticReason: SquatDiagnosticReason.recoveryDiscontinuity);
      _side = evaluatedSide;
    }
    _lostSince = null;
    _health = TrackingStatus.healthy;
    final filtered = _filter.filter(frame);
    _geometry = SquatGeometry.fromFrame(filtered, _side!);
    if (_geometry == null) return _unavailable(time, nowMicros: nowMicros);
    final angle = _geometry!.kneeAngleDegrees;
    diagnostics?.observe(
        time: time, side: _side!, filtered2d: angle, confidence: _confidence);
    _velocity =
        !recovering && _previousAngle != null && _previousAngleTime != null
            ? (angle - _previousAngle!) * 1000000 / (time - _previousAngleTime!)
            : null;
    _account(time, valid: _previousValid && !gap && !changed && !recovering);
    final cues = <CueRequest>[];
    SquatAttempt? completed;
    if (_needsCalibration) {
      _calibrate(angle, time);
    } else {
      completed = _advance(angle, _velocity ?? 0, time, cues);
    }
    _lastRawAngle = raw.kneeAngleDegrees;
    _previousAngle = angle;
    _previousAngleTime = time;
    _previousValid = !_needsCalibration;
    return _snapshot(time, cues: cues, completed: completed);
  }

  /// Called by the application watchdog; repeated ticks cannot duplicate time.
  SquatUpdate tick({required int nowMicros}) {
    if (nowMicros < 0 || (_lastNow != null && nowMicros < _lastNow!)) {
      throw ArgumentError('Watchdog time must be monotonic');
    }
    _lastNow = nowMicros;
    if (!_paused &&
        _lastCapture != null &&
        nowMicros - _lastCapture! > rules.maximumFrameGapMicros) {
      _lostSince ??= _lastCapture;
      _invalidateCalibration(
          diagnosticReason: SquatDiagnosticReason.watchdogStale,
          diagnosticTime: nowMicros);
      _health = nowMicros - _lostSince! >= rules.lostAfterMicros
          ? TrackingStatus.lost
          : TrackingStatus.degraded;
      _account(nowMicros, valid: false);
      _geometry = null;
      _confidence = 0;
    }
    return _snapshot(_lastCapture ?? nowMicros);
  }

  void pause(
      {SquatDiagnosticReason diagnosticReason = SquatDiagnosticReason.paused}) {
    _paused = true;
    _invalidateCalibration(diagnosticReason: diagnosticReason);
    _accountedUntil = null;
    _health = TrackingStatus.degraded;
    _geometry = null;
  }

  void resume() {
    _paused = false;
    _invalidateCalibration();
    _lastCapture = null;
    _accountedUntil = null;
    _lostSince = null;
  }

  void reset() {
    _paused = false;
    _invalidateCalibration();
    _lastCapture = _lastNow = _accountedUntil = _lostSince = null;
    _identity = null;
    _reps = _partials = _tracked = _rejected = 0;
    _scoreSum = _confidence = 0;
    _geometry = null;
    _health = TrackingStatus.degraded;
    diagnostics?.clear();
  }

  SquatUpdate _unavailable(int time, {required int nowMicros}) {
    diagnostics?.unavailable(_confidence);
    _lostSince ??= time;
    _health = nowMicros - _lostSince! >= rules.lostAfterMicros
        ? TrackingStatus.lost
        : TrackingStatus.degraded;
    _account(time, valid: false);
    _previousValid = false;
    _previousAngle = null;
    _previousAngleTime = null;
    _velocity = null;
    _geometry = null;
    _standingSince = _depthSince = _ascendingSince = _leanSince = null;
    _filter.reset();
    if (_health == TrackingStatus.lost) {
      _invalidateCalibration(
          diagnosticReason: SquatDiagnosticReason.trackingLost);
    }
    return _snapshot(time);
  }

  void _calibrate(double angle, int time) {
    if (angle < rules.readyAngleDegrees) {
      _standingSince = null;
      return;
    }
    if (_standingSince == null) {
      _standingSince = time;
      _standingMin = _standingMax = angle;
    }
    _standingMin = math.min(_standingMin, angle);
    _standingMax = math.max(_standingMax, angle);
    if (_standingMax - _standingMin > rules.calibrationRangeDegrees) {
      _standingSince = time;
      _standingMin = _standingMax = angle;
    }
    if (time - _standingSince! >= rules.calibrationMicros) {
      _needsCalibration = false;
      _phase = SquatPhase.ready;
    }
  }

  SquatAttempt? _advance(
      double angle, double velocity, int time, List<CueRequest> cues) {
    if (_cycleStart != null && time - _cycleStart! > rules.maximumCycleMicros) {
      _invalidateCalibration(
          diagnosticReason: SquatDiagnosticReason.cycleTimeout);
      return null;
    }
    if (_phase == SquatPhase.ready) {
      if (angle < rules.readyAngleDegrees &&
          velocity < -rules.velocityThreshold) {
        _phase = SquatPhase.eccentric;
        _cycleStart = time;
        _minimumAngle = angle;
        diagnostics?.begin(time: time, side: _side!);
      }
      return null;
    }
    _minimumAngle = math.min(_minimumAngle, angle);
    if (angle <= rules.depthAngleDegrees) {
      _depthSince ??= time;
      if (time - _depthSince! >= rules.reversalMicros) _depthReached = true;
    } else if (!_depthReached) {
      _depthSince = null;
    }
    if (_geometry!.trunkLeanDegrees > rules.trunkLimitDegrees) {
      _leanSince ??= time;
      if (time - _leanSince! >= rules.deviationDwellMicros) {
        _maxLeanDeviation = math.max(_maxLeanDeviation,
            _geometry!.trunkLeanDegrees - rules.trunkLimitDegrees);
        if (!_leanCueIssued) {
          cues.add(const CueRequest(
              id: 'squat_trunk',
              text: 'Keep your chest up.',
              priority: CuePriority.correction));
          _leanCueIssued = true;
        }
      }
    } else {
      _leanSince = null;
    }
    if (_phase == SquatPhase.eccentric && _depthReached) {
      _phase = SquatPhase.inflection;
    }
    if (_phase == SquatPhase.eccentric || _phase == SquatPhase.inflection) {
      if (velocity > rules.velocityThreshold) {
        _ascendingSince ??= time;
        if (time - _ascendingSince! >= rules.reversalMicros) {
          _phase = SquatPhase.concentric;
        }
      } else {
        _ascendingSince = null;
      }
    }
    // A reversal back down belongs to the same attempt, never a second count.
    if (_phase == SquatPhase.concentric &&
        velocity < -rules.velocityThreshold) {
      _phase = _depthReached ? SquatPhase.inflection : SquatPhase.eccentric;
      _ascendingSince = null;
    }
    if (_phase != SquatPhase.concentric || angle < rules.readyAngleDegrees) {
      return null;
    }
    final duration = time - _cycleStart!;
    if (duration < rules.minimumCycleMicros) {
      diagnostics?.abort(SquatDiagnosticReason.tooShortCycle, time);
      _clearCycle();
      return null;
    }
    final deviations = <SquatDeviation>[
      if (_maxLeanDeviation > 0)
        SquatDeviation(SquatDeviationKind.trunkLean, _maxLeanDeviation),
      if (!_depthReached)
        SquatDeviation(SquatDeviationKind.incompleteDepth,
            math.max(0, _minimumAngle - rules.depthAngleDegrees)),
    ];
    // One normalized penalty per attempt. No repeated frame/duration penalties.
    final trunkPenalty = math.min(30.0, _maxLeanDeviation * 2);
    final depthPenalty = _depthReached
        ? 0.0
        : math.max(
            10.0, math.min(50.0, _minimumAngle - rules.depthAngleDegrees));
    final score = (100 - trunkPenalty - depthPenalty).clamp(0, 100).toDouble();
    if (_depthReached) {
      _reps++;
    } else {
      _partials++;
    }
    _scoreSum += score;
    diagnostics?.complete(
        full: _depthReached,
        time: time,
        number: _reps + _partials,
        minimumAngle: _minimumAngle,
        trunkPenalty: trunkPenalty,
        depthPenalty: depthPenalty,
        score: score,
        sessionScore: _scoreSum / (_reps + _partials));
    final result = SquatAttempt(
        number: _reps + _partials,
        complete: _depthReached,
        minimumKneeAngleDegrees: _minimumAngle,
        durationMicros: duration,
        scorePercent: score,
        deviations: deviations);
    cues.add(CueRequest(
        id: _depthReached ? 'squat_rep' : 'squat_depth',
        text: _depthReached
            ? 'Repetition $_reps.'
            : 'That was a partial repetition.',
        priority: _depthReached
            ? CuePriority.encouragement
            : CuePriority.correction));
    _clearCycle();
    return result;
  }

  void _account(int time, {required bool valid}) {
    final previous = _accountedUntil;
    if (previous != null && time > previous) {
      if (valid) {
        _tracked += time - previous;
      } else {
        _rejected += time - previous;
      }
    }
    _accountedUntil = math.max(time, previous ?? time);
  }

  void _clearCycle() {
    _phase = SquatPhase.ready;
    _cycleStart = _depthSince = _ascendingSince = _leanSince = null;
    _depthReached = _leanCueIssued = false;
    _minimumAngle = 180;
    _maxLeanDeviation = 0;
  }

  void _invalidateCalibration(
      {SquatDiagnosticReason diagnosticReason =
          SquatDiagnosticReason.recalibration,
      int? diagnosticTime}) {
    diagnostics?.abort(diagnosticReason, diagnosticTime ?? _lastCapture ?? 0);
    _needsCalibration = true;
    _side = null;
    _standingSince = null;
    _previousAngle = _lastRawAngle = _velocity = null;
    _previousAngleTime = null;
    _previousValid = false;
    _filter.reset();
    _clearCycle();
  }

  SquatUpdate _snapshot(int time,
          {List<CueRequest> cues = const [], SquatAttempt? completed}) =>
      SquatUpdate(
          capturedAtMicros: time,
          health: _health,
          needsCalibration: _needsCalibration,
          phase: _phase,
          selectedSide: _side,
          geometry: _geometry,
          angularVelocityDegreesPerSecond: _velocity,
          repetitions: _reps,
          partialRepetitions: _partials,
          trackedDurationMicros: _tracked,
          rejectedDurationMicros: _rejected,
          formScorePercent:
              _reps + _partials == 0 ? null : _scoreSum / (_reps + _partials),
          trackingConfidence: _confidence,
          completedAttempt: completed,
          cues: cues);
}
