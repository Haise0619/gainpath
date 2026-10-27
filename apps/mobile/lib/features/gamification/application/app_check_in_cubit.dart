import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/app_check_in.dart';

enum AppCheckInStatus { loading, ready, unavailable, error, inactive }

class AppCheckInState {
  const AppCheckInState(
      {required this.status,
      this.snapshot,
      this.claiming = false,
      this.message});
  final AppCheckInStatus status;
  final AppCheckInSnapshot? snapshot;
  final bool claiming;
  final String? message;
}

class AppCheckInCubit extends Cubit<AppCheckInState> {
  AppCheckInCubit({required this.repository, required this.activeScope})
      : super(const AppCheckInState(status: AppCheckInStatus.loading));
  final AppCheckInRepository repository;
  final SessionScope? Function() activeScope;
  int _generation = 0;
  bool _claiming = false;
  bool get current => activeScope() == repository.scope;
  Future<void> refresh() => _run(false);
  Future<void> claim() => _run(true);
  Future<void> _run(bool claim) async {
    if (isClosed || _claiming) return;
    if (!current) {
      invalidate();
      return;
    }
    if (claim && state.snapshot?.claimedToday == true) return;
    final generation = ++_generation;
    _claiming = claim;
    emit(AppCheckInState(
        status:
            state.snapshot == null ? AppCheckInStatus.loading : state.status,
        snapshot: state.snapshot,
        claiming: claim));
    try {
      final result =
          claim ? await repository.claim() : await repository.overview();
      if (isClosed || generation != _generation) return;
      if (!current) {
        invalidate();
        return;
      }
      if (result.snapshot.scope != repository.scope) {
        throw const FormatException('Check-in scope changed');
      }
      emit(AppCheckInState(
          status: AppCheckInStatus.ready,
          snapshot: result.snapshot,
          message: claim
              ? (result.awarded
                  ? '+${result.snapshot.pointsPerClaim} points · app check-in saved'
                  : 'Already claimed today')
              : null));
    } catch (e) {
      if (isClosed || generation != _generation) return;
      if (!current) {
        invalidate();
        return;
      }
      emit(AppCheckInState(
          status: e is AppCheckInUnavailable
              ? AppCheckInStatus.unavailable
              : AppCheckInStatus.error,
          snapshot: state.snapshot,
          message: e is AppCheckInUnavailable
              ? 'App check-in awaiting activation.'
              : 'Could not confirm check-in. Refresh or retry when connected.'));
    } finally {
      if (claim && generation == _generation) _claiming = false;
    }
  }

  void invalidate() {
    if (!isClosed && !current) {
      ++_generation;
      _claiming = false;
      emit(const AppCheckInState(status: AppCheckInStatus.inactive));
    }
  }

  @override
  Future<void> close() {
    ++_generation;
    return super.close();
  }
}
