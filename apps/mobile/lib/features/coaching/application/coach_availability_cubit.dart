import 'dart:convert';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';

class CoachAvailabilityState {
  const CoachAvailabilityState(
      {this.context,
      this.day,
      this.windows = const [],
      this.loading = false,
      this.saving = false,
      this.conflict = false,
      this.message});
  final CoachAvailabilityContext? context;
  final CoachAvailabilityDay? day;
  final List<DatedCoachWindow> windows;
  final bool loading, saving, conflict;
  final String? message;
  bool get dirty =>
      jsonEncode(windows.map((w) => w.toJson()).toList()) !=
      jsonEncode(day?.windows.map((w) => w.toJson()).toList() ?? []);
}

class CoachAvailabilityCubit extends Cubit<CoachAvailabilityState> {
  CoachAvailabilityCubit(
      {required this.repository,
      required this.coachId,
      required this.isCurrent})
      : super(const CoachAvailabilityState());
  final CoachAvailabilityRepository repository;
  final String coachId;
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
    emit(const CoachAvailabilityState(
        message: 'Schedule unavailable for this session.'));
  }

  void _message(String message) => emit(CoachAvailabilityState(
      context: state.context,
      day: state.day,
      windows: state.windows,
      conflict: state.conflict,
      message: message));
  Future<void> loadWeek({String? firstLocalDate, bool discard = false}) async {
    if (isClosed || state.saving) return;
    if (!_allowed) {
      invalidate();
      return;
    }
    if (state.dirty && !discard) {
      _message('Save or discard changes before changing dates.');
      return;
    }
    final n = ++_generation;
    _intent = null;
    _request = null;
    emit(const CoachAvailabilityState(loading: true));
    try {
      final result = await repository.load(
          coachId: coachId, firstLocalDate: firstLocalDate);
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      final day =
          result.days.where((d) => d.editable).firstOrNull ?? result.days.first;
      emit(CoachAvailabilityState(
          context: result, day: day, windows: day.windows));
    } catch (e) {
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      emit(CoachAvailabilityState(message: _error(e)));
    }
  }

  void openDay(String date) {
    if (isClosed || state.loading || state.saving) return;
    if (!_allowed) {
      invalidate();
      return;
    }
    if (state.dirty || state.conflict) {
      _message('Save or discard changes before changing dates.');
      return;
    }
    final day =
        state.context?.days.where((d) => d.localDate == date).firstOrNull;
    if (day != null) {
      _intent = null;
      _request = null;
      emit(CoachAvailabilityState(
          context: state.context, day: day, windows: day.windows));
    }
  }

  void setWindows(List<DatedCoachWindow> windows) {
    if (isClosed ||
        state.saving ||
        state.conflict ||
        state.day?.editable != true) {
      return;
    }
    if (!_allowed) {
      invalidate();
      return;
    }
    final sorted = List<DatedCoachWindow>.of(windows)
      ..sort((a, b) => a.startAtMillis.compareTo(b.startAtMillis));
    if (sorted.length > 16 ||
        sorted.indexed.any((e) =>
            e.$1 > 0 && sorted[e.$1 - 1].endAtMillis > e.$2.startAtMillis)) {
      _message('Use at most 16 non-overlapping windows.');
      return;
    }
    emit(CoachAvailabilityState(
        context: state.context,
        day: state.day,
        windows: List.unmodifiable(sorted)));
  }

  Future<void> discardAndReload() => loadWeek(discard: true);
  Future<void> save() async {
    final original = state;
    if (isClosed ||
        original.loading ||
        original.saving ||
        original.conflict ||
        !original.dirty ||
        original.day?.editable != true ||
        original.context == null) {
      return;
    }
    if (!_allowed) {
      invalidate();
      return;
    }
    final intent = jsonEncode([
      original.day!.localDate,
      original.day!.revision,
      original.context!.policyVersion,
      original.context!.timeZone,
      original.context!.assignedBranchIds,
      original.windows.map((w) => w.toJson()).toList()
    ]);
    if (_intent != intent) {
      _intent = intent;
      _request =
          'availability_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
    }
    final n = ++_generation;
    emit(CoachAvailabilityState(
        context: original.context,
        day: original.day,
        windows: original.windows,
        saving: true));
    try {
      await repository.save(
          baseline: original.day!,
          context: original.context!,
          windows: original.windows,
          requestId: _request!);
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      final result = await repository.load(
          coachId: coachId,
          firstLocalDate: original.context!.days.first.localDate);
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      final day = result.days
          .where((d) => d.localDate == original.day!.localDate)
          .firstOrNull;
      _intent = null;
      _request = null;
      emit(CoachAvailabilityState(
          context: result,
          day: day,
          windows: day?.windows ?? [],
          message: 'Schedule saved and refreshed.'));
    } catch (e) {
      if (!_current(n)) {
        if (!_allowed) invalidate();
        return;
      }
      if (e is CoachAvailabilityException &&
          ['permission-denied', 'unauthenticated'].contains(e.code)) {
        invalidate();
        return;
      }
      emit(CoachAvailabilityState(
          context: original.context,
          day: original.day,
          windows: original.windows,
          conflict: e is CoachAvailabilityException && e.code == 'aborted',
          message: _error(e)));
    }
  }

  String _error(Object e) => e is CoachAvailabilityException
      ? e.message
      : 'Could not load or save the schedule. Refresh or retry.';
}
