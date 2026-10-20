import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/coaching.dart';

/// Keeps a single aggregate draft and its retry identity until readback/discard.
class CoachRosterEditor extends ChangeNotifier {
  CoachRosterEditor(
      {required this.repository,
      required this.coachId,
      required this.isCurrent,
      required this.onSaved});
  final CoachRosterRepository repository;
  final String coachId;
  final bool Function() isCurrent;
  final VoidCallback onSaved;
  CoachRosterSnapshot? baseline;
  List<CoachWeeklyDay> schedule = [];
  List<CoachTimeException> exceptions = [];
  int? dailyHours, advanceDays;
  bool loading = false, saving = false, conflict = false;
  String? message;
  String? _request, _intent;
  int _generation = 0;
  bool _disposed = false;
  bool get busy => loading || saving;
  bool get enabled =>
      !busy && !conflict && isCurrent() && baseline != null && _request == null;
  bool get uncertain => _request != null && !saving && !conflict;
  String get _draft => jsonEncode([
        dailyHours,
        advanceDays,
        schedule.map((e) => e.toJson()).toList(),
        exceptions.map((e) => e.toJson()).toList()
      ]);
  String? _original;
  bool get dirty => baseline != null && _draft != _original;
  bool _current(int generation) =>
      !_disposed && isCurrent() && generation == _generation;
  static String newId() => List.generate(16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
      .join();
  void _accept(CoachRosterSnapshot value) {
    baseline = value;
    dailyHours = value.weeklyAvailability?.dailyCapacityHours;
    advanceDays = value.weeklyAvailability?.advanceBookingWindowDays;
    schedule = [...?value.weeklyAvailability?.schedule];
    exceptions = [...value.exceptions];
    _original = _draft;
    _request = null;
    _intent = null;
    conflict = false;
  }

  Future<void> reload({bool discard = false}) async {
    if (_disposed || busy || !isCurrent() || (dirty && !discard)) return;
    final generation = ++_generation;
    loading = true;
    message = null;
    notifyListeners();
    try {
      final value = await repository.loadRoster(coachId: coachId);
      if (!_current(generation)) return;
      _accept(value);
    } catch (error) {
      if (!_current(generation)) return;
      message = _error(error);
    } finally {
      if (_current(generation)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void limits({int? hours, int? days}) {
    if (!enabled) return;
    dailyHours = hours ?? dailyHours;
    advanceDays = days ?? advanceDays;
    notifyListeners();
  }

  void day(CoachWeeklyDay value) {
    if (!enabled) return;
    schedule = [...schedule.where((d) => d.dayOfWeek != value.dayOfWeek), value]
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    notifyListeners();
  }

  void exception(CoachTimeException value) {
    if (!enabled) return;
    exceptions = [...exceptions.where((e) => e.id != value.id), value]
      ..sort((a, b) => a.startAtMillis.compareTo(b.startAtMillis));
    notifyListeners();
  }

  void remove(String id) {
    if (!enabled) return;
    exceptions = exceptions.where((e) => e.id != id).toList();
    notifyListeners();
  }

  Future<void> save() async {
    if (_disposed ||
        busy ||
        conflict ||
        !isCurrent() ||
        baseline == null ||
        !dirty) {
      return;
    }
    if (dailyHours == null || advanceDays == null || schedule.length != 7) {
      message =
          'Set all seven working days and both booking limits before saving.';
      notifyListeners();
      return;
    }
    final intent = _draft;
    if (_intent != intent) {
      _intent = intent;
      _request = newId();
    }
    final generation = ++_generation;
    saving = true;
    message = null;
    notifyListeners();
    try {
      final result = await repository.saveRoster(
          baseline: baseline!,
          weeklyAvailability: CoachWeeklyAvailability(
              dailyCapacityHours: dailyHours!,
              advanceBookingWindowDays: advanceDays!,
              schedule: schedule),
          exceptions: exceptions,
          requestId: _request!);
      if (!_current(generation)) return;
      _accept(result);
      message = 'Roster saved and refreshed.';
      onSaved();
    } catch (error) {
      if (!_current(generation)) return;
      conflict = error is CoachAvailabilityException &&
          [
            'aborted',
            'failed-precondition',
            'permission-denied',
            'unauthenticated'
          ].contains(error.code);
      message = _error(error);
    } finally {
      if (_current(generation)) {
        saving = false;
        notifyListeners();
      }
    }
  }

  String _error(Object error) => error is CoachAvailabilityException
      ? error.message
      : 'Could not load or save the roster. Reload or retry.';
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
