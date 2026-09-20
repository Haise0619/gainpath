import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/workout_contracts.dart';

enum WorkoutHistoryStatus { initial, loading, loaded, syncing, failure }

class WorkoutHistoryState extends Equatable {
  const WorkoutHistoryState({
    this.status = WorkoutHistoryStatus.initial,
    this.records = const [],
    this.errorMessage,
  });

  final WorkoutHistoryStatus status;
  final List<WorkoutSessionRecord> records;
  final String? errorMessage;

  WorkoutHistoryState copyWith({
    WorkoutHistoryStatus? status,
    List<WorkoutSessionRecord>? records,
    String? errorMessage,
  }) {
    return WorkoutHistoryState(
      status: status ?? this.status,
      records: records ?? this.records,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, records, errorMessage];
}

sealed class WorkoutHistoryEvent extends Equatable {
  const WorkoutHistoryEvent();

  @override
  List<Object?> get props => [];
}

class WorkoutHistoryRequested extends WorkoutHistoryEvent {
  const WorkoutHistoryRequested();
}

class WorkoutHistorySyncRequested extends WorkoutHistoryEvent {
  const WorkoutHistorySyncRequested();
}

class WorkoutHistoryBloc
    extends Bloc<WorkoutHistoryEvent, WorkoutHistoryState> {
  WorkoutHistoryBloc(this._repository) : super(const WorkoutHistoryState()) {
    on<WorkoutHistoryRequested>(_onRequested);
    on<WorkoutHistorySyncRequested>(_onSyncRequested);
  }

  final WorkoutRepository _repository;
  int _revision = 0;

  Future<void> _onRequested(
    WorkoutHistoryRequested event,
    Emitter<WorkoutHistoryState> emit,
  ) async {
    emit(state.copyWith(status: WorkoutHistoryStatus.loading));
    await _load(emit, WorkoutHistoryStatus.loaded, ++_revision);
  }

  Future<void> _onSyncRequested(
    WorkoutHistorySyncRequested event,
    Emitter<WorkoutHistoryState> emit,
  ) async {
    final revision = ++_revision;
    emit(state.copyWith(status: WorkoutHistoryStatus.syncing));
    try {
      await _repository.syncPending();
      if (revision != _revision || emit.isDone) return;
      await _load(emit, WorkoutHistoryStatus.loaded, revision);
    } on Object catch (error) {
      if (revision != _revision || emit.isDone) return;
      emit(state.copyWith(
        status: WorkoutHistoryStatus.failure,
        errorMessage: error.toString(),
      ));
    }
  }

  Future<void> _load(
    Emitter<WorkoutHistoryState> emit,
    WorkoutHistoryStatus status,
    int revision,
  ) async {
    try {
      final records = await _repository.loadHistory();
      if (revision != _revision || emit.isDone) return;
      emit(state.copyWith(
        status: status,
        records: records,
      ));
    } on Object catch (error) {
      if (revision != _revision || emit.isDone) return;
      emit(state.copyWith(
        status: WorkoutHistoryStatus.failure,
        errorMessage: error.toString(),
      ));
    }
  }

  @override
  Future<void> close() {
    _revision++;
    return super.close();
  }
}
