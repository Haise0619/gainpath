import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import '../domain/workout_contracts.dart';

enum WorkoutSessionStatus { idle, tracking, paused, saved }

class WorkoutSessionState extends Equatable {
  const WorkoutSessionState({
    required this.plan,
    this.status = WorkoutSessionStatus.idle,
    this.sessionId,
    this.repetitions = 0,
    this.trackingConfidence = 0,
    this.accuracy = 0,
    this.summary,
    this.errorMessage,
  });

  factory WorkoutSessionState.initial(WorkoutPlan plan) {
    return WorkoutSessionState(plan: plan);
  }

  final WorkoutPlan plan;
  final WorkoutSessionStatus status;
  final String? sessionId;
  final int repetitions;
  final int trackingConfidence;
  final int accuracy;
  final WorkoutSessionSummary? summary;
  final String? errorMessage;

  WorkoutSessionState copyWith({
    WorkoutSessionStatus? status,
    String? sessionId,
    int? repetitions,
    int? trackingConfidence,
    int? accuracy,
    WorkoutSessionSummary? summary,
    String? errorMessage,
  }) {
    return WorkoutSessionState(
      plan: plan,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      repetitions: repetitions ?? this.repetitions,
      trackingConfidence: trackingConfidence ?? this.trackingConfidence,
      accuracy: accuracy ?? this.accuracy,
      summary: summary ?? this.summary,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        plan,
        status,
        sessionId,
        repetitions,
        trackingConfidence,
        accuracy,
        summary,
        errorMessage,
      ];
}

sealed class WorkoutSessionEvent extends Equatable {
  const WorkoutSessionEvent();

  @override
  List<Object?> get props => [];
}

class WorkoutStarted extends WorkoutSessionEvent {
  const WorkoutStarted({this.startedAt});

  final DateTime? startedAt;

  @override
  List<Object?> get props => [startedAt];
}

class WorkoutPoseTicked extends WorkoutSessionEvent {
  const WorkoutPoseTicked({
    required this.timestampMicros,
    required this.movementMetric,
  });

  final int timestampMicros;
  final double movementMetric;

  @override
  List<Object?> get props => [timestampMicros, movementMetric];
}

class WorkoutEnded extends WorkoutSessionEvent {
  const WorkoutEnded({this.endedAt});

  final DateTime? endedAt;

  @override
  List<Object?> get props => [endedAt];
}

class WorkoutSessionBloc
    extends Bloc<WorkoutSessionEvent, WorkoutSessionState> {
  WorkoutSessionBloc({
    required WorkoutRepository repository,
    WorkoutPlan plan = WorkoutPlan.starter,
    required PoseDetector detector,
    DateTime Function()? clock,
  })  : _repository = repository,
        _detector = detector,
        _clock = clock ?? DateTime.now,
        super(WorkoutSessionState.initial(plan)) {
    on<WorkoutStarted>(_onStarted);
    on<WorkoutPoseTicked>(_onPoseTicked);
    on<WorkoutEnded>(_onEnded);
  }

  final WorkoutRepository _repository;
  final PoseDetector _detector;
  final DateTime Function() _clock;
  PoseSessionCoordinator? _coordinator;
  DateTime? _startedAt;

  WorkoutRepository get repository => _repository;
  int _revision = 0;
  bool _processing = false;
  bool _saving = false;
  WorkoutSessionSummary? _pendingSummary;

  void _onStarted(WorkoutStarted event, Emitter<WorkoutSessionState> emit) {
    if (_saving ||
        (state.status != WorkoutSessionStatus.idle &&
            state.status != WorkoutSessionStatus.saved)) {
      return;
    }
    _revision++;
    _pendingSummary = null;
    final exercise = state.plan.exercises.first;
    _startedAt = event.startedAt ?? _clock();
    final random = Random.secure();
    final sessionId = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    _coordinator = PoseSessionCoordinator(
      detector: _detector,
      healthMonitor: TrackingHealthMonitor(),
      repetition: RepetitionFsm(
        downThreshold: exercise.downThreshold,
        upThreshold: exercise.upThreshold,
      ),
    );
    emit(WorkoutSessionState(
      plan: state.plan,
      status: WorkoutSessionStatus.tracking,
      sessionId: sessionId,
      repetitions: 0,
      trackingConfidence: 0,
      accuracy: 0,
    ));
  }

  Future<void> _onPoseTicked(
    WorkoutPoseTicked event,
    Emitter<WorkoutSessionState> emit,
  ) async {
    final coordinator = _coordinator;
    if (coordinator == null ||
        _processing ||
        _saving ||
        _pendingSummary != null ||
        (state.status != WorkoutSessionStatus.tracking &&
            state.status != WorkoutSessionStatus.paused)) {
      return;
    }
    final revision = _revision;
    _processing = true;
    try {
      final result = await coordinator.process(
        PoseInput(timestampMicros: event.timestampMicros),
        movementMetric: event.movementMetric,
      );
      if (revision != _revision || emit.isDone) return;
      emit(state.copyWith(
        status: result.health.status == TrackingStatus.lost
            ? WorkoutSessionStatus.paused
            : WorkoutSessionStatus.tracking,
        repetitions: result.repetition.count,
        trackingConfidence: result.score.trackingConfidence,
        accuracy: result.score.accuracy,
      ));
    } catch (_) {
      if (revision == _revision && !emit.isDone) {
        emit(state.copyWith(
            status: WorkoutSessionStatus.paused,
            errorMessage: 'Tracking unavailable. Try again.'));
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _onEnded(
    WorkoutEnded event,
    Emitter<WorkoutSessionState> emit,
  ) async {
    if (_startedAt == null ||
        state.sessionId == null ||
        _saving ||
        state.status == WorkoutSessionStatus.saved) {
      return;
    }
    final revision = ++_revision;
    _saving = true;
    final summary = _pendingSummary ??= WorkoutSessionSummary(
      userId: _repository.scope.userId,
      organizationId: _repository.scope.organizationId,
      sessionId: state.sessionId!,
      exerciseId: state.plan.exercises.first.id,
      repetitions: state.repetitions,
      accuracy: state.accuracy,
      startedAt: _startedAt!,
      endedAt: event.endedAt ?? _clock(),
    );
    try {
      await _repository.saveLocal(summary);
      if (revision == _revision && !emit.isDone) {
        emit(state.copyWith(
            status: WorkoutSessionStatus.saved, summary: summary));
      }
    } catch (_) {
      if (revision == _revision && !emit.isDone) {
        emit(state.copyWith(
            status: WorkoutSessionStatus.paused,
            errorMessage: 'Unable to save workout. Retry saving.'));
      }
    } finally {
      _saving = false;
    }
  }

  @override
  Future<void> close() {
    _revision++;
    return super.close();
  }
}
