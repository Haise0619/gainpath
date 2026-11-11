import 'package:flutter/foundation.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import 'guided_workout_progress.dart';
import 'workout_audio_controller.dart';

enum SetContinuationStatus { inactive, waiting, countdown, cancelled }

typedef SetReadinessProbe = bool Function(PoseFrame frame, int nowMicros);

abstract interface class WorkoutSetContinuationSession {
  WorkoutSetContinuation get setContinuation;
}

/// Consumes the already-delivered raw poses during rest. Only a fresh pose can
/// finish the countdown. This controller never runs inference or awards reps.
class WorkoutSetContinuation extends ChangeNotifier {
  WorkoutSetContinuation({
    required this.guidance,
    required this.clockMicros,
    required this.canContinue,
    required this.detectorId,
    required this.detectorVersion,
    required this.createProbe,
    required this.startNextSet,
    this.audio,
  });

  final GuidedWorkoutProgress? Function() guidance;
  final int Function() clockMicros;
  final bool Function() canContinue;
  final String detectorId, detectorVersion;
  final SetReadinessProbe? Function() createProbe;
  final VoidCallback startNextSet;
  final WorkoutAudioController? audio;

  static const _preparationMicros = 3000000;
  static const _maximumFrameAgeMicros = 250000;

  bool _enabled = false;
  bool get enabled => _enabled;
  SetContinuationStatus _status = SetContinuationStatus.inactive;
  SetContinuationStatus get status => _status;
  int _remainingSeconds = 0;
  int get remainingSeconds => _remainingSeconds;
  String completionAnnouncement = 'Workout complete.';
  bool get isResting => guidance()?.stage == GuidedWorkoutStage.resting;
  String? get boundaryAnnouncement => switch (guidance()?.stage) {
        GuidedWorkoutStage.resting => guidance()!.remainingRestSeconds > 0
            ? 'Set complete. Rest.'
            : 'Set complete.',
        GuidedWorkoutStage.complete => completionAnnouncement,
        _ => null,
      };

  void finishBoundary() =>
      audio?.finishSet(transition: boundaryAnnouncement, restScoped: isResting);

  int? _restSet, _deadline, _lastCapture, _lastDelivery;
  bool _cancelled = false, _restEndingAnnounced = false;
  bool _disposed = false;
  SetReadinessProbe? _probe;
  (int, int, bool)? _geometry;

  void _publish(SetContinuationStatus status, [int seconds = 0]) {
    if (status == _status && seconds == _remainingSeconds) return;
    _status = status;
    _remainingSeconds = seconds;
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (_disposed || value == _enabled) return;
    _enabled = value;
    if (!value) {
      if (_deadline != null) cancel();
      _clearProbe();
      _publish(SetContinuationStatus.inactive);
    }
    notifyListeners();
  }

  void _clearProbe() {
    _deadline = _lastCapture = _lastDelivery = null;
    _probe = null;
    _geometry = null;
  }

  void leaveRest() {
    if (_disposed) return;
    _restSet = null;
    _cancelled = _restEndingAnnounced = false;
    _clearProbe();
    audio?.cancelTransition();
    _publish(SetContinuationStatus.inactive);
  }

  /// An interruption is sticky for this rest. Manual continuation remains
  /// available once the session's own authorization/lifecycle permits it.
  void cancel() {
    if (_disposed) return;
    final flow = guidance();
    if (flow?.stage != GuidedWorkoutStage.resting) return;
    _restSet = flow!.completedSets;
    _cancelled = true;
    _restEndingAnnounced = true;
    _clearProbe();
    audio?.cancelTransition();
    _publish(enabled
        ? SetContinuationStatus.cancelled
        : SetContinuationStatus.inactive);
  }

  void update({PoseFrame? frame}) {
    if (_disposed) return;
    final flow = guidance();
    if (flow == null || flow.stage != GuidedWorkoutStage.resting) return;
    if (_restSet != flow.completedSets) {
      _restSet = flow.completedSets;
      _cancelled = _restEndingAnnounced = false;
      _clearProbe();
    }
    if (!canContinue()) {
      cancel();
      return;
    }
    if (_cancelled) {
      if (enabled) _publish(SetContinuationStatus.cancelled);
      return;
    }
    final now = clockMicros();
    final restSeconds = flow.remainingRestSeconds;
    if (restSeconds > 0) {
      if (restSeconds <= 3 && !_restEndingAnnounced) {
        _restEndingAnnounced = true;
        audio?.announceTransition(
            'rest-ending-${flow.completedSets}', 'Rest ending. Get ready.',
            nowMicros: now);
      }
      return;
    }
    if (!enabled) return;
    if (_deadline == null) _publish(SetContinuationStatus.waiting);
    if (_lastDelivery != null &&
        now - _lastDelivery! > _maximumFrameAgeMicros) {
      if (_deadline != null) {
        cancel();
        return;
      }
      _clearProbe();
    }
    if (frame == null) return;
    final capture = frame.capturedAtMicros;
    final geometry = (frame.imageWidth, frame.imageHeight, frame.isMirrored);
    if (frame.detectorId != detectorId ||
        frame.modelVersion != detectorVersion ||
        (_geometry != null && _geometry != geometry)) {
      cancel();
      return;
    }
    final lastCapture = _lastCapture;
    if (lastCapture != null && capture <= lastCapture) return;
    if (capture < 0 ||
        capture > now ||
        now - capture > _maximumFrameAgeMicros ||
        (lastCapture != null &&
            capture - lastCapture > _maximumFrameAgeMicros)) {
      if (_deadline != null) {
        cancel();
      } else {
        _clearProbe();
      }
      return;
    }
    final probe = _probe ??= createProbe();
    if (probe == null) {
      cancel(); // A required manual arm or side choice remains outstanding.
      return;
    }
    _geometry = geometry;
    _lastCapture = capture;
    _lastDelivery = now;
    if (!probe(frame, now)) {
      if (_deadline != null) cancel();
      return;
    }
    if (_deadline == null) {
      _deadline = now + _preparationMicros;
      audio?.announceTransition(
          'prepare-set-${flow.completedSets}', 'Hold steady. Wait for ready.',
          nowMicros: now);
    }
    final remaining = _deadline! - now;
    if (remaining > 0) {
      _publish(SetContinuationStatus.countdown, (remaining / 1000000).ceil());
      return;
    }
    if (canContinue()) startNextSet();
    if (flow.stage == GuidedWorkoutStage.resting) {
      cancel();
    } else {
      leaveRest();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _clearProbe();
    super.dispose();
  }
}
