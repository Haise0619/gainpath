import 'dart:math' as math;
import '../pose/audio_cue_arbiter.dart';
import '../pose/pose_frame.dart';
import '../pose/tracking_health.dart';
import 'curl_geometry.dart';

enum CurlPhase { ready, curling, lowering }

class CurlUpdate {
  const CurlUpdate(
      {required this.repetitions,
      required this.partialRepetitions,
      required this.trackedDurationMicros,
      required this.rejectedDurationMicros,
      required this.needsCalibration,
      required this.health,
      required this.selectedSide,
      required this.phase,
      required this.formScorePercent,
      required this.trackingConfidence,
      required this.geometry,
      required this.cues});
  final int repetitions,
      partialRepetitions,
      trackedDurationMicros,
      rejectedDurationMicros;
  final bool needsCalibration;
  final TrackingStatus health;
  final CurlSide? selectedSide;
  final CurlPhase phase;
  final double? formScorePercent;
  final double trackingConfidence;
  final CurlGeometry? geometry;
  final List<CueRequest> cues;
}

/// Provisional single-arm projected rules, independent of the frozen squat FSM.
/// Thresholds require physical acceptance; no load, grip or injury assessment.
class CurlAnalyzer {
  CurlAnalyzer({CurlSide? side}) : _side = side;
  static const version = 'single-arm-curl-side-v1';
  static const maximumFrameAgeMicros = 250000;
  CurlSide? _side;
  int? _lastCapture, _lastNow, _calibratingSince, _attemptSince;
  (int, int)? _dimensions;
  int _reps = 0, _partial = 0, _tracked = 0, _rejected = 0, _attemptFrames = 0;
  double _scoreTotal = 0,
      _minimum = 180,
      _upperBaseline = 0,
      _trunkBaseline = 0;
  double _maximumUpperDrift = 0, _maximumTrunkDrift = 0, _previousAngle = 180;
  bool _calibrated = false, _flexionConfirmed = false;
  int? _flexionSince;
  CurlGeometry? _geometry;
  double _confidence = 0;
  TrackingStatus _health = TrackingStatus.degraded;
  CurlPhase _phase = CurlPhase.ready;
  List<CueRequest> _cues = const [];

  void pause() {
    _calibrated = false;
    _calibratingSince = null;
    _attemptSince = null;
    _lastCapture = null;
    _lastNow = null;
    _geometry = null;
    _cues = const [];
    _health = TrackingStatus.degraded;
    _phase = CurlPhase.ready;
  }

  CurlUpdate get snapshot => CurlUpdate(
      repetitions: _reps,
      partialRepetitions: _partial,
      trackedDurationMicros: _tracked,
      rejectedDurationMicros: _rejected,
      needsCalibration: !_calibrated,
      health: _health,
      selectedSide: _side,
      phase: _phase,
      formScorePercent:
          _reps + _partial == 0 ? null : _scoreTotal / (_reps + _partial),
      trackingConfidence: _confidence,
      geometry: _geometry,
      cues: List.unmodifiable(_cues));

  void _invalidate() {
    _calibrated = false;
    _calibratingSince = null;
    _attemptSince = null;
    _phase = CurlPhase.ready;
    _health = TrackingStatus.degraded;
    _cues = const [];
  }

  CurlUpdate tick({required int nowMicros}) {
    if (_lastNow == null || nowMicros <= _lastNow!) return snapshot;
    if (_lastCapture == null ||
        nowMicros - _lastCapture! > maximumFrameAgeMicros) {
      _rejected += nowMicros - _lastNow!;
      _invalidate();
      _health = TrackingStatus.lost;
    } else if (_calibrated) {
      _tracked += nowMicros - _lastNow!;
    } else {
      _rejected += nowMicros - _lastNow!;
    }
    _lastNow = nowMicros;
    return snapshot;
  }

  CurlUpdate update(PoseFrame frame, {required int nowMicros}) {
    final capture = frame.capturedAtMicros;
    if (capture < 0 ||
        capture > nowMicros ||
        (_lastCapture != null && capture <= _lastCapture!) ||
        (_lastNow != null && nowMicros < _lastNow!)) {
      return snapshot;
    }
    final elapsed = _lastNow == null ? 0 : nowMicros - _lastNow!;
    final gap =
        _lastCapture != null && capture - _lastCapture! > maximumFrameAgeMicros;
    final dimensions = (frame.imageWidth, frame.imageHeight);
    if (gap || (_dimensions != null && _dimensions != dimensions)) {
      _invalidate();
    }
    _dimensions = dimensions;
    _lastNow = nowMicros;
    _lastCapture = capture;
    _cues = const [];
    // Lock one anatomical arm for the entire session, including pause/loss.
    if (_side == null) {
      final left = CurlGeometry.confidence(frame, CurlSide.left);
      final right = CurlGeometry.confidence(frame, CurlSide.right);
      final candidate = left >= right ? CurlSide.left : CurlSide.right;
      if (math.max(left, right) >= .65 &&
          CurlGeometry.fromFrame(frame, candidate) != null) {
        _side = candidate;
      }
    }
    _confidence = _side == null ? 0 : CurlGeometry.confidence(frame, _side!);
    _geometry = _side == null ? null : CurlGeometry.fromFrame(frame, _side!);
    final g = _geometry;
    if (nowMicros - capture > maximumFrameAgeMicros ||
        _confidence < .65 ||
        g == null) {
      _rejected += elapsed;
      _invalidate();
      return snapshot;
    }
    _health = TrackingStatus.healthy;
    if (!_calibrated) {
      _rejected += elapsed;
      if (g.elbowAngleDegrees >= 150 &&
          g.upperArmDegrees.abs() <= 30 &&
          g.trunkDegrees.abs() <= 15) {
        _calibratingSince ??= capture;
        if (capture - _calibratingSince! >= 800000) {
          _calibrated = true;
          _upperBaseline = g.upperArmDegrees;
          _trunkBaseline = g.trunkDegrees;
          _previousAngle = g.elbowAngleDegrees;
        }
      } else {
        _calibratingSince = null;
      }
      return snapshot;
    }
    _tracked += elapsed;
    final upper = (g.upperArmDegrees - _upperBaseline).abs();
    final trunk = (g.trunkDegrees - _trunkBaseline).abs();
    final cues = <CueRequest>[];
    if (upper > 15) {
      cues.add(const CueRequest(
          id: 'curl_upper_arm',
          text: 'Keep your upper arm steady.',
          priority: CuePriority.correction));
    }
    if (trunk > 15) {
      cues.add(const CueRequest(
          id: 'curl_trunk',
          text: 'Keep your body steady. Avoid leaning.',
          priority: CuePriority.correction));
    }
    if (_attemptSince == null && g.elbowAngleDegrees <= 135) {
      _attemptSince = capture;
      _flexionSince = null;
      _flexionConfirmed = false;
      _minimum = g.elbowAngleDegrees;
      _attemptFrames = 0;
      _maximumUpperDrift = 0;
      _maximumTrunkDrift = 0;
      _phase = CurlPhase.curling;
    }
    if (_attemptSince != null) {
      if (g.elbowAngleDegrees <= 60) {
        _flexionSince ??= capture;
        if (capture - _flexionSince! >= 100000) _flexionConfirmed = true;
      } else {
        _flexionSince = null;
      }
      _attemptFrames++;
      _minimum = math.min(_minimum, g.elbowAngleDegrees);
      _maximumUpperDrift = math.max(_maximumUpperDrift, upper);
      _maximumTrunkDrift = math.max(_maximumTrunkDrift, trunk);
      if (g.elbowAngleDegrees > _previousAngle + 3) _phase = CurlPhase.lowering;
      final duration = capture - _attemptSince!;
      if (duration > 15000000) {
        _invalidate();
      } else if (g.elbowAngleDegrees >= 150) {
        if (duration >= 600000 && _attemptFrames >= 4 && _minimum <= 120) {
          final full = _flexionConfirmed;
          if (full) {
            _reps++;
          } else {
            _partial++;
          }
          _scoreTotal += (100 -
                  (full ? 0 : 30) -
                  (_maximumUpperDrift > 15 ? 20 : 0) -
                  (_maximumTrunkDrift > 15 ? 20 : 0))
              .clamp(0, 100);
          cues.add(CueRequest(
              id: full ? 'curl_rep' : 'curl_partial',
              text: full ? '$_reps' : 'Partial movement recorded.',
              priority: CuePriority.encouragement));
        }
        _attemptSince = null;
        _phase = CurlPhase.ready;
      }
    }
    _previousAngle = g.elbowAngleDegrees;
    _cues = cues;
    return snapshot;
  }
}
