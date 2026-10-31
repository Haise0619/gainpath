import 'dart:math' as math;
import '../pose/audio_cue_arbiter.dart';
import '../pose/pose_frame.dart';
import '../pose/tracking_health.dart';
import 'reverse_lunge_geometry.dart';
import 'reverse_lunge_calibration_window.dart';

enum ReverseLungePhase { ready, descending, returning }

class ReverseLungeUpdate {
  const ReverseLungeUpdate(
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
      this.rejectionReason,
      this.diagnostics = const {},
      required this.cues});
  final int repetitions,
      partialRepetitions,
      trackedDurationMicros,
      rejectedDurationMicros;
  final bool needsCalibration;
  final TrackingStatus health;
  final LungeSide selectedSide;
  final ReverseLungePhase phase;
  final String calibrationCue;
  final double calibrationProgress;
  final String? rejectionReason;
  final Map<String, num> diagnostics;
  double? get formScorePercent => null;
  final List<CueRequest> cues;
}

/// Provisional front-leg cycles: neutral, observed backward step, sustained
/// descent and knee bend, then a held return to the neutral stance. Targets stay outside.
class ReverseLungeAnalyzer {
  ReverseLungeAnalyzer({required LungeSide side}) : _side = side;
  static const version = 'reverse-lunge-side-v1';
  static const implementationRevision = 'reverse-lunge-side-v1-r4';
  static const maximumFrameAgeMicros = 250000;
  final LungeSide _side;
  ReverseLungeGeometry? _base;
  final _calibration = ReverseLungeCalibrationWindow();
  (int, int)? _dimensions;
  (String, String)? _model;
  int? _lastCapture,
      _lastNow,
      _stepSince,
      _earlyStepSince,
      _attemptStart,
      _bottomSince,
      _partialSince,
      _returnSince;
  int _reps = 0, _partial = 0, _tracked = 0, _rejected = 0;
  bool _previousAccepted = false, _full = false, _hasPartial = false;
  double _progress = 0, _maximumDrop = 0, _earlyBack = 0;
  String? _reason;
  Map<String, num> _diagnostics = const {};
  TrackingStatus _health = TrackingStatus.degraded;
  ReverseLungePhase _phase = ReverseLungePhase.ready;
  String _cue =
      'Stand side-on with feet comfortably apart · show the selected front knee and both ankles';
  List<CueRequest> _cues = const [];
  ReverseLungeUpdate get snapshot => ReverseLungeUpdate(
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
      rejectionReason: _reason,
      diagnostics: Map.unmodifiable(_diagnostics),
      cues: List.unmodifiable(_cues));

  void _clearAttempt() {
    _stepSince =
        _attemptStart = _bottomSince = _partialSince = _returnSince = null;
    _earlyStepSince = null;
    _earlyBack = 0;
    _full = _hasPartial = false;
    _maximumDrop = 0;
    _phase = ReverseLungePhase.ready;
  }

  void _invalidate(String cue) {
    _base = null;
    _calibration.reset();
    _progress = 0;
    _previousAccepted = false;
    _clearAttempt();
    _health = TrackingStatus.degraded;
    _cues = const [];
    _cue = cue;
  }

  void pause() {
    _invalidate(
        'Stand with feet comfortably apart to restart the selected leg');
    _lastCapture = _lastNow = null;
  }

  ReverseLungeUpdate tick({required int nowMicros}) {
    if (_lastNow == null || nowMicros <= _lastNow!) return snapshot;
    final elapsed = nowMicros - _lastNow!;
    final fresh = _lastCapture == null
        ? 0
        : math.max(
            0,
            math.min(nowMicros, _lastCapture! + maximumFrameAgeMicros) -
                _lastNow!);
    final credit = _previousAccepted && _base != null ? fresh : 0;
    _tracked += credit;
    _rejected += elapsed - credit;
    _lastNow = nowMicros;
    if (_lastCapture == null ||
        nowMicros - _lastCapture! > maximumFrameAgeMicros) {
      _invalidate('Camera tracking delayed · return to your starting stance');
      _health = TrackingStatus.lost;
    }
    return snapshot;
  }

  ReverseLungeUpdate update(PoseFrame frame, {required int nowMicros}) {
    final t = frame.capturedAtMicros;
    final elapsed = _lastNow == null ? 0 : math.max(0, nowMicros - _lastNow!);
    final priorCapture = _lastCapture, priorNow = _lastNow;
    final priorAccepted = _previousAccepted;
    _cues = const [];
    if (t < 0 ||
        nowMicros < 0 ||
        t > nowMicros ||
        (_lastCapture != null && t <= _lastCapture!) ||
        (_lastNow != null && nowMicros < _lastNow!)) {
      _rejected += elapsed;
      _invalidate(
          'Fresh camera frames needed · return to your starting stance');
      if (_lastNow == null || nowMicros > _lastNow!) _lastNow = nowMicros;
      return snapshot;
    }
    final dimensions = (frame.imageWidth, frame.imageHeight);
    final model = (frame.detectorId, frame.modelVersion);
    final discontinuity =
        (priorCapture != null && t - priorCapture > maximumFrameAgeMicros) ||
            (_dimensions != null && dimensions != _dimensions) ||
            (_model != null && model != _model);
    if (discontinuity) {
      _invalidate('Camera changed · return to your starting stance');
    }
    _lastCapture = t;
    _lastNow = nowMicros;
    _dimensions = dimensions;
    _model = model;
    final g = ReverseLungeGeometry.fromFrame(frame, _side);
    if (nowMicros - t > maximumFrameAgeMicros || g == null) {
      _rejected += elapsed;
      final reason = ReverseLungeGeometry.rejectionReason(frame, _side);
      final cue = ReverseLungeGeometry.setupCue(frame, _side) ??
          'Show both hips, both ankles and the selected front knee and foot side-on';
      // A short weak calibration sample pauses existing neutral evidence. A
      // working interruption still discards every unfinished cycle immediately.
      if (nowMicros - t <= maximumFrameAgeMicros &&
          !discontinuity &&
          _base == null &&
          reason != null &&
          (reason.startsWith('required_') || reason == 'pose_unclear') &&
          _calibration.keepAcrossWeakFrame(t)) {
        _previousAccepted = false;
        _health = TrackingStatus.degraded;
        _cue = cue;
      } else {
        _invalidate(cue);
      }
      _reason = reason;
      _diagnostics = {'calibrationSamples': _calibration.sampleCount};
      if (nowMicros - t > maximumFrameAgeMicros) {
        _health = TrackingStatus.lost;
        _cue = 'Camera tracking delayed · return to your starting stance';
        _reason = 'stale_frame';
      }
      return snapshot;
    }
    _health = TrackingStatus.healthy;
    if (_base == null) {
      _rejected += elapsed;
      if (!g.neutral) {
        _invalidate(ReverseLungeGeometry.setupCue(frame, _side)!);
        _reason = g.frontAngle < 160
            ? 'neutral_knees_bent'
            : (g.frontHip.$2 - g.rearHip.$2).abs() > g.legLength * .08
                ? 'neutral_hips_unlevel'
                : 'neutral_feet_apart';
        _diagnostics = {
          'frontKneeDegrees': g.frontAngle,
        };
        return snapshot;
      }
      final baseline = _calibration.add(t, g);
      _progress = _calibration.progress;
      _reason = _calibration.reason;
      _diagnostics = {
        'calibrationSamples': _calibration.sampleCount,
        'frontKneeDegrees': g.frontAngle,
      };
      _cue = _reason == 'neutral_motion'
          ? 'Hold your comfortable stance still · keep the camera steady'
          : 'Hold your starting stance · keep the selected front leg planted';
      if (baseline != null) {
        _base = baseline;
        _previousAccepted = true;
        _reason = null;
      }
      return snapshot;
    }
    final b = _base!, leg = b.legLength;
    final drop = (g.hipY - b.hipY) / leg;
    final back = (b.rearAnkle.$1 - g.rearAnkle.$1) * b.facing / leg;
    _diagnostics = {
      'hipDropLegRatio': drop,
      'backstepLegRatio': back,
      'frontKneeDegrees': g.frontAngle,
    };
    bool scaled(double current, double baseline) =>
        (current / baseline - 1).abs() <= .25;
    final planted = ReverseLungeGeometry.distance(g.frontAnkle, b.frontAnkle) <=
            leg * .10 &&
        ReverseLungeGeometry.distance(g.frontHeel, b.frontHeel) <= leg * .12 &&
        ReverseLungeGeometry.distance(g.frontToe, b.frontToe) <= leg * .12 &&
        (g.frontAnkle.$2 - b.frontAnkle.$2).abs() <= leg * .05 &&
        (g.frontHeel.$2 - b.frontHeel.$2).abs() <= leg * .06 &&
        (g.frontToe.$2 - b.frontToe.$2).abs() <= leg * .06;
    if (!planted ||
        g.facing != b.facing ||
        !scaled(g.frontThigh, b.frontThigh) ||
        !scaled(g.frontShin, b.frontShin) ||
        !scaled(g.torsoLength, b.torsoLength) ||
        (g.frontHip.$1 - b.frontHip.$1).abs() > leg * .32 ||
        (g.rearAnkle.$2 - b.rearAnkle.$2).abs() > leg * .15 ||
        drop < -.10 ||
        drop > .65 ||
        back < -.12 ||
        back > 1.1) {
      _rejected += elapsed;
      _invalidate(
          'Keep the selected front foot planted · step the other leg back');
      _reason = 'working_projection_changed';
      return snapshot;
    }
    final fresh = priorCapture == null || priorNow == null
        ? 0
        : math.max(
            0,
            math.min(nowMicros, priorCapture + maximumFrameAgeMicros) -
                priorNow);
    final credit =
        priorAccepted && !discontinuity ? math.min(elapsed, fresh) : 0;
    _tracked += credit;
    _rejected += elapsed - credit;
    _previousAccepted = true;
    _reason = null;
    _cue = 'Step the other leg back · lower and return to your starting stance';
    if (_attemptStart == null) {
      // Early observed rear-foot travel may overlap a small initial descent.
      // Persist its time and position before the meaningful descent; a bottom
      // pose, knee bend alone or a static split cannot supply this history.
      if (back >= .06 && back <= .24 && drop <= .12 && g.frontAngle >= 130) {
        if (_earlyStepSince == null) {
          _earlyStepSince = t;
          _earlyBack = back;
        }
      } else if (back < .03) {
        _earlyStepSince = null;
      }
      final orderedOverlap = _earlyStepSince != null &&
          t - _earlyStepSince! >= 80000 &&
          back >= .28 &&
          back - _earlyBack >= .06;
      // Observe the backstep before meaningful knee/hip descent. A static
      // split squat or a single bottom frame cannot manufacture this order.
      if (orderedOverlap) {
        _attemptStart = _earlyStepSince;
        _phase = ReverseLungePhase.descending;
      } else if (back >= .28 && drop <= .20 && g.frontAngle >= 135) {
        _stepSince ??= t;
        if (t - _stepSince! >= 80000) {
          _attemptStart = _stepSince;
          _phase = ReverseLungePhase.descending;
        }
      } else {
        _stepSince = null;
      }
    }
    if (_attemptStart != null) {
      if (t - _attemptStart! > 15000000) {
        _invalidate('Return to your starting stance to restart');
        return snapshot;
      }
      _maximumDrop = math.max(_maximumDrop, drop);
      // Full projected selected-front-leg depth; rear knee bend is unmeasured.
      if (back >= .35 && drop >= .28 && g.frontAngle <= 115) {
        _bottomSince ??= t;
        if (t - _bottomSince! >= 140000) _full = true;
      } else {
        _bottomSince = null;
      }
      if (back >= .28 && drop >= .12 && g.frontAngle <= 148) {
        _partialSince ??= t;
        if (t - _partialSince! >= 100000) _hasPartial = true;
      } else {
        _partialSince = null;
      }
      if (drop < _maximumDrop - .04) _phase = ReverseLungePhase.returning;
      if (g.neutral && drop.abs() <= .08 && back.abs() <= .12) {
        _returnSince ??= t;
        if (t - _returnSince! >= 140000) {
          if (t - _attemptStart! >= 900000 &&
              _hasPartial &&
              _reps + _partial < 10000) {
            if (_full) {
              _reps++;
            } else {
              _partial++;
            }
            _cues = [
              CueRequest(
                  id: _full ? 'reverse_lunge_rep' : 'reverse_lunge_partial',
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
