import 'dart:math' as math;
import '../pose/audio_cue_arbiter.dart';
import '../pose/one_euro_filter.dart';
import '../pose/pose_frame.dart';
import '../pose/tracking_health.dart';
import 'shoulder_press_geometry.dart';

enum ShoulderPressPhase { ready, pressing, lowering }

class ShoulderPressUpdate {
  const ShoulderPressUpdate(
      {required this.repetitions,
      required this.partialRepetitions,
      required this.trackedDurationMicros,
      required this.rejectedDurationMicros,
      required this.needsCalibration,
      required this.health,
      required this.phase,
      required this.calibrationCue,
      required this.calibrationProgress,
      required this.requiresBottomReset,
      required this.decision,
      required this.cues});
  final int repetitions,
      partialRepetitions,
      trackedDurationMicros,
      rejectedDurationMicros;
  final bool needsCalibration;
  final TrackingStatus health;
  final ShoulderPressPhase phase;
  final String calibrationCue;
  final double calibrationProgress;
  final bool requiresBottomReset;

  /// Bounded scalar reason; no camera images, landmarks or personal data.
  final String decision;
  double? get formScorePercent => null;
  final List<CueRequest> cues;
}

/// Counts projected bilateral bottom → overhead → bottom cycles only.
/// O(1) bounded state, capture-time dwell and fresh raw/filtered agreement.
/// Targets, sets and rest belong to the Routine/session, never the analyzer.
class ShoulderPressAnalyzer {
  static const version = 'dumbbell-shoulder-press-front-v1';
  static const maximumFrameAgeMicros = 250000;
  static const lostAfterMicros = 500000;
  static const implementationRevision = 'projection-recovery-2';
  ShoulderPressGeometry? _base, _anchor;
  (int, int, String, String, bool)? _identity;
  int? _lastCapture,
      _lastNow,
      _calibrationStart,
      _startSince,
      _attemptStart,
      _peakSince,
      _returnSince;
  int? _unavailableSince, _rearmSince;
  int _reps = 0, _partials = 0, _tracked = 0, _rejected = 0, _samples = 0;
  bool _full = false;
  bool _requiresBottomReset = false;
  String _decision = 'starting';
  double _progress = 0, _maximumAngle = 0;
  List<OneEuroFilter> _filters = _newFilters();
  static List<OneEuroFilter> _newFilters() =>
      [for (var i = 0; i < 2; i++) OneEuroFilter(minCutoff: 4, beta: .02)];
  TrackingStatus _health = TrackingStatus.degraded;
  ShoulderPressPhase _phase = ShoulderPressPhase.ready;
  String _cue = 'Face the camera · hold both elbows bent at shoulder height';
  List<CueRequest> _cues = const [];
  ShoulderPressUpdate get snapshot => ShoulderPressUpdate(
      repetitions: _reps,
      partialRepetitions: _partials,
      trackedDurationMicros: _tracked,
      rejectedDurationMicros: _rejected,
      needsCalibration: _base == null,
      health: _health,
      phase: _phase,
      calibrationCue: _cue,
      calibrationProgress: _progress,
      requiresBottomReset: _requiresBottomReset,
      decision: _decision,
      cues: List.unmodifiable(_cues));
  void _clearAttempt() {
    _startSince = _attemptStart = _peakSince = _returnSince = null;
    _full = false;
    _maximumAngle = 0;
    _phase = ShoulderPressPhase.ready;
  }

  void _invalidate() {
    _base = _anchor = null;
    _calibrationStart = null;
    _samples = 0;
    _progress = 0;
    _requiresBottomReset = false;
    _rearmSince = null;
    _clearAttempt();
    _filters = _newFilters();
    _health = TrackingStatus.degraded;
    _cues = const [];
    _cue = 'Face front · reset both hands above bent elbows at shoulder height';
  }

  void pause() {
    _invalidate();
    _unavailableSince = null;
    _decision = 'paused';
    _lastCapture = _lastNow = null;
  }

  ShoulderPressUpdate tick({required int nowMicros}) {
    if (_lastNow == null || nowMicros <= _lastNow!) return snapshot;
    final elapsed = nowMicros - _lastNow!;
    if (_lastCapture == null ||
        nowMicros - _lastCapture! > maximumFrameAgeMicros) {
      _rejected += elapsed;
      _invalidate();
      _health = TrackingStatus.lost;
      _decision = 'watchdog_stale';
      _cue = 'Camera tracking delayed · reset both arms';
    } else if (_base != null && _health == TrackingStatus.healthy) {
      _tracked += elapsed;
    } else {
      _rejected += elapsed;
    }
    _lastNow = nowMicros;
    return snapshot;
  }

  ShoulderPressUpdate update(PoseFrame frame, {required int nowMicros}) {
    final previousAssessable =
        _base != null && _health == TrackingStatus.healthy;
    final t = frame.capturedAtMicros,
        elapsed = _lastNow == null ? 0 : math.max(0, nowMicros - _lastNow!);
    if (t < 0 ||
        nowMicros < 0 ||
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
    _lastCapture = t;
    _lastNow = nowMicros;
    _identity = identity;
    _cues = const [];
    final g = ShoulderPressGeometry.fromFrame(frame);
    if (nowMicros - t > maximumFrameAgeMicros) {
      _rejected += elapsed;
      _invalidate();
      _health = TrackingStatus.lost;
      _decision = 'stale_frame';
      _cue = 'Camera frames delayed · hold the starting position';
      return snapshot;
    }
    if (g != null && _base != null && !g.bodyStableFrom(_base!)) {
      _rejected += elapsed;
      _invalidate();
      _unavailableSince = null;
      _decision = 'body_displacement';
      _cue = 'Camera or body moved · hold the starting position to recalibrate';
      return snapshot;
    }
    if (g == null || !g.frontUpright) {
      _rejected += elapsed;
      _unavailableSince ??= t;
      // Discard the entire unfinished cycle immediately. Retaining only the
      // setup briefly is safe because a sustained observed bottom is required
      // before another attempt; no hidden peak/return can be reconstructed.
      _clearAttempt();
      _filters = _newFilters();
      _rearmSince = null;
      if (_base == null || t - _unavailableSince! >= lostAfterMicros) {
        _invalidate();
        _decision = 'tracking_lost';
      } else {
        _requiresBottomReset = true;
        _decision = 'brief_tracking_loss';
      }
      _health = t - _unavailableSince! >= lostAfterMicros
          ? TrackingStatus.lost
          : TrackingStatus.degraded;
      _cue = ShoulderPressGeometry.rejectionCue(frame, g);
      return snapshot;
    }
    if (_unavailableSince != null &&
        t - _unavailableSince! >= lostAfterMicros) {
      _invalidate();
      _decision = 'prolonged_loss';
    }
    _unavailableSince = null;
    if (_base == null) {
      _rejected += elapsed;
      if (!g.neutral || !g.symmetric) {
        _invalidate();
        _decision = 'starting_position';
        return snapshot;
      }
      if (_anchor == null || !g.stableFrom(_anchor!, calibration: true)) {
        _anchor = g;
        _calibrationStart = t;
        _samples = 0;
      }
      _samples++;
      _progress = ((t - _calibrationStart!) / 650000).clamp(0.0, 1.0);
      _cue = 'Hold steady · both hands above bent elbows at shoulder height';
      _decision = 'calibrating';
      if (_progress >= 1 && _samples >= 5) {
        _base = _anchor;
        _health = TrackingStatus.healthy;
        _decision = 'ready';
        for (var i = 0; i < 2; i++) {
          _filters[i].filter(g.angles[i], timestampSeconds: t / 1e6);
        }
      }
      return snapshot;
    }
    if (!g.symmetric) {
      _rejected += elapsed;
      _clearAttempt();
      _filters = _newFilters();
      _requiresBottomReset = true;
      _rearmSince = null;
      _health = TrackingStatus.degraded;
      _decision = 'arms_out_of_sync';
      _cue = 'Move both arms together · return to shoulder height to restart';
      return snapshot;
    }
    _health = TrackingStatus.healthy;
    if (previousAssessable) {
      _tracked += elapsed;
    } else {
      _rejected += elapsed;
    }
    if (_requiresBottomReset) {
      _decision = 'awaiting_bottom_reset';
      _cue =
          'Return both hands above bent elbows at shoulder height to restart';
      if (g.neutral) {
        _rearmSince ??= t;
        if (t - _rearmSince! >= 100000) {
          _requiresBottomReset = false;
          _rearmSince = null;
          _filters = _newFilters();
          for (var i = 0; i < 2; i++) {
            _filters[i].filter(g.angles[i], timestampSeconds: t / 1e6);
          }
          _decision = 'ready';
        }
      } else {
        _rearmSince = null;
      }
      return snapshot;
    }
    final angle = math.min(
        _filters[0].filter(g.angles[0], timestampSeconds: t / 1e6),
        _filters[1].filter(g.angles[1], timestampSeconds: t / 1e6));
    final raw = math.min(g.angles[0], g.angles[1]);
    _cue = 'Press both arms overhead · return with control';
    _decision = 'ready';
    if (_attemptStart == null) {
      if (angle >= 115 && raw >= 115) {
        _startSince ??= t;
        if (t - _startSince! >= 70000) {
          _attemptStart = _startSince;
          _phase = ShoulderPressPhase.pressing;
          _decision = 'pressing';
        }
      } else {
        _startSince = null;
      }
    }
    if (_attemptStart != null) {
      _decision = _phase.name;
      _maximumAngle = math.max(_maximumAngle, angle);
      if (g.overhead && angle >= 155) {
        _peakSince ??= t;
        if (t - _peakSince! >= 120000) {
          _full = true;
          _decision = 'overhead_observed';
        }
      } else {
        _peakSince = null;
      }
      if (angle < _maximumAngle - 5) {
        _phase = ShoulderPressPhase.lowering;
        _decision = 'lowering';
      }
      final duration = t - _attemptStart!;
      if (duration > 15000000) {
        _invalidate();
      } else if (g.neutral && angle <= 115) {
        _returnSince ??= t;
        if (t - _returnSince! >= 100000) {
          if (duration >= 600000 &&
              _maximumAngle >= 122 &&
              _reps + _partials < 10000) {
            if (_full) {
              _reps++;
              _decision = 'rep_completed';
            } else {
              _partials++;
              _decision = 'partial_completed';
            }
            _cues = [
              CueRequest(
                  id: _full ? 'shoulder_press_rep' : 'shoulder_press_partial',
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
