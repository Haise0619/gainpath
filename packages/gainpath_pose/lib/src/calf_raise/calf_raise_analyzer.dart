import 'dart:math' as math;
import '../pose/audio_cue_arbiter.dart';
import '../pose/one_euro_filter.dart';
import '../pose/pose_frame.dart';
import '../pose/tracking_health.dart';
import 'calf_raise_geometry.dart';
import 'calf_calibration_window.dart';

enum CalfRaisePhase { ready, raising, lowering }

class CalfRaiseUpdate {
  const CalfRaiseUpdate(
      {required this.repetitions,
      required this.partialRepetitions,
      required this.trackedDurationMicros,
      required this.rejectedDurationMicros,
      required this.needsCalibration,
      required this.health,
      required this.selectedSide,
      required this.phase,
      required this.calibrationCue,
      required this.calibrationProgress,
      required this.formScorePercent,
      required this.cues,
      required this.requiresHeelReset,
      required this.decision});
  final int repetitions,
      partialRepetitions,
      trackedDurationMicros,
      rejectedDurationMicros;
  final bool needsCalibration, requiresHeelReset;
  final TrackingStatus health;
  final CalfSide? selectedSide;
  final CalfRaisePhase phase;
  final String calibrationCue, decision;
  final double calibrationProgress;
  final double? formScorePercent;
  final List<CueRequest> cues;
}

/// Provisional level-ground visible-leg cycles. Floor contact is confirmed by
/// setup, not inferred from perspective. No load/bilateral/balance assessment.
class CalfRaiseAnalyzer {
  static const version = 'standing-calf-raise-side-v1';
  static const implementationRevision = 'forefoot-corridor-noise-return-3';
  static const maximumFrameAgeMicros = 250000, lostAfterMicros = 500000;
  CalfSide? _side;
  CalfRaiseGeometry? _base;
  (int, int, String, String, bool)? _identity;
  int? _lastCapture,
      _lastNow,
      _attemptStart,
      _startSince,
      _peakSince,
      _returnSince,
      _unavailableSince,
      _rearmSince;
  final _calibration = CalfCalibrationWindow();
  int _reps = 0, _partial = 0, _tracked = 0, _rejected = 0, _frames = 0;
  double _score = 0, _peak = 0, _minimumKnee = 180, _previousLift = 0;
  double _heelNoise = 0, _ankleNoise = 0;
  String? _resetReason;
  double? _toeHorizontal,
      _toeVertical,
      _shinRatio,
      _thighRatio,
      _rawHeel,
      _rawAnkle,
      _filteredHeel,
      _filteredAnkle;

  /// Bounded local scalars, never images or landmark coordinates/history.
  Map<String, Object?> get decisionDiagnostics => {
        'resetReason': _resetReason,
        'toeHorizontalShins': _toeHorizontal,
        'toeVerticalShins': _toeVertical,
        'shinRatio': _shinRatio,
        'thighRatio': _thighRatio,
        'rawHeelLift': _rawHeel,
        'rawAnkleLift': _rawAnkle,
        'filteredHeelLift': _filteredHeel,
        'filteredAnkleLift': _filteredAnkle,
        'heelNoise': _heelNoise,
        'ankleNoise': _ankleNoise,
      };
  double get _heelStart => math.max(.03, _heelNoise * 1.5);
  double get _ankleStart => math.max(.02, _ankleNoise * 1.5);
  double get _heelReturnRaw =>
      math.max(.035, _heelNoise * 1.5).clamp(.035, .06);
  double get _ankleReturnRaw =>
      math.max(.035, _ankleNoise * 1.5).clamp(.035, .06);
  double get _heelReturnFiltered =>
      math.max(.02, _heelNoise * .85).clamp(.02, .035);
  double get _ankleReturnFiltered =>
      math.max(.025, _ankleNoise * .85).clamp(.025, .035);
  bool _calibrated = false, _full = false, _requiresHeelReset = false;
  TrackingStatus _health = TrackingStatus.degraded;
  CalfRaisePhase _phase = CalfRaisePhase.ready;
  List<CueRequest> _cues = const [];
  String _cue = 'Stand side-on · lower both heels and hold still',
      _decision = 'starting';
  OneEuroFilter _heelFilter = OneEuroFilter(minCutoff: 4, beta: 2),
      _ankleFilter = OneEuroFilter(minCutoff: 4, beta: 2);
  CalfRaiseUpdate get snapshot => CalfRaiseUpdate(
      repetitions: _reps,
      partialRepetitions: _partial,
      trackedDurationMicros: _tracked,
      rejectedDurationMicros: _rejected,
      needsCalibration: !_calibrated,
      health: _health,
      selectedSide: _side,
      phase: _phase,
      calibrationCue: _cue,
      calibrationProgress: _calibrated ? 1 : _calibration.progress,
      formScorePercent:
          _reps + _partial == 0 ? null : _score / (_reps + _partial),
      cues: List.unmodifiable(_cues),
      requiresHeelReset: _requiresHeelReset,
      decision: _decision);
  void _resetFilters() {
    _heelFilter = OneEuroFilter(minCutoff: 4, beta: 2);
    _ankleFilter = OneEuroFilter(minCutoff: 4, beta: 2);
  }

  void _clearAttempt() {
    _attemptStart = _startSince = _peakSince = _returnSince = null;
    _full = false;
    _frames = 0;
    _peak = 0;
    _minimumKnee = 180;
    _previousLift = 0;
    _phase = CalfRaisePhase.ready;
  }

  void _invalidate({String? reason}) {
    _calibrated = false;
    _base = null;
    _calibration.reset();
    _clearAttempt();
    _resetFilters();
    _requiresHeelReset = false;
    _rearmSince = null;
    _health = TrackingStatus.degraded;
    _cues = const [];
    _cue = 'Tracking interrupted · lower heels and hold still';
    _resetReason = reason;
    _rawHeel = _rawAnkle = _filteredHeel = _filteredAnkle = null;
  }

  void pause() {
    _invalidate();
    _lastCapture = _lastNow = _unavailableSince = null;
    _decision = 'paused';
  }

  CalfRaiseUpdate tick({required int nowMicros}) {
    if (_lastNow == null || nowMicros <= _lastNow!) return snapshot;
    final elapsed = nowMicros - _lastNow!;
    if (_lastCapture == null ||
        nowMicros - _lastCapture! > maximumFrameAgeMicros) {
      _rejected += elapsed;
      _invalidate();
      _health = TrackingStatus.lost;
      _decision = 'watchdog_stale';
      _cue = 'Camera tracking delayed · hold still while it catches up';
    } else if (_calibrated && _health == TrackingStatus.healthy) {
      _tracked += elapsed;
    } else {
      _rejected += elapsed;
    }
    _lastNow = nowMicros;
    return snapshot;
  }

  void _chooseInitialSide(PoseFrame frame) {
    if (_side != null &&
        (_calibrated ||
            _reps + _partial > 0 ||
            !_calibration.isEmpty ||
            CalfRaiseGeometry.confidence(frame, _side!) >= .7)) {
      return;
    }
    final sides = CalfSide.values.toList()
      ..sort((a, b) => CalfRaiseGeometry.confidence(frame, b)
          .compareTo(CalfRaiseGeometry.confidence(frame, a)));
    for (final side in sides) {
      final g = CalfRaiseGeometry.fromFrame(frame, side);
      if (CalfRaiseGeometry.confidence(frame, side) >= .7 &&
          g != null &&
          g.kneeAngleDegrees >= 165) {
        if (_side != side) {
          _base = null;
          _calibration.reset();
        }
        _side = side;
        return;
      }
    }
  }

  CalfRaiseUpdate update(PoseFrame frame, {required int nowMicros}) {
    final t = frame.capturedAtMicros,
        elapsed = _lastNow == null ? 0 : math.max(0, nowMicros - _lastNow!);
    final previousAssessable = _calibrated && _health == TrackingStatus.healthy;
    if (t < 0 ||
        t > nowMicros ||
        (_lastCapture != null && t <= _lastCapture!) ||
        (_lastNow != null && nowMicros < _lastNow!)) {
      _rejected += elapsed;
      _invalidate();
      _decision = 'invalid_timestamp';
      if (_lastNow == null || nowMicros > _lastNow!) _lastNow = nowMicros;
      return snapshot;
    }
    final identity = (
      frame.imageWidth,
      frame.imageHeight,
      frame.detectorId,
      frame.modelVersion,
      frame.isMirrored
    );
    if ((_lastCapture != null && t - _lastCapture! > maximumFrameAgeMicros) ||
        (_identity != null && identity != _identity)) {
      _invalidate();
      _unavailableSince = null;
      _decision = 'geometry_or_frame_gap';
    }
    _identity = identity;
    _lastCapture = t;
    _lastNow = nowMicros;
    _cues = const [];
    if (nowMicros - t > maximumFrameAgeMicros) {
      _rejected += elapsed;
      _invalidate();
      _health = TrackingStatus.lost;
      _decision = 'stale_frame';
      _cue = 'Camera tracking delayed · hold still while it catches up';
      return snapshot;
    }
    _chooseInitialSide(frame);
    final g = _side == null ? null : CalfRaiseGeometry.fromFrame(frame, _side!);
    if (g == null ||
        CalfRaiseGeometry.confidence(frame, _side!) < .7 ||
        g.kneeAngleDegrees < 150) {
      _rejected += elapsed;
      _unavailableSince ??= t;
      if (g != null && g.kneeAngleDegrees < 150) {
        _invalidate();
        _decision = 'knee_bend';
      } else if (!_calibrated) {
        if (!_calibration.keepAcrossBadSample(t)) _invalidate();
        _decision = 'calibration_tracking_uncertain';
      } else {
        _clearAttempt();
        _resetFilters();
        _rearmSince = null;
        if (t - _unavailableSince! >= lostAfterMicros) {
          _invalidate();
          _decision = 'tracking_lost';
        } else {
          _requiresHeelReset = true;
          _decision = 'brief_tracking_loss';
        }
      }
      _health = t - _unavailableSince! >= lostAfterMicros
          ? TrackingStatus.lost
          : TrackingStatus.degraded;
      _cue = CalfRaiseGeometry.setupCue(frame, _side);
      return snapshot;
    }
    if (_unavailableSince != null &&
        t - _unavailableSince! >= lostAfterMicros) {
      _invalidate();
    }
    _unavailableSince = null;
    if (!_calibrated) {
      _rejected += elapsed;
      _health = TrackingStatus.healthy;
      if (g.kneeAngleDegrees < 165) {
        _calibration.keepAcrossBadSample(t);
        _cue = CalfRaiseGeometry.setupCue(frame, _side);
        _decision = 'starting_position';
        return snapshot;
      }
      final baseline = _calibration.add(t, g);
      _decision = 'calibrating';
      _cue = _resetReason == null
          ? 'Hold still with heels down'
          : '$_resetReason · hold still with heels down';
      if (baseline != null) {
        _base = baseline;
        _heelNoise = _calibration.heelNoise;
        _ankleNoise = _calibration.ankleNoise;
        _calibrated = true;
        _resetFilters();
        _heelFilter.filter(0, timestampSeconds: t / 1e6);
        _ankleFilter.filter(0, timestampSeconds: t / 1e6);
        _decision = 'ready';
        _resetReason = null;
        _cue = 'Ready · raise and lower your heels with control';
      }
      return snapshot;
    }
    final base = _base!;
    _toeHorizontal = (g.toeX - base.toeX).abs() / base.shinLength;
    _toeVertical = (g.toeY - base.toeY).abs() / base.shinLength;
    _shinRatio = g.shinLength / base.shinLength;
    _thighRatio = g.thighLength / base.thighLength;
    // Foot-index is an estimated point on an articulating forefoot, not a fixed
    // floor-contact marker. Bound its axes separately. The thigh supplies the
    // stable scale reference while the ankle/shin projection changes in a raise.
    final footMoved = _toeHorizontal! > .16 || _toeVertical! > .12;
    final viewChanged = (_thighRatio! - 1).abs() > .15 ||
        _shinRatio! < .70 ||
        _shinRatio! > 1.30;
    if (footMoved || viewChanged) {
      _rejected += elapsed;
      _invalidate(
          reason: viewChanged ? 'Leg view changed' : 'Foot position changed');
      _decision = viewChanged ? 'leg_view_changed' : 'forefoot_moved';
      _cue = '$_resetReason · keep the phone still and reset with heels down';
      return snapshot;
    }
    _health = TrackingStatus.healthy;
    if (previousAssessable) {
      _tracked += elapsed;
    } else {
      _rejected += elapsed;
    }
    final raw = (g.heelHeight - base.heelHeight) / base.shinLength,
        rawAnkle = (base.ankleY - g.ankleY) / base.shinLength;
    final lift = _heelFilter.filter(raw, timestampSeconds: t / 1e6),
        ankle = _ankleFilter.filter(rawAnkle, timestampSeconds: t / 1e6);
    _rawHeel = raw;
    _rawAnkle = rawAnkle;
    _filteredHeel = lift;
    _filteredAnkle = ankle;
    if (_requiresHeelReset) {
      _cue = 'Lower both heels and hold briefly to restart';
      _decision = 'awaiting_heel_reset';
      if (raw.abs() <= math.max(.04, _heelReturnRaw) &&
          rawAnkle.abs() <= math.max(.04, _ankleReturnRaw) &&
          lift.abs() <= math.max(.025, _heelReturnFiltered) &&
          ankle.abs() <= _ankleReturnFiltered) {
        _rearmSince ??= t;
        if (t - _rearmSince! >= 100000) {
          _requiresHeelReset = false;
          _rearmSince = null;
          _decision = 'ready';
        }
      } else {
        _rearmSince = null;
      }
      return snapshot;
    }
    _cue = 'Ready · raise and lower your heels with control';
    _decision = 'ready';
    final cues = <CueRequest>[];
    if (g.kneeAngleDegrees < 165) {
      cues.add(const CueRequest(
          id: 'calf_knee',
          text: 'Keep your knees steady without bending.',
          priority: CuePriority.correction));
    }
    if (_attemptStart == null) {
      if (raw >= _heelStart &&
          lift >= _heelStart &&
          rawAnkle >= _ankleStart &&
          ankle >= _ankleStart) {
        _startSince ??= t;
        if (t - _startSince! >= 70000) {
          _attemptStart = _startSince;
          _phase = CalfRaisePhase.raising;
          _frames = 0;
          _peak = 0;
          _minimumKnee = 180;
          _full = false;
        }
      } else {
        _startSince = null;
      }
    }
    if (_attemptStart != null) {
      _frames++;
      _peak = math.max(_peak, lift);
      _minimumKnee = math.min(_minimumKnee, g.kneeAngleDegrees);
      _decision = _phase.name;
      final fullLift = math.max(.08, 3 / (base.shinLength * base.imageHeight));
      if (raw >= fullLift &&
          lift >= fullLift &&
          rawAnkle >= .04 &&
          ankle >= .04) {
        _peakSince ??= t;
        if (t - _peakSince! >= 150000) {
          _full = true;
          _decision = 'peak_observed';
        }
      } else {
        _peakSince = null;
      }
      if (lift < _previousLift - .005) {
        _phase = CalfRaisePhase.lowering;
        _decision = 'lowering';
      }
      final duration = t - _attemptStart!;
      if (duration > 10000000) {
        _invalidate();
        _decision = 'cycle_timeout';
      } else if (raw.abs() <= _heelReturnRaw &&
          rawAnkle.abs() <= _ankleReturnRaw &&
          lift.abs() <= _heelReturnFiltered &&
          ankle.abs() <= _ankleReturnFiltered) {
        _returnSince ??= t;
        if (t - _returnSince! >= 100000) {
          if (duration >= 700000 &&
              _frames >= 5 &&
              _peak >= math.max(.035, _heelNoise * 2) &&
              _reps + _partial < 10000) {
            if (_full) {
              _reps++;
              _decision = 'rep_completed';
            } else {
              _partial++;
              _decision = 'partial_completed';
            }
            _score += (100 - (_full ? 0 : 30) - (_minimumKnee < 165 ? 20 : 0))
                .clamp(0, 100);
            cues.add(CueRequest(
                id: _full ? 'calf_rep' : 'calf_partial',
                text: _full ? _reps.toString() : 'Partial movement recorded.',
                priority: CuePriority.encouragement));
          }
          _clearAttempt();
        }
      } else {
        _returnSince = null;
      }
    }
    _previousLift = lift;
    _cues = cues;
    return snapshot;
  }
}
