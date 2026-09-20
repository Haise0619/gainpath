part of 'workout_session_bloc.dart';

sealed class WorkoutSessionEvent extends Equatable {
  const WorkoutSessionEvent();
  @override
  List<Object?> get props => [];
}

/// One second of tracking elapsed. [confidenceDelta] overrides the simulated
/// confidence drift (used by tests and, later, a real pose pipeline).
class SessionTicked extends WorkoutSessionEvent {
  const SessionTicked({this.confidenceDelta});
  final double? confidenceDelta;
  @override
  List<Object?> get props => [confidenceDelta];
}

/// Demo control: force a tracking-confidence drop.
class TrackingIssueSimulated extends WorkoutSessionEvent {
  const TrackingIssueSimulated();
}

/// Toggle spoken cues (UC-2.7).
class VoiceToggled extends WorkoutSessionEvent {
  const VoiceToggled();
}

/// Member tapped pause (SD-M2.4); [reason] is set when the system paused.
class SessionPaused extends WorkoutSessionEvent {
  const SessionPaused({this.reason});
  final String? reason;
  @override
  List<Object?> get props => [reason];
}

class SessionResumed extends WorkoutSessionEvent {
  const SessionResumed();
}

class SessionEnded extends WorkoutSessionEvent {
  const SessionEnded();
}
