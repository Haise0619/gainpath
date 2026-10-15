import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

enum FitnessProfileStatus { loading, missing, ready, saving, loadFailure }

class FitnessProfileState {
  const FitnessProfileState(this.status, {this.profile, this.error});
  final FitnessProfileStatus status;
  final FitnessProfile? profile;
  final String? error;
}

class FitnessProfileCubit extends Cubit<FitnessProfileState> {
  FitnessProfileCubit(this.repository)
      : super(const FitnessProfileState(FitnessProfileStatus.loading));

  final FitnessProfileRepository repository;
  int _generation = 0;
  bool _reloadRequired = false;

  Future<void> load() async {
    if (isClosed || state.status == FitnessProfileStatus.saving) return;
    final generation = ++_generation;
    emit(const FitnessProfileState(FitnessProfileStatus.loading));
    try {
      final profile = await repository.load();
      if (isClosed || generation != _generation) return;
      _reloadRequired = false;
      emit(FitnessProfileState(
          profile == null
              ? FitnessProfileStatus.missing
              : FitnessProfileStatus.ready,
          profile: profile));
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(FitnessProfileState(FitnessProfileStatus.loadFailure,
          error: error is FitnessProfileException
              ? error.message
              : 'Could not load your profile. Check your connection and retry.'));
    }
  }

  Future<void> save(FitnessProfile profile) async {
    if (_reloadRequired) {
      throw const FitnessProfileException(
          'Reload your profile before saving this form.',
          reloadRequired: true);
    }
    if (isClosed ||
        !{FitnessProfileStatus.missing, FitnessProfileStatus.ready}
            .contains(state.status)) {
      throw const FitnessProfileException(
          'Please wait for the current request to finish.');
    }
    final previous = state;
    ++_generation;
    emit(FitnessProfileState(FitnessProfileStatus.saving,
        profile: previous.profile));
    try {
      await repository.save(profile);
      if (isClosed) return;
      FitnessProfile? confirmed;
      try {
        confirmed = await repository.load();
        if (confirmed == null) throw const FormatException();
      } catch (_) {
        throw const FitnessProfileException(
            'The save could not be verified. Reload before trying again; your answers are still here.',
            reloadRequired: true);
      }
      if (!isClosed) {
        emit(FitnessProfileState(FitnessProfileStatus.ready,
            profile: confirmed));
      }
    } catch (error) {
      _reloadRequired =
          error is FitnessProfileException && error.reloadRequired;
      if (!isClosed) emit(previous);
      throw error is FitnessProfileException
          ? error
          : const FitnessProfileException(
              'Could not save your profile. Your answers are still here; please retry.');
    }
  }
}
