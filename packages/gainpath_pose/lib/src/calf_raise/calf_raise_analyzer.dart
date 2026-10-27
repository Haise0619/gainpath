import 'dart:math' as math;
import '../pose/audio_cue_arbiter.dart';
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
      required this.cues});
  final int repetitions,
      partialRepetitions,
      trackedDurationMicros,
      rejectedDurationMicros;
  final bool needsCalibration;
  final TrackingStatus health;
  final CalfSide? selectedSide;
  final CalfRaisePhase phase;
  final String calibrationCue;
  final double calibrationProgress;
  final double? formScorePercent;
  final List<CueRequest> cues;
}

/// Provisional rules for a level-ground standing calf raise, isolated from squat/curl.
/// Counts the visible leg's heel cycle; cannot verify both legs or prescribe load.
class CalfRaiseAnalyzer {
  static const version = 'standing-calf-raise-side-v1';
  static const maximumFrameAgeMicros = 250000;
  CalfSide? _side;
  CalfRaiseGeometry? _base;
  (int, int)? _dimensions;
  int? _lastCapture, _lastNow, _attemptStart, _peakSince;
  final _calibration = CalfCalibrationWindow();
  int _reps = 0, _partial = 0, _tracked = 0, _rejected = 0, _frames = 0;
  double _score = 0, _peak = 0, _minimumKnee = 180, _previousLift = 0;
  bool _calibrated = false, _full = false;
  TrackingStatus _health = TrackingStatus.degraded;
  CalfRaisePhase _phase = CalfRaisePhase.ready;
  List<CueRequest> _cues = const [];
  String _calibrationCue = 'Stand side-on · lower both heels and hold still';
  CalfRaiseUpdate get snapshot => CalfRaiseUpdate(
      repetitions: _reps,
      partialRepetitions: _partial,
      trackedDurationMicros: _tracked,
      rejectedDurationMicros: _rejected,
      needsCalibration: !_calibrated,
      health: _health,
      selectedSide: _side,
      phase: _phase,
      calibrationCue: _calibrated
          ? 'Ready · raise and lower your heels with control'
          : _calibrationCue,
      calibrationProgress: _calibrated ? 1 : _calibration.progress,
      formScorePercent:
          _reps + _partial == 0 ? null : _score / (_reps + _partial),
      cues: List.unmodifiable(_cues));
  void _invalidate() {
    _calibrated = false;
    _base = null;
    _calibration.reset();
    _attemptStart = null;
    _peakSince = null;
    _full = false;
    _frames = 0;
    _phase = CalfRaisePhase.ready;
    _health = TrackingStatus.degraded;
    _cues = const [];
    _calibrationCue = 'Tracking interrupted · lower heels and hold still';
  }

  void pause() {
    _invalidate();
    _lastCapture = null;
    _lastNow = null;
  }

  CalfRaiseUpdate tick({required int nowMicros}) {
    if (_lastNow == null || nowMicros <= _lastNow!) return snapshot;
    if (_lastCapture == null ||
        nowMicros - _lastCapture! > maximumFrameAgeMicros) {
      _rejected += nowMicros - _lastNow!;
      _invalidate();
      _health = TrackingStatus.lost;
      _calibrationCue =
          'Camera tracking delayed · hold still while it catches up';
    } else if (_calibrated) {
      _tracked += nowMicros - _lastNow!;
    } else {
      _rejected += nowMicros - _lastNow!;
    }
    _lastNow = nowMicros;
    return snapshot;
  }

  // Image-space foot slope cannot establish floor contact under perspective.
  // The member starts heels-down as instructed; motion is relative to this
  // stable neutral baseline, with all rise/return and toe-anchor guards intact.
  bool _neutralStanding(CalfRaiseGeometry g) => g.kneeAngleDegrees >= 165;
  double _toeDistance(CalfRaiseGeometry a, CalfRaiseGeometry b) =>
      math.sqrt(math.pow(a.toeX - b.toeX, 2) + math.pow(a.toeY - b.toeY, 2)) /
      b.shinLength;
  CalfRaiseUpdate update(PoseFrame frame, {required int nowMicros}) {
    final t = frame.capturedAtMicros;
    if (t < 0 ||
        t > nowMicros ||
        (_lastCapture != null && t <= _lastCapture!) ||
        (_lastNow != null && nowMicros < _lastNow!)) {
      return snapshot;
    }
    final elapsed = _lastNow == null ? 0 : nowMicros - _lastNow!;
    final dimensions = (frame.imageWidth, frame.imageHeight);
    if ((_lastCapture != null && t - _lastCapture! > maximumFrameAgeMicros) ||
        (_dimensions != null && dimensions != _dimensions)) {
      _invalidate();
    }
    _dimensions = dimensions;
    _lastCapture = t;
    _lastNow = nowMicros;
    _cues = const [];
    if (_side == null ||
        (!_calibrated &&
            _reps + _partial == 0 &&
            _calibration.isEmpty &&
            CalfRaiseGeometry.confidence(frame, _side!) < .7)) {
      final sides = CalfSide.values.toList()
        ..sort((a, b) => CalfRaiseGeometry.confidence(frame, b)
            .compareTo(CalfRaiseGeometry.confidence(frame, a)));
      for (final side in sides) {
        final g = CalfRaiseGeometry.fromFrame(frame, side);
        if (CalfRaiseGeometry.confidence(frame, side) >= .7 &&
            g != null &&
            _neutralStanding(g)) {
          if (_side != side) {
            _base = null;
            _calibration.reset();
          }
          _side = side;
          break;
        }
      }
    }
    final g = _side == null ? null : CalfRaiseGeometry.fromFrame(frame, _side!);
    if (nowMicros - t > maximumFrameAgeMicros ||
        g == null ||
        CalfRaiseGeometry.confidence(frame, _side!) < .7 ||
        g.kneeAngleDegrees < 150) {
      _rejected += elapsed;
      final briefCalibrationLoss = !_calibrated &&
          nowMicros - t <= maximumFrameAgeMicros &&
          (g == null || g.kneeAngleDegrees >= 150) &&
          _calibration.keepAcrossBadSample(t);
      if (!briefCalibrationLoss) {
        _invalidate();
      } else {
        _health = TrackingStatus.degraded;
        _cues = const [];
      }
      _calibrationCue = nowMicros - t > maximumFrameAgeMicros
          ? 'Camera tracking delayed · hold still while it catches up'
          : CalfRaiseGeometry.setupCue(frame, _side);
      return snapshot;
    }
    _health = TrackingStatus.healthy;
    if (!_calibrated) {
      _rejected += elapsed;
      if (!_neutralStanding(g)) {
        _calibration.keepAcrossBadSample(t);
        _calibrationCue = CalfRaiseGeometry.setupCue(frame, _side);
        return snapshot;
      }
      final baseline = _calibration.add(t, g);
      if (baseline != null) {
        _base = baseline;
        _calibrated = true;
        _previousLift = 0;
      }
      _calibrationCue = 'Hold still with heels down';
      return snapshot;
    }
    final base = _base!;
    if (_toeDistance(g, base) > .06 ||
        (g.shinLength / base.shinLength - 1).abs() > .15) {
      _rejected += elapsed;
      _invalidate();
      _calibrationCue =
          'Keep toes in place and the phone stationary · reset with heels down';
      return snapshot;
    }
    _tracked += elapsed;
    final lift = (g.heelHeight - base.heelHeight) / base.shinLength;
    final ankleLift = (base.ankleY - g.ankleY) / base.shinLength;
    final cues = <CueRequest>[];
    if (g.kneeAngleDegrees < 165) {
      cues.add(const CueRequest(
          id: 'calf_knee',
          text: 'Keep your knees steady without bending.',
          priority: CuePriority.correction));
    }
    if (_attemptStart == null && lift >= .03 && ankleLift >= .02) {
      _attemptStart = t;
      _frames = 0;
      _peak = 0;
      _minimumKnee = 180;
      _full = false;
      _peakSince = null;
      _phase = CalfRaisePhase.raising;
    }
    if (_attemptStart != null) {
      _frames++;
      _peak = math.max(_peak, lift);
      _minimumKnee = math.min(_minimumKnee, g.kneeAngleDegrees);
      if (lift >= .08 && ankleLift >= .04) {
        _peakSince ??= t;
        if (t - _peakSince! >= 150000) _full = true;
      } else {
        _peakSince = null;
      }
      if (lift < _previousLift - .01) _phase = CalfRaisePhase.lowering;
      final duration = t - _attemptStart!;
      if (duration > 10000000) {
        _invalidate();
      } else if (lift <= .015 && ankleLift <= .025) {
        if (duration >= 700000 && _frames >= 5 && _peak >= .035) {
          if (_full) {
            _reps++;
          } else {
            _partial++;
          }
          _score += (100 - (_full ? 0 : 30) - (_minimumKnee < 165 ? 20 : 0))
              .clamp(0, 100);
          cues.add(CueRequest(
              id: _full ? 'calf_rep' : 'calf_partial',
              text: _full ? '$_reps' : 'Partial movement recorded.',
              priority: CuePriority.encouragement));
        }
        _attemptStart = null;
        _phase = CalfRaisePhase.ready;
      }
    }
    _previousLift = lift;
    _cues = cues;
    return snapshot;
  }
}
