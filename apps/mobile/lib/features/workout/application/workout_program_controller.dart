import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import '../domain/program_enrollment.dart';
import '../domain/published_routine_view.dart';
import '../domain/routine_journey.dart';
import '../domain/routine_attempt.dart';

class WorkoutProgramController extends ChangeNotifier {
  WorkoutProgramController(
      {required this.scope,
      required this.activeScope,
      required this.store,
      required this.routineStore,
      required this.newId}) {
    if (store.scope != scope || routineStore.scope != scope) {
      throw ArgumentError('Program account mismatch');
    }
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final ProgramEnrollmentStore store;
  final RoutineJourneyStore routineStore;
  final String Function() newId;
  ProgramJournal? _journal;
  List<RoutineCheckpoint> _checkpoints = [];
  bool _disposed = false, busy = false;
  String? error;
  Future<void> _tail = Future.value();
  bool get authorized => !_disposed && activeScope() == scope;
  ProgramJournal? get journal => authorized ? _journal : null;
  ProgramEnrollment? get enrollment => journal?.active;
  void _guard() {
    if (!authorized) throw StateError('Program account changed');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _tail.then((_) async {
      _guard();
      busy = true;
      error = null;
      _notify();
      try {
        return await action();
      } catch (_) {
        if (authorized) {
          error =
              'Program progress could not be loaded or saved. Retry before continuing.';
        }
        rethrow;
      } finally {
        busy = false;
        _notify();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> open() => _run(() async {
        final journal = await store.load();
        final checkpoints = await routineStore.load();
        _guard();
        _journal = journal;
        _checkpoints = checkpoints.where((c) => c.scope == scope).toList();
      });
  Future<void> _save(List<ProgramEnrollment> records, String activeId) async {
    _guard();
    final previous =
        _journal ?? (throw StateError('Open program progress first'));
    final next = ProgramJournal(
        revision: previous.revision + 1,
        activeId: activeId,
        enrollments: List.unmodifiable(records));
    await store.save(next, expectedRevision: previous.revision);
    _guard();
    _journal = next;
  }

  Future<void> enroll(
          WorkoutProgram program, DateTime start, Set<int> weekdays) =>
      _run(() async {
        program.validate(published: true);
        final frozen = WorkoutProgram.fromJson(Map<String, dynamic>.from(
            jsonDecode(jsonEncode(program.toJson())) as Map));
        final next = ProgramEnrollment(
            id: newId(),
            program: frozen,
            schedule: ProgramSchedule.create(frozen, start, weekdays));
        final all = _journal?.enrollments ??
            (throw StateError('Open program progress first'));
        if (all.length >= 100) {
          throw StateError('Program history limit reached');
        }
        await _save([...all, next], next.id);
      });
  Future<void> selectEnrollment(String id) => _run(() async {
        final all = _journal?.enrollments ??
            (throw StateError('Program progress unavailable'));
        if (!all.any((e) => e.id == id)) {
          throw ArgumentError('Unknown enrollment');
        }
        await _save(all, id);
      });
  ScheduledProgramDay _day(String key) =>
      enrollment?.schedule.singleWhere((d) => d.key == key) ??
      (throw StateError('Program unavailable'));
  RoutineAttempt? attempt(String key) {
    final e = enrollment;
    if (e == null) return null;
    final id = e.progress[key]?.attemptId;
    final scheduled = _day(key);
    final found = _checkpoints.where((c) =>
        c.scope == scope &&
        c.id == id &&
        c.routineId == scheduled.definition.routineId &&
        c.day == scheduled.definition.routineDay);
    if (found.length != 1) return null;
    final definition = scheduled.definition;
    final expected = PublishedRoutine.fromDocument(definition.routineId!,
        Map<String, dynamic>.from(definition.routineSnapshot!));
    final signature = jsonEncode([
      expected.id,
      expected.sourceBlueprintId,
      for (final e in expected.exercises)
        [
          e.exerciseId,
          e.dayNumber,
          e.sets,
          e.reps,
          if (e.restSeconds != 60) e.restSeconds
        ]
    ]);
    if (found.single.planSignature != signature) return null;
    final a = found.single.attempt;
    if (a == null || a.scope != scope || a.id != id) return null;
    if (canonicalProgramJson(routinePlanSnapshot(expected)) !=
        canonicalProgramJson(routinePlanSnapshot(a.routine))) {
      return null;
    }
    return a;
  }

  bool isComplete(String key) => attempt(key)?.isComplete == true;
  String status(String key, DateTime today) {
    final d = _day(key);
    if (d.definition.kind != 'workout') {
      return d.definition.kind == 'rest' ? 'Rest day' : 'Active recovery';
    }
    if (isComplete(key)) return 'Completed';
    if (enrollment!.progress[key]?.skipped == true) return 'Skipped';
    final a = attempt(key);
    if (a != null) return a.statusLabel;
    if (enrollment!.progress[key]?.attemptId != null) return 'In progress';
    final date = DateTime.utc(today.year, today.month, today.day);
    return d.date.isBefore(date) ? 'Missed · not completed' : 'Scheduled';
  }

  int completedDays(int week) =>
      enrollment?.schedule
          .where((d) =>
              d.definition.week == week &&
              d.definition.kind == 'workout' &&
              isComplete(d.key))
          .length ??
      0;
  ScheduledProgramDay? nextWorkout({String? afterKey}) {
    final all = enrollment?.schedule.toList() ?? [];
    all.sort((a, b) => a.date.compareTo(b.date));
    final after = afterKey == null ? null : _day(afterKey).date;
    return all
        .where((d) =>
            d.definition.kind == 'workout' &&
            !isComplete(d.key) &&
            enrollment!.progress[d.key]?.skipped != true &&
            (after == null || d.date.isAfter(after)))
        .firstOrNull;
  }

  Future<void> _replace(ProgramEnrollment next) => _save([
        for (final e in _journal!.enrollments)
          if (e.id == next.id) next else e
      ], next.id);
  Future<ProgramRoutineLaunch> begin(String key) => _run(() async {
        final e = enrollment ?? (throw StateError('Program unavailable'));
        final day = _day(key).definition;
        if (day.kind != 'workout' ||
            day.routineId == null ||
            day.routineSnapshot == null) {
          throw StateError('This day has no published workout');
        }
        final routine = PublishedRoutine.fromDocument(
            day.routineId!, Map<String, dynamic>.from(day.routineSnapshot!));
        final current = e.progress[key];
        final id = current?.attemptId ?? newId();
        await _replace(e.copyWith(
            progress: {...e.progress, key: ProgramDayProgress(attemptId: id)}));
        return ProgramRoutineLaunch(
            routine: routine, routineDay: day.routineDay, attemptId: id);
      });
  Future<void> skip(String key) => _run(() async {
        final e = enrollment ?? (throw StateError('Program unavailable'));
        if (_day(key).definition.kind != 'workout' || isComplete(key)) {
          throw StateError('Completed/recovery days cannot be skipped');
        }
        await _replace(e.copyWith(progress: {
          ...e.progress,
          key: ProgramDayProgress(
              attemptId: e.progress[key]?.attemptId, skipped: true)
        }));
      });
  Future<void> reschedule(String key, DateTime date) => _run(() async {
        final e = enrollment ?? (throw StateError('Program unavailable'));
        if (_day(key).definition.kind != 'workout' || isComplete(key)) {
          throw StateError('Only unfinished workouts can move');
        }
        final entries = ProgramSchedule.reschedule(e.schedule, key, date);
        await _replace(e.copyWith(schedule: entries));
      });
  void accountChanged() {
    if (!authorized) {
      _journal = null;
      _checkpoints = [];
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _journal = null;
    _checkpoints = [];
    super.dispose();
  }
}
