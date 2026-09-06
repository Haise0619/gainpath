part of 'workout_session_bloc.dart';

enum SessionPhase { tracking, paused, finished }

class WorkoutSessionState extends Equatable {
  const WorkoutSessionState({
    required this.routine,
    this.phase = SessionPhase.tracking,
    this.elapsedSec = 0,
    this.reps = 0,
    this.accuracy = 82,
    this.confidence = 88,
    this.recalibrating = false,
    this.lowStreak = 0,
    this.pauseReason,
    this.voiceOn = true,
    this.cue = 'Get into position.',
    this.exerciseIndex = 0,
    this.setNumber = 1,
    this.repsInSet = 0,
  });

  factory WorkoutSessionState.initial(List<Exercise> routine) => WorkoutSessionState(routine: routine);

  final List<Exercise> routine;
  final SessionPhase phase;
  final int elapsedSec;
  final int reps;
  final int accuracy;
  final double confidence;
  final bool recalibrating;
  final int lowStreak;
  final String? pauseReason;
  final bool voiceOn;
  final String cue;
  final int exerciseIndex;
  final int setNumber;
  final int repsInSet;

  bool get paused => phase == SessionPhase.paused;
  Exercise? get currentExercise => routine.isEmpty ? null : routine[exerciseIndex];

  /// mm:ss for the on-screen clock.
  String get clock {
    final m = (elapsedSec ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  WorkoutSessionState copyWith({
    SessionPhase? phase,
    int? elapsedSec,
    int? reps,
    int? accuracy,
    double? confidence,
    bool? recalibrating,
    int? lowStreak,
    String? pauseReason,
    bool clearPauseReason = false,
    bool? voiceOn,
    String? cue,
    int? exerciseIndex,
    int? setNumber,
    int? repsInSet,
  }) =>
      WorkoutSessionState(
        routine: routine,
        phase: phase ?? this.phase,
        elapsedSec: elapsedSec ?? this.elapsedSec,
        reps: reps ?? this.reps,
        accuracy: accuracy ?? this.accuracy,
        confidence: confidence ?? this.confidence,
        recalibrating: recalibrating ?? this.recalibrating,
        lowStreak: lowStreak ?? this.lowStreak,
        pauseReason: clearPauseReason ? null : (pauseReason ?? this.pauseReason),
        voiceOn: voiceOn ?? this.voiceOn,
        cue: cue ?? this.cue,
        exerciseIndex: exerciseIndex ?? this.exerciseIndex,
        setNumber: setNumber ?? this.setNumber,
        repsInSet: repsInSet ?? this.repsInSet,
      );

  @override
  List<Object?> get props => [
        routine, phase, elapsedSec, reps, accuracy, confidence, recalibrating, lowStreak,
        pauseReason, voiceOn, cue, exerciseIndex, setNumber, repsInSet,
      ];
}
