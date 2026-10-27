import 'dart:math' as math;
import '../pose/pose_frame.dart';
import '../pose/tracking_health.dart';
import '../pose/audio_cue_arbiter.dart';
import 'wall_push_up_geometry.dart';
import 'wall_push_up_calibration.dart';

enum WallPushUpPhase { ready, lowering, pushing }

class WallPushUpUpdate {
  const WallPushUpUpdate(
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
  final WallPushUpSide? selectedSide;
  final WallPushUpPhase phase;
  final String calibrationCue;
  final double calibrationProgress;
  final double? formScorePercent;
  final List<CueRequest> cues;
}

/// Provisional visible-arm wall push-up rules. No wall/force/symmetry detection.
class WallPushUpAnalyzer {
  static const version = 'wall-push-up-side-v1';
  static const maximumFrameAgeMicros = 250000;
  final _calibration = WallPushUpCalibration();
  WallPushUpSide? _side;
  WallPushUpGeometry? _base;
  (int, int)? _dimensions;
  int? _lastCapture, _lastNow, _attemptStart, _flexionSince, _returnSince;
  int _reps = 0, _partial = 0, _tracked = 0, _rejected = 0, _attemptFrames = 0;
  double _score = 0,
      _minimumAngle = 180,
      _minimumBody = 180,
      _previousAngle = 180;
  bool _calibrated = false, _full = false;
  TrackingStatus _health = TrackingStatus.degraded;
  WallPushUpPhase _phase = WallPushUpPhase.ready;
  String _calibrationCue =
      'Face a wall · palms at chest height and arms extended';
  List<CueRequest> _cues = const [];
  WallPushUpUpdate get snapshot => WallPushUpUpdate(
      repetitions: _reps,
      partialRepetitions: _partial,
      trackedDurationMicros: _tracked,
      rejectedDurationMicros: _rejected,
      needsCalibration: !_calibrated,
      health: _health,
      selectedSide: _side,
      phase: _phase,
      calibrationCue: _calibrationCue,
      calibrationProgress: _calibrated ? 1 : _calibration.progress,
      formScorePercent:
          _reps + _partial == 0 ? null : _score / (_reps + _partial),
      cues: List.unmodifiable(_cues));
  void _invalidate() {
    _calibrated = false;
    _calibration.reset();
    _base = null;
    _attemptStart = null;
    _flexionSince = null;
    _returnSince = null;
    _full = false;
    _phase = WallPushUpPhase.ready;
    _health = TrackingStatus.degraded;
    _cues = const [];
    _calibrationCue = 'Reset with arms extended · palms steady on the wall';
  }

  void pause() {
    _invalidate();
    _lastCapture = null;
    _lastNow = null;
  }

  WallPushUpUpdate tick({required int nowMicros}) {
    if (_lastNow == null || nowMicros <= _lastNow!) return snapshot;
    if (_lastCapture == null ||
        nowMicros - _lastCapture! > maximumFrameAgeMicros) {
      _rejected += nowMicros - _lastNow!;
      _invalidate();
      _health = TrackingStatus.lost;
      _calibrationCue = 'Camera tracking delayed · hold your starting position';
    } else if (_calibrated) {
      _tracked += nowMicros - _lastNow!;
    } else {
      _rejected += nowMicros - _lastNow!;
    }
    _lastNow = nowMicros;
    return snapshot;
  }

  WallPushUpUpdate update(PoseFrame frame, {required int nowMicros}) {
    final t = frame.capturedAtMicros;
    if (t < 0 ||
        t > nowMicros ||
        (_lastCapture != null && t <= _lastCapture!) ||
        (_lastNow != null && nowMicros < _lastNow!)) {
      return snapshot;
    }
    final elapsed = _lastNow == null ? 0 : nowMicros - _lastNow!;
    final size = (frame.imageWidth, frame.imageHeight);
    if ((_lastCapture != null && t - _lastCapture! > maximumFrameAgeMicros) ||
        (_dimensions != null && size != _dimensions)) {
      _invalidate();
    }
    _dimensions = size;
    _lastCapture = t;
    _lastNow = nowMicros;
    _cues = const [];
    if (_side == null ||
        (!_calibrated &&
            _reps + _partial == 0 &&
            _calibration.isEmpty &&
            WallPushUpGeometry.confidence(frame, _side!) < .65)) {
      final sides = WallPushUpSide.values.toList()
        ..sort((a, b) => WallPushUpGeometry.confidence(frame, b)
            .compareTo(WallPushUpGeometry.confidence(frame, a)));
      for (final side in sides) {
        final g = WallPushUpGeometry.fromFrame(frame, side);
        if (WallPushUpGeometry.confidence(frame, side) >= .65 &&
            g != null &&
            g.neutral) {
          if (_side != side) _calibration.reset();
          _side = side;
          break;
        }
      }
    }
    final g =
        _side == null ? null : WallPushUpGeometry.fromFrame(frame, _side!);
    if (nowMicros - t > maximumFrameAgeMicros ||
        g == null ||
        WallPushUpGeometry.confidence(frame, _side!) < .65 ||
        g.bodyAngleDegrees < 140 ||
        g.torsoAngleDegrees.abs() > 60) {
      _rejected += elapsed;
      final brief = !_calibrated &&
          nowMicros - t <= maximumFrameAgeMicros &&
          (g == null || g.bodyAngleDegrees >= 140) &&
          _calibration.keepAcrossBadSample(t);
      if (!brief) {
        _invalidate();
      } else {
        _health = TrackingStatus.degraded;
      }
      _calibrationCue = nowMicros - t > maximumFrameAgeMicros
          ? 'Camera tracking delayed · hold your starting position'
          : WallPushUpGeometry.setupCue(frame, _side);
      return snapshot;
    }
    _health = TrackingStatus.healthy;
    if (!_calibrated) {
      _rejected += elapsed;
      if (!g.neutral) {
        _calibration.keepAcrossBadSample(t);
        _calibrationCue = WallPushUpGeometry.setupCue(frame, _side);
        return snapshot;
      }
      final base = _calibration.add(t, g);
      if (base != null) {
        _base = base;
        _calibrated = true;
        _previousAngle = g.elbowAngleDegrees;
      }
      _calibrationCue = 'Hold arms extended · palms steady on the wall';
      return snapshot;
    }
    final base = _base!;
    if (g.wristDistance(base) > .12 ||
        (g.torsoLength / base.torsoLength - 1).abs() > .20 ||
        g.horizontalReach * base.horizontalReach <= 0 ||
        g.handHeight.abs() > .8) {
      _rejected += elapsed;
      _invalidate();
      _calibrationCue = 'Keep palms in place · reset your wall position';
      return snapshot;
    }
    _tracked += elapsed;
    final cues = <CueRequest>[];
    if (g.bodyAngleDegrees < 165) {
      cues.add(const CueRequest(
          id: 'wall_body',
          text: 'Keep your body in a straight line.',
          priority: CuePriority.correction));
    }
    if (_attemptStart == null && g.elbowAngleDegrees <= 140) {
      _attemptStart = t;
      _attemptFrames = 0;
      _minimumAngle = 180;
      _minimumBody = 180;
      _full = false;
      _flexionSince = null;
      _returnSince = null;
      _phase = WallPushUpPhase.lowering;
    }
    if (_attemptStart != null) {
      _attemptFrames++;
      _minimumAngle = math.min(_minimumAngle, g.elbowAngleDegrees);
      _minimumBody = math.min(_minimumBody, g.bodyAngleDegrees);
      if (g.elbowAngleDegrees <= 105 &&
          (base.reach - g.reach) / base.torsoLength >= .15) {
        _flexionSince ??= t;
        if (t - _flexionSince! >= 120000) _full = true;
      } else {
        _flexionSince = null;
      }
      if (g.elbowAngleDegrees > _previousAngle + 3) {
        _phase = WallPushUpPhase.pushing;
      }
      final duration = t - _attemptStart!;
      if (duration > 15000000) {
        _invalidate();
      } else if (g.elbowAngleDegrees >= 155 && g.reach >= base.reach * .85) {
        _returnSince ??= t;
        if (t - _returnSince! >= 100000) {
          if (duration >= 700000 &&
              _attemptFrames >= 6 &&
              _minimumAngle <= 130) {
            if (_full) {
              _reps++;
            } else {
              _partial++;
            }
            _score += (100 - (_full ? 0 : 30) - (_minimumBody < 165 ? 20 : 0))
                .clamp(0, 100);
            cues.add(CueRequest(
                id: _full ? 'wall_rep' : 'wall_partial',
                text: _full ? '$_reps' : 'Partial movement recorded.',
                priority: CuePriority.encouragement));
          }
          _attemptStart = null;
          _phase = WallPushUpPhase.ready;
        }
      } else {
        _returnSince = null;
      }
    }
    _previousAngle = g.elbowAngleDegrees;
    _cues = cues;
    return snapshot;
  }
}
