import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';

class CoachDirectoryAdminState {
  const CoachDirectoryAdminState(
      {this.loading = true,
      this.busy = false,
      this.allowed = false,
      this.conflict = false,
      this.drafts = const [],
      this.publicProfiles = const [],
      this.draftCursor,
      this.publicCursor,
      this.review,
      this.message});
  final bool loading, busy, allowed, conflict;
  final List<CoachProfessionalProfile> drafts;
  final List<PublishedCoachProfile> publicProfiles;
  final String? draftCursor, publicCursor, message;
  final CoachPublicationReview? review;
}

class CoachDirectoryAdminCubit extends Cubit<CoachDirectoryAdminState> {
  CoachDirectoryAdminCubit(this.repository)
      : super(const CoachDirectoryAdminState());
  final CoachProfileAdminRepository repository;
  int _generation = 0;
  String? _intent, _request;
  bool _current(int n) => !isClosed && n == _generation;
  Future<void> refresh() async {
    if (isClosed || state.busy) return;
    final n = ++_generation;
    _intent = null;
    _request = null;
    emit(const CoachDirectoryAdminState());
    try {
      if (!await repository.canManageDirectory()) {
        if (_current(n)) {
          emit(const CoachDirectoryAdminState(
              loading: false,
              message: 'Canonical organization Admin access is required.'));
        }
        return;
      }
      final drafts = await repository.loadDraftPage(),
          publicProfiles = await repository.loadPublicPage();
      if (_current(n)) {
        emit(CoachDirectoryAdminState(
            loading: false,
            allowed: true,
            drafts: drafts.items,
            publicProfiles: publicProfiles.items,
            draftCursor: drafts.nextCursor,
            publicCursor: publicProfiles.nextCursor));
      }
    } catch (e) {
      if (_current(n)) {
        emit(CoachDirectoryAdminState(loading: false, message: _message(e)));
      }
    }
  }

  CoachDirectoryAdminState _copy(CoachDirectoryAdminState s,
          {bool busy = false,
          bool conflict = false,
          CoachPublicationReview? review,
          String? message,
          List<CoachProfessionalProfile>? drafts,
          List<PublishedCoachProfile>? publicProfiles,
          String? draftCursor,
          String? publicCursor,
          bool page = false}) =>
      CoachDirectoryAdminState(
          loading: false,
          allowed: s.allowed,
          busy: busy,
          conflict: conflict,
          review: review ?? s.review,
          drafts: drafts ?? s.drafts,
          publicProfiles: publicProfiles ?? s.publicProfiles,
          draftCursor: page ? draftCursor : s.draftCursor,
          publicCursor: page ? publicCursor : s.publicCursor,
          message: message);
  Future<void> review(String id) async {
    if (isClosed || state.busy || !state.allowed) return;
    final n = ++_generation, original = state;
    emit(CoachDirectoryAdminState(
        loading: false,
        allowed: true,
        busy: true,
        drafts: original.drafts,
        publicProfiles: original.publicProfiles,
        draftCursor: original.draftCursor,
        publicCursor: original.publicCursor));
    try {
      final value = await repository.loadReview(id);
      if (_current(n)) {
        _intent = null;
        _request = null;
        emit(_copy(original, review: value));
      }
    } catch (e) {
      if (_current(n)) {
        if (_revoked(e)) {
          emit(CoachDirectoryAdminState(loading: false, message: _message(e)));
        } else {
          emit(CoachDirectoryAdminState(
              loading: false,
              allowed: true,
              drafts: original.drafts,
              publicProfiles: original.publicProfiles,
              draftCursor: original.draftCursor,
              publicCursor: original.publicCursor,
              message: _message(e)));
        }
      }
    }
  }

  Future<void> loadMore({required bool publicPage}) async {
    if (isClosed || state.busy || state.loading || !state.allowed) return;
    final original = state,
        cursor = publicPage ? state.publicCursor : state.draftCursor;
    if (cursor == null) return;
    final n = _generation;
    emit(_copy(original, busy: true, conflict: original.conflict));
    try {
      if (publicPage) {
        final page = await repository.loadPublicPage(afterId: cursor);
        if (_current(n)) {
          emit(_copy(original,
              conflict: original.conflict,
              publicProfiles: List.unmodifiable({
                for (final p in original.publicProfiles) p.id: p,
                for (final p in page.items) p.id: p
              }.values),
              page: true,
              publicCursor: page.nextCursor,
              draftCursor: original.draftCursor));
        }
      } else {
        final page = await repository.loadDraftPage(afterId: cursor);
        if (_current(n)) {
          emit(_copy(original,
              conflict: original.conflict,
              drafts: List.unmodifiable({
                for (final p in original.drafts) p.id: p,
                for (final p in page.items) p.id: p
              }.values),
              page: true,
              draftCursor: page.nextCursor,
              publicCursor: original.publicCursor));
        }
      }
    } catch (e) {
      if (_current(n)) {
        if (_revoked(e)) {
          emit(CoachDirectoryAdminState(loading: false, message: _message(e)));
        } else {
          emit(_copy(original,
              conflict: original.conflict, message: _message(e)));
        }
      }
    }
  }

  Future<void> setStatus(CoachDirectoryAction action) async {
    if (isClosed ||
        state.busy ||
        state.conflict ||
        !state.allowed ||
        state.review == null) {
      return;
    }
    final baseline = state.review!, original = state;
    if (action == CoachDirectoryAction.publish && !baseline.canPublish) return;
    if (action == CoachDirectoryAction.deactivate &&
        baseline.publication == null) {
      return;
    }
    final intent = jsonEncode([
      baseline.coachId,
      action.name,
      baseline.publicRevision,
      baseline.draft?.revision,
      baseline.branchIds
    ]);
    if (_intent != intent) {
      _intent = intent;
      _request =
          'directory_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
    }
    final n = ++_generation;
    emit(_copy(original, busy: true));
    try {
      await repository.setStatus(
          baseline: baseline, action: action, requestId: _request!);
      if (!_current(n)) return;
      final fresh = await repository.loadReview(baseline.coachId),
          drafts = await repository.loadDraftPage(),
          publicProfiles = await repository.loadPublicPage();
      if (_current(n)) {
        _intent = null;
        _request = null;
        emit(CoachDirectoryAdminState(
            loading: false,
            allowed: true,
            drafts: drafts.items,
            publicProfiles: publicProfiles.items,
            draftCursor: drafts.nextCursor,
            publicCursor: publicProfiles.nextCursor,
            review: fresh,
            message: action == CoachDirectoryAction.publish
                ? 'Coach profile published.'
                : 'Coach directory profile deactivated. Account identity is unchanged.'));
      }
    } catch (e) {
      if (_current(n)) {
        if (_revoked(e)) {
          emit(CoachDirectoryAdminState(loading: false, message: _message(e)));
        } else {
          emit(_copy(original,
              conflict: e is CoachRepositoryException && e.code == 'aborted',
              message: _message(e)));
        }
      }
    }
  }

  bool _revoked(Object e) =>
      e is CoachRepositoryException &&
      ['permission-denied', 'unauthenticated'].contains(e.code);
  String _message(Object e) {
    if (e is CoachRepositoryException) return e.message;
    if (e is FormatException) {
      return 'This Admin build cannot read the Coach record format. Open the main Admin at http://localhost:7359/ and reload. No records were changed.';
    }
    if (e is TimeoutException) {
      return 'Coach loading timed out. Check your connection and retry.';
    }
    return 'Could not load or update Coach profiles. Refresh or retry.';
  }
}
