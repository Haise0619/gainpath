import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/workout.dart';

part 'workout_session_event.dart';
part 'workout_session_state.dart';

/// Runs one AI-guided workout session (SD-M2.1, SD-M2.3, SD-M2.4).
///
/// The view owns the 1 Hz timer and the camera/skeleton animation; every
/// rule lives here: rep counting, routine progress, the confidence-driven
/// recalibration state machine and its auto-pause escalation. In the
/// prototype the confidence reading is simulated; a real pose pipeline
/// would dispatch the same [SessionTicked] with a measured value.
class WorkoutSessionBloc extends Bloc<WorkoutSessionEvent, WorkoutSessionState> {
  WorkoutSessionBloc(WorkoutRepository repo, {math.Random? random})
      : _cues = repo.voiceCues,
        _rng = random ?? math.Random(),
        super(WorkoutSessionState.initial(repo.routine)) {
    on<SessionTicked>(_onTicked);
    on<TrackingIssueSimulated>(_onTrackingIssueSimulated);
    on<VoiceToggled>((_, emit) => emit(state.copyWith(voiceOn: !state.voiceOn)));
    on<SessionPaused>((e, emit) => emit(state.copyWith(phase: SessionPhase.paused, pauseReason: e.reason)));
    on<SessionResumed>((_, emit) => emit(state.copyWith(phase: SessionPhase.tracking, clearPauseReason: true)));
    on<SessionEnded>((_, emit) => emit(state.copyWith(phase: SessionPhase.finished)));
  }

  static const recalibrateBelowPct = 70;
  static const lostBelowPct = 50;
  static const lostTicksBeforePause = 5;
  static const trackingLostReason = 'Tracking lost for a few seconds, so we paused for you.';

  final List<String> _cues;
  final math.Random _rng;

  void _onTicked(SessionTicked e, Emitter<WorkoutSessionState> emit) {
    if (state.phase != SessionPhase.tracking) return;
    final delta = e.confidenceDelta ?? (_rng.nextDouble() * 14 - 7);
    var s = state.copyWith(
      elapsedSec: state.elapsedSec + 1,
      confidence: (state.confidence + delta).clamp(28, 98).toDouble(),
    );
    s = _evaluateConfidence(s);
    if (s.recalibrating || s.phase != SessionPhase.tracking) {
      emit(s);
      return;
    }
    s = s.copyWith(accuracy: s.confidence.round());
    if (s.elapsedSec % 3 == 0) {
      s = _advanceRoutineProgress(s.copyWith(reps: s.reps + 1));
      if (s.voiceOn && _cues.isNotEmpty) {
        s = s.copyWith(cue: _cues[_rng.nextInt(_cues.length)]);
      }
    }
    emit(s);
  }

  /// Demo affordance: first call drops confidence into the recalibration
  /// band; a second call while recalibrating forces the escalation path.
  void _onTrackingIssueSimulated(TrackingIssueSimulated e, Emitter<WorkoutSessionState> emit) {
    if (state.phase != SessionPhase.tracking) return;
    final s = state.recalibrating
        ? state.copyWith(confidence: 32, lowStreak: lostTicksBeforePause)
        : state.copyWith(confidence: 58);
    emit(_evaluateConfidence(s));
  }

  /// Steps the exercise/set pointer forward as reps accumulate, so the
  /// "Exercise 2 of 4 · Set 3/4" label always matches the rep counter.
  static WorkoutSessionState _advanceRoutineProgress(WorkoutSessionState s) {
    final current = s.currentExercise;
    if (current == null) return s;
    final repsInSet = s.repsInSet + 1;
    if (repsInSet < current.reps) return s.copyWith(repsInSet: repsInSet);
    if (s.setNumber < current.sets) return s.copyWith(repsInSet: 0, setNumber: s.setNumber + 1);
    if (s.exerciseIndex < s.routine.length - 1) {
      return s.copyWith(repsInSet: 0, setNumber: 1, exerciseIndex: s.exerciseIndex + 1);
    }
    return s.copyWith(repsInSet: 0);
  }

  /// Confidence state machine (SD-M2.3): below 70% hand off to the
  /// alignment overlay; if it stays below 50% for five ticks while
  /// recalibrating, escalate into an automatic pause.
  static WorkoutSessionState _evaluateConfidence(WorkoutSessionState s) {
    final lowStreak = s.confidence < lostBelowPct ? s.lowStreak + 1 : 0;
    s = s.copyWith(lowStreak: lowStreak);
    if (!s.recalibrating) {
      return s.confidence < recalibrateBelowPct ? s.copyWith(recalibrating: true) : s;
    }
    if (s.confidence >= recalibrateBelowPct) {
      return s.copyWith(recalibrating: false, lowStreak: 0);
    }
    if (lowStreak >= lostTicksBeforePause) {
      return s.copyWith(recalibrating: false, phase: SessionPhase.paused, pauseReason: trackingLostReason);
    }
    return s;
  }
}
