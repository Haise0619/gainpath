import 'dart:convert';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';

enum CoachProfileStatus { loading, ready, unavailable, error }

class CoachProfileState {
  const CoachProfileState(
      {this.status = CoachProfileStatus.loading,
      this.profile,
      this.publication,
      this.saving = false,
      this.conflict = false,
      this.message});
  final CoachProfileStatus status;
  final CoachProfessionalProfile? profile;
  final PublishedCoachProfile? publication;
  final bool saving, conflict;
  final String? message;
}

class CoachProfileCubit extends Cubit<CoachProfileState> {
  CoachProfileCubit({required this.repository, required this.isCurrent})
      : super(const CoachProfileState());
  final CoachProfileRepository repository;
  final bool Function() isCurrent;
  int _generation = 0;
  bool _invalidated = false;
  String? _intent, _request;
  bool get _allowed => !_invalidated && isCurrent();
  bool _current(int n) => !isClosed && _allowed && n == _generation;
  void invalidate() {
    if (isClosed) return;
    _invalidated = true;
    _generation++;
    emit(const CoachProfileState(
        status: CoachProfileStatus.unavailable,
        message: 'Coach profile unavailable for this session.'));
  }

  Future<void> reload() async {
    if (isClosed) return;
    if (!_allowed) {
      invalidate();
      return;
    }
    if (state.saving) return;
    final n = ++_generation;
    _intent = null;
    _request = null;
    emit(const CoachProfileState());
    try {
      final profile = await repository.loadOwn(),
          publication = await repository.loadOwnPublication();
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      emit(CoachProfileState(
          status: CoachProfileStatus.ready,
          profile: profile,
          publication: publication));
    } catch (e) {
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      if (e is CoachRepositoryException &&
          ['permission-denied', 'unauthenticated'].contains(e.code)) {
        invalidate();
        return;
      }
      emit(CoachProfileState(
          status: CoachProfileStatus.error, message: _message(e)));
    }
  }

  Future<void> save(CoachProfessionalFields fields) async {
    if (isClosed ||
        state.saving ||
        state.conflict ||
        state.status != CoachProfileStatus.ready) {
      return;
    }
    if (!_allowed) {
      invalidate();
      return;
    }
    final original = state, expected = original.profile?.revision ?? 0;
    final patch = CoachProfilePatch.between(original.profile?.fields, fields);
    if (patch.isEmpty) return;
    final intent = jsonEncode([expected, patch.toJson()]);
    if (_intent != intent) {
      _intent = intent;
      _request =
          'coach_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
    }
    final n = ++_generation;
    emit(CoachProfileState(
        status: original.status,
        profile: original.profile,
        publication: original.publication,
        saving: true));
    try {
      await repository.save(
          expectedRevision: expected, patch: patch, requestId: _request!);
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      final fresh = await repository.loadOwn(),
          published = await repository.loadOwnPublication();
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      _intent = null;
      _request = null;
      emit(CoachProfileState(
          status: CoachProfileStatus.ready,
          profile: fresh,
          publication: published,
          message: 'Profile saved. Admin publication is required.'));
    } catch (e) {
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      if (e is CoachRepositoryException &&
          ['permission-denied', 'unauthenticated'].contains(e.code)) {
        invalidate();
        return;
      }
      emit(CoachProfileState(
          status: CoachProfileStatus.ready,
          profile: original.profile,
          publication: original.publication,
          conflict: e is CoachRepositoryException && e.code == 'aborted',
          message: _message(e)));
    }
  }

  String _message(Object e) => e is CoachRepositoryException
      ? e.message
      : 'Could not load or save the Coach profile. Refresh or retry.';
}
