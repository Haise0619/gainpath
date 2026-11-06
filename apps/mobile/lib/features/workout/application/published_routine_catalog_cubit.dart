import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../domain/published_routine_catalog_repository.dart';
import '../domain/published_routine_view.dart';

enum CatalogStatus { loading, ready, empty, error, unavailable }

class PublishedRoutineCatalogState {
  const PublishedRoutineCatalogState(
      {this.status = CatalogStatus.loading,
      this.items = const [],
      this.selected,
      this.nextCursor,
      this.loadingMore = false,
      this.message});
  final CatalogStatus status;
  final List<PublishedRoutine> items;
  final PublishedRoutine? selected;
  final String? nextCursor;
  final bool loadingMore;
  final String? message;
}

class PublishedRoutineCatalogCubit extends Cubit<PublishedRoutineCatalogState> {
  PublishedRoutineCatalogCubit(
      {required this.repository, required this.activeScope})
      : super(const PublishedRoutineCatalogState());
  final PublishedRoutineCatalogRepository repository;
  final SessionScope? Function() activeScope;
  String? _selectedId;
  int _generation = 0;
  bool _invalidated = false;
  bool get _authorized => !_invalidated && activeScope() == repository.scope;
  bool _current(int generation) =>
      !isClosed && _authorized && generation == _generation;

  void accountChanged() {
    if (isClosed || _authorized) return;
    invalidate();
  }

  /// Observed logout/role/scope events invalidate even if a later state has
  /// already restored the same identity before the stream callback runs.
  void invalidate() {
    if (isClosed) return;
    _invalidated = true;
    _generation++;
    _selectedId = null;
    emit(const PublishedRoutineCatalogState(
        status: CatalogStatus.unavailable,
        message: 'Published routines are unavailable for this session.'));
  }

  Future<void> refresh() async {
    if (isClosed) return;
    if (!_authorized) {
      accountChanged();
      return;
    }
    final generation = ++_generation;
    final selectedId = _selectedId;
    emit(const PublishedRoutineCatalogState());
    try {
      final page = await repository.loadPage();
      if (!_current(generation)) {
        accountChanged();
        return;
      }
      final discoveryItems = _preferSuccessors(page.items);
      PublishedRoutine? selected;
      if (selectedId == null) {
        selected = discoveryItems.isEmpty ? null : discoveryItems.first;
      } else {
        for (final item in discoveryItems) {
          if (item.id == selectedId) selected = item;
        }
        // A missing page entry is not evidence of withdrawal.
        selected ??= await repository.loadById(selectedId);
      }
      if (!_current(generation)) {
        accountChanged();
        return;
      }
      _selectedId = selected?.id;
      emit(PublishedRoutineCatalogState(
          status: discoveryItems.isEmpty && selected == null
              ? CatalogStatus.empty
              : CatalogStatus.ready,
          items: discoveryItems,
          selected: selected,
          nextCursor: page.nextCursor,
          message: selectedId != null && selected == null
              ? 'The selected routine is no longer available. Choose a published routine.'
              : null));
    } catch (_) {
      if (!_current(generation)) {
        accountChanged();
        return;
      }
      emit(const PublishedRoutineCatalogState(
          status: CatalogStatus.error,
          message: 'Could not load published routines. Please refresh.'));
    }
  }

  void select(String id) {
    if (!_authorized) {
      accountChanged();
      return;
    }
    if (isClosed || state.status != CatalogStatus.ready) return;
    PublishedRoutine? selected;
    for (final item in state.items) {
      if (item.id == id) selected = item;
    }
    if (selected == null) return;
    _selectedId = id;
    emit(PublishedRoutineCatalogState(
        status: CatalogStatus.ready,
        items: state.items,
        selected: selected,
        nextCursor: state.nextCursor,
        loadingMore: state.loadingMore));
  }

  Future<void> loadMore() async {
    if (isClosed) return;
    if (!_authorized) {
      accountChanged();
      return;
    }
    if (state.loadingMore ||
        state.status != CatalogStatus.ready ||
        state.nextCursor == null) {
      return;
    }
    final generation = _generation;
    final cursor = state.nextCursor!;
    emit(PublishedRoutineCatalogState(
        status: state.status,
        items: state.items,
        selected: state.selected,
        nextCursor: cursor,
        loadingMore: true));
    try {
      final page = await repository.loadPage(afterId: cursor);
      if (!_current(generation)) {
        accountChanged();
        return;
      }
      final items = _preferSuccessors([...state.items, ...page.items]);
      var selected = state.selected;
      if (selected != null) {
        for (final item in items) {
          if (item.sourceBlueprintId == selected!.sourceBlueprintId &&
              item.schemaVersion == 2) {
            selected = item;
            break;
          }
        }
      }
      _selectedId = selected?.id;
      emit(PublishedRoutineCatalogState(
          status: CatalogStatus.ready,
          items: items,
          selected: selected,
          nextCursor: page.nextCursor));
    } catch (_) {
      if (!_current(generation)) {
        accountChanged();
        return;
      }
      emit(PublishedRoutineCatalogState(
          status: CatalogStatus.ready,
          items: state.items,
          selected: state.selected,
          nextCursor: cursor,
          message: 'Could not load more routines. Please try again.'));
    }
  }
}

List<PublishedRoutine> _preferSuccessors(Iterable<PublishedRoutine> input) {
  final byId = {for (final item in input) item.id: item};
  final successors = <String, PublishedRoutine>{};
  for (final item in byId.values) {
    if (item.schemaVersion != 2) continue;
    final previous = successors[item.sourceBlueprintId];
    if (previous == null || item.id.compareTo(previous.id) < 0) {
      successors[item.sourceBlueprintId] = item;
    }
  }
  final emitted = <String>{};
  return List.unmodifiable(byId.values
      .map((item) => successors[item.sourceBlueprintId] ?? item)
      .where((item) => emitted.add(item.id)));
}
