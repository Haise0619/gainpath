import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';

class CoachDirectoryState {
  const CoachDirectoryState(
      {this.items = const [],
      this.loading = true,
      this.loadingMore = false,
      this.nextCursor,
      this.message});
  final List<PublishedCoachProfile> items;
  final bool loading, loadingMore;
  final String? nextCursor, message;
}

class CoachDirectoryCubit extends Cubit<CoachDirectoryState> {
  CoachDirectoryCubit({required this.repository, required this.isCurrent})
      : super(const CoachDirectoryState());
  final CoachDirectoryRepository repository;
  final bool Function() isCurrent;
  int _generation = 0;
  bool _invalidated = false;
  bool get _allowed => !_invalidated && isCurrent();
  bool _current(int n) => !isClosed && _allowed && n == _generation;
  void invalidate() {
    if (isClosed) return;
    _invalidated = true;
    _generation++;
    emit(const CoachDirectoryState(
        loading: false,
        message: 'Coach directory unavailable for this session.'));
  }

  Future<void> refresh() async {
    if (isClosed) return;
    if (!_allowed) {
      invalidate();
      return;
    }
    final n = ++_generation;
    emit(const CoachDirectoryState());
    try {
      final page = await repository.loadPage();
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      emit(CoachDirectoryState(
          items: page.items, nextCursor: page.nextCursor, loading: false));
    } catch (e) {
      if (_current(n)) {
        if (e is CoachRepositoryException &&
            ['permission-denied', 'unauthenticated'].contains(e.code)) {
          invalidate();
        } else {
          emit(CoachDirectoryState(
              loading: false,
              message: e is CoachRepositoryException
                  ? e.message
                  : 'Could not load Coaches. Refresh to retry.'));
        }
      } else if (!_allowed) {
        invalidate();
      }
    }
  }

  Future<void> loadMore() async {
    if (isClosed ||
        state.loading ||
        state.loadingMore ||
        state.nextCursor == null) {
      return;
    }
    if (!_allowed) {
      invalidate();
      return;
    }
    final n = _generation, original = state;
    emit(CoachDirectoryState(
        items: original.items,
        nextCursor: original.nextCursor,
        loading: false,
        loadingMore: true));
    try {
      final page = await repository.loadPage(afterId: original.nextCursor);
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      final all = {
        for (final p in original.items) p.id: p,
        for (final p in page.items) p.id: p
      };
      emit(CoachDirectoryState(
          items: List.unmodifiable(all.values),
          nextCursor: page.nextCursor,
          loading: false));
    } catch (e) {
      if (_current(n)) {
        if (e is CoachRepositoryException &&
            ['permission-denied', 'unauthenticated'].contains(e.code)) {
          invalidate();
        } else {
          emit(CoachDirectoryState(
              items: original.items,
              nextCursor: original.nextCursor,
              loading: false,
              message: 'Could not load more Coaches. Retry.'));
        }
      } else if (!_allowed) {
        invalidate();
      }
    }
  }
}
