import 'dart:math' as math;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/live_session/workout_session_bloc.dart';
import 'package:gainpath_domain/workout.dart';

class _FakeWorkoutRepository implements WorkoutRepository {
  @override
  List<Exercise> get routine => const [
        Exercise('Squat', 'Lower', 2, 2, 'Chest up', '', 'Quads'),
        Exercise('Press', 'Upper', 1, 1, 'Brace', '', 'Chest'),
      ];
  @override
  List<String> get voiceCues => const ['Keep going.'];
  @override
  List<WorkoutRecord> get history => const [];
  @override
  int get heightCm => 170;
}

WorkoutSessionBloc _bloc() => WorkoutSessionBloc(_FakeWorkoutRepository(), random: math.Random(1));

/// Ticks with a zero confidence delta so confidence stays at the initial 88.
void _tick(WorkoutSessionBloc b, int n) {
  for (var i = 0; i < n; i++) {
    b.add(const SessionTicked(confidenceDelta: 0));
  }
}

void main() {
  blocTest<WorkoutSessionBloc, WorkoutSessionState>(
    'every third tick counts a rep and advances the routine pointer',
    build: _bloc,
    act: (b) => _tick(b, 6),
    verify: (b) {
      expect(b.state.elapsedSec, 6);
      expect(b.state.reps, 2);
      // Squat: 2 reps per set -> after 2 reps we are on set 2 of the squat.
      expect(b.state.exerciseIndex, 0);
      expect(b.state.setNumber, 2);
      expect(b.state.accuracy, 88);
      expect(b.state.cue, 'Keep going.');
    },
  );

  blocTest<WorkoutSessionBloc, WorkoutSessionState>(
    'finishing every set of an exercise moves to the next exercise',
    build: _bloc,
    act: (b) => _tick(b, 12), // 4 reps = 2 sets of squat
    verify: (b) {
      expect(b.state.reps, 4);
      expect(b.state.exerciseIndex, 1);
      expect(b.state.setNumber, 1);
    },
  );

  blocTest<WorkoutSessionBloc, WorkoutSessionState>(
    'ticks are ignored while paused, and resuming clears the pause reason',
    build: _bloc,
    act: (b) => b
      ..add(const SessionPaused(reason: 'Member tapped pause'))
      ..add(const SessionTicked(confidenceDelta: 0))
      ..add(const SessionResumed())
      ..add(const SessionTicked(confidenceDelta: 0)),
    verify: (b) {
      expect(b.state.elapsedSec, 1);
      expect(b.state.phase, SessionPhase.tracking);
      expect(b.state.pauseReason, isNull);
    },
  );

  blocTest<WorkoutSessionBloc, WorkoutSessionState>(
    'confidence under 70 enters recalibration and suspends rep counting',
    build: _bloc,
    act: (b) => b
      ..add(const SessionTicked(confidenceDelta: -20)) // 88 -> 68
      ..add(const SessionTicked(confidenceDelta: 0))
      ..add(const SessionTicked(confidenceDelta: 0)),
    verify: (b) {
      expect(b.state.recalibrating, isTrue);
      expect(b.state.reps, 0);
      expect(b.state.elapsedSec, 3);
    },
  );

  blocTest<WorkoutSessionBloc, WorkoutSessionState>(
    'confidence recovering to 70 or more leaves recalibration',
    build: _bloc,
    act: (b) => b
      ..add(const SessionTicked(confidenceDelta: -20)) // 68, recalibrating
      ..add(const SessionTicked(confidenceDelta: 5)), // 73, cleared
    verify: (b) => expect(b.state.recalibrating, isFalse),
  );

  blocTest<WorkoutSessionBloc, WorkoutSessionState>(
    'five ticks under 50 while recalibrating auto-pause the session',
    build: _bloc,
    act: (b) {
      b.add(const SessionTicked(confidenceDelta: -40)); // 48, recalibrating, streak 1
      for (var i = 0; i < 4; i++) {
        b.add(const SessionTicked(confidenceDelta: 0)); // streak 2..5
      }
    },
    verify: (b) {
      expect(b.state.phase, SessionPhase.paused);
      expect(b.state.recalibrating, isFalse);
      expect(b.state.pauseReason, WorkoutSessionBloc.trackingLostReason);
    },
  );

  blocTest<WorkoutSessionBloc, WorkoutSessionState>(
    'simulated tracking issue escalates on the second tap',
    build: _bloc,
    act: (b) => b
      ..add(const TrackingIssueSimulated())
      ..add(const TrackingIssueSimulated()),
    verify: (b) => expect(b.state.phase, SessionPhase.paused),
  );

  blocTest<WorkoutSessionBloc, WorkoutSessionState>(
    'ending the session finishes it and voice can be toggled',
    build: _bloc,
    act: (b) => b
      ..add(const VoiceToggled())
      ..add(const SessionEnded()),
    verify: (b) {
      expect(b.state.voiceOn, isFalse);
      expect(b.state.phase, SessionPhase.finished);
    },
  );
}
