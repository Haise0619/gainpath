import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/local_member_progress_repository.dart';
import '../../workout/domain/routine_attempt.dart';

enum MemberProgressStatus { loading, ready, failure, inactive }

class MemberProgressState {
  const MemberProgressState(
      {required this.status,
      this.progress,
      this.snapshot,
      this.routines,
      this.error});
  final MemberProgressStatus status;
  final MemberLocalProgress? progress;
  final RoutineProgress? routines;
  final LocalMemberProgressSnapshot? snapshot;
  final String? error;
}

class MemberProgressCubit extends Cubit<MemberProgressState> {
  MemberProgressCubit(
      {required this.repository,
      required this.activeScope,
      DateTime Function()? clock})
      : clock = clock ?? DateTime.now,
        super(const MemberProgressState(status: MemberProgressStatus.loading));
  final LocalMemberProgressRepository repository;
  final SessionScope? Function() activeScope;
  final DateTime Function() clock;
  int _generation = 0;

  bool get _active => activeScope() == repository.scope;

  Future<void> load() async {
    if (isClosed) return;
    if (!_active) {
      accountChanged();
      return;
    }
    final generation = ++_generation;
    emit(const MemberProgressState(status: MemberProgressStatus.loading));
    try {
      final snapshot = await repository.load();
      if (isClosed || generation != _generation) return;
      if (!_active) {
        accountChanged();
        return;
      }
      final progress = calculateLocalMemberProgress(
          scope: repository.scope, records: snapshot.records, asOf: clock());
      emit(MemberProgressState(
          status: MemberProgressStatus.ready,
          progress: progress,
          routines: snapshot.routineHistoryAvailable
              ? RoutineProgress(
                  scope: repository.scope,
                  attempts: snapshot.attempts,
                  asOf: clock())
              : null,
          snapshot: snapshot));
    } catch (_) {
      if (isClosed || generation != _generation) return;
      if (!_active) {
        accountChanged();
        return;
      }
      emit(const MemberProgressState(
          status: MemberProgressStatus.failure,
          error: 'Could not read measured workouts saved on this device.'));
    }
  }

  void accountChanged() {
    if (isClosed || _active) return;
    ++_generation;
    emit(const MemberProgressState(status: MemberProgressStatus.inactive));
  }

  @override
  Future<void> close() {
    ++_generation;
    return super.close();
  }
}
