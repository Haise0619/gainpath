import 'dart:math' as math;
import '../pose/audio_cue_arbiter.dart';
import '../pose/one_euro_filter.dart';
import '../pose/pose_frame.dart';
import '../pose/tracking_health.dart';
import 'row_geometry.dart';

enum RowPhase { ready, pulling, lowering }

class RowUpdate {
  const RowUpdate(
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
      required this.cues});
  final int repetitions,
      partialRepetitions,
      trackedDurationMicros,
      rejectedDurationMicros;
  final bool needsCalibration;
  final TrackingStatus health;
  final RowSide selectedSide;
  final RowPhase phase;
  final String calibrationCue;
  final double calibrationProgress;
  final double? formScorePercent;
  final List<CueRequest> cues;
}

/// Provisional projected row cycles, bound to an explicit anatomical arm.
/// Memory and work per frame are bounded. Timing uses capture timestamps;
/// missing/stale evidence is never filtered into an apparent movement.
class RowAnalyzer {
  RowAnalyzer({required RowSide side}) : _side = side;
  static const version = 'single-arm-row-side-v1';
  static const maximumFrameAgeMicros = 250000;
  final RowSide _side;
  RowGeometry? _base, _calibrationAnchor;
  (int, int)? _dimensions;
  int? _lastCapture,
      _lastNow,
      _calibrationStart,
      _startSince,
      _attemptStart,
      _peakSince,
      _returnSince;
  int _reps = 0,
      _partial = 0,
      _tracked = 0,
      _rejected = 0,
      _calibrationSamples = 0;
  double _progress = 0, _maximumTravel = 0, _minimumAngle = 180;
  bool _full = false;
  OneEuroFilter _angleFilter = OneEuroFilter(minCutoff: 4, beta: .02);
  OneEuroFilter _travelFilter = OneEuroFilter(minCutoff: 4, beta: 2);
  TrackingStatus _health = TrackingStatus.degraded;
  RowPhase _phase = RowPhase.ready;
  String _cue = 'Turn side-on · hinge forward and let the selected arm hang';
  List<CueRequest> _cues = const [];

  RowUpdate get snapshot => RowUpdate(
      repetitions: _reps,
      partialRepetitions: _partial,
      trackedDurationMicros: _tracked,
      rejectedDurationMicros: _rejected,
      needsCalibration: _base == null,
      health: _health,
      selectedSide: _side,
      phase: _phase,
      calibrationCue: _cue,
      calibrationProgress: _progress,
      formScorePercent: null,
      cues: List.unmodifiable(_cues));

  void _clearAttempt() {
    _startSince = _attemptStart = _peakSince = _returnSince = null;
    _maximumTravel = 0;
    _minimumAngle = 180;
    _full = false;
    _phase = RowPhase.ready;
  }

  void _invalidate() {
    _base = _calibrationAnchor = null;
    _calibrationStart = null;
    _calibrationSamples = 0;
    _progress = 0;
    _clearAttempt();
    _angleFilter = OneEuroFilter(minCutoff: 4, beta: .02);
    _travelFilter = OneEuroFilter(minCutoff: 4, beta: 2);
    _health = TrackingStatus.degraded;
    _cues = const [];
    _cue = 'Reset with a steady torso and your selected arm hanging';
  }

  void pause() {
    _invalidate();
    _lastCapture = _lastNow = null;
  }

  RowUpdate tick({required int nowMicros}) {
    if (_lastNow == null || nowMicros <= _lastNow!) return snapshot;
    final elapsed = nowMicros - _lastNow!;
    if (_lastCapture == null ||
        nowMicros - _lastCapture! > maximumFrameAgeMicros) {
      _rejected += elapsed;
      _invalidate();
      _health = TrackingStatus.lost;
      _cue = 'Camera tracking delayed · hold your starting position';
    } else if (_base != null) {
      _tracked += elapsed;
    } else {
      _rejected += elapsed;
    }
    _lastNow = nowMicros;
    return snapshot;
  }

  RowUpdate update(PoseFrame frame, {required int nowMicros}) {
    final t = frame.capturedAtMicros;
    final elapsed = _lastNow == null ? 0 : math.max(0, nowMicros - _lastNow!);
    if (t < 0 ||
        nowMicros < 0 ||
        t > nowMicros ||
        (_lastCapture != null && t <= _lastCapture!) ||
        (_lastNow != null && nowMicros < _lastNow!)) {
      _rejected += elapsed;
      _invalidate();
      if (_lastNow == null || nowMicros > _lastNow!) _lastNow = nowMicros;
      return snapshot;
    }
    final dimensions = (frame.imageWidth, frame.imageHeight);
    if ((_lastCapture != null && t - _lastCapture! > maximumFrameAgeMicros) ||
        (_dimensions != null && dimensions != _dimensions)) {
      _invalidate();
    }
    _lastCapture = t;
    _lastNow = nowMicros;
    _dimensions = dimensions;
    _cues = const [];
    final g = RowGeometry.fromFrame(frame, _side);
    if (nowMicros - t > maximumFrameAgeMicros ||
        g == null ||
        RowGeometry.confidence(frame, _side) < .65 ||
        !g.bentTorso) {
      _rejected += elapsed;
      _invalidate();
      if (nowMicros - t > maximumFrameAgeMicros) {
        _health = TrackingStatus.lost;
        _cue = 'Camera tracking delayed · hold your starting position';
      } else {
        _cue = 'Show selected shoulder, elbow, wrist and hip side-on';
      }
      return snapshot;
    }
    _health = TrackingStatus.healthy;
    if (_base == null) {
      _rejected += elapsed;
      if (!g.neutral) {
        _invalidate();
        _cue = 'Hinge forward · start with your selected arm hanging straight';
        return snapshot;
      }
      final anchor = _calibrationAnchor;
      if (anchor == null ||
          g.shoulderDistance(anchor) > .06 ||
          g.hipDistance(anchor) > .06 ||
          (g.elbowAngleDegrees - anchor.elbowAngleDegrees).abs() > 6 ||
          (g.upperArmProjection - anchor.upperArmProjection).abs() > .05 ||
          (g.torsoLength / anchor.torsoLength - 1).abs() > .07 ||
          (g.torsoInclinationDegrees - anchor.torsoInclinationDegrees).abs() >
              5 ||
          g.torsoDirection != anchor.torsoDirection) {
        _calibrationAnchor = g;
        _calibrationStart = t;
        _calibrationSamples = 0;
      }
      _calibrationSamples++;
      _progress = ((t - _calibrationStart!) / 650000).clamp(0.0, 1.0);
      _cue = 'Hold your torso steady · let the selected arm hang';
      if (_progress >= 1 && _calibrationSamples >= 5) {
        _base = _calibrationAnchor;
        _angleFilter.filter(g.elbowAngleDegrees, timestampSeconds: t / 1e6);
        _travelFilter.filter(0, timestampSeconds: t / 1e6);
      }
      return snapshot;
    }
    final base = _base!;
    if (g.shoulderDistance(base) > .16 ||
        g.hipDistance(base) > .16 ||
        (g.torsoLength / base.torsoLength - 1).abs() > .18 ||
        (g.upperArmLength / base.upperArmLength - 1).abs() > .20 ||
        (g.forearmLength / base.forearmLength - 1).abs() > .20 ||
        (g.torsoInclinationDegrees - base.torsoInclinationDegrees).abs() > 12 ||
        g.torsoDirection != base.torsoDirection) {
      _rejected += elapsed;
      _invalidate();
      _cue = 'Keep your torso still · reset your starting position';
      return snapshot;
    }
    _tracked += elapsed;
    final rawTravel = g.upperArmProjection - base.upperArmProjection;
    final travel = _travelFilter.filter(rawTravel, timestampSeconds: t / 1e6);
    final angle =
        _angleFilter.filter(g.elbowAngleDegrees, timestampSeconds: t / 1e6);
    _cue = 'Pull the elbow toward your hip · return to a hanging arm';
    // Both raw and filtered evidence must agree: a filter tail cannot create
    // peak/return dwell after a single spurious sample.
    if (_attemptStart == null) {
      if (angle <= 148 &&
          g.elbowAngleDegrees <= 148 &&
          travel >= .12 &&
          rawTravel >= .12) {
        _startSince ??= t;
        if (t - _startSince! >= 70000) {
          _attemptStart = _startSince;
          _phase = RowPhase.pulling;
        }
      } else {
        _startSince = null;
      }
    }
    if (_attemptStart != null) {
      _maximumTravel = math.max(_maximumTravel, travel);
      _minimumAngle = math.min(_minimumAngle, angle);
      if (angle <= 110 &&
          g.elbowAngleDegrees <= 110 &&
          travel >= .32 &&
          rawTravel >= .32) {
        _peakSince ??= t;
        if (t - _peakSince! >= 120000) _full = true;
      } else {
        _peakSince = null;
      }
      if (travel < _maximumTravel - .04) _phase = RowPhase.lowering;
      final duration = t - _attemptStart!;
      if (duration > 15000000) {
        _invalidate();
      } else if (angle >= 158 &&
          g.elbowAngleDegrees >= 160 &&
          travel <= .12 &&
          rawTravel <= .12 &&
          g.armVerticality >= .94) {
        _returnSince ??= t;
        if (t - _returnSince! >= 100000) {
          if (duration >= 600000 &&
              _minimumAngle <= 145 &&
              _maximumTravel >= .15) {
            if (_full) {
              _reps++;
            } else {
              _partial++;
            }
            _cues = [
              CueRequest(
                  id: _full ? 'row_rep' : 'row_partial',
                  text: _full ? '$_reps' : 'Partial movement recorded.',
                  priority: CuePriority.encouragement)
            ];
          }
          _clearAttempt();
        }
      } else {
        _returnSince = null;
      }
    }
    return snapshot;
  }
}
