import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart' show ExerciseTrackingCapability;
import '../domain/exercise_tracker_dispatcher.dart';
import '../domain/published_routine_view.dart';
import '../domain/routine_journey.dart';
import '../domain/routine_attempt.dart';
import '../domain/workout_contracts.dart';

class RoutineJourneyController extends ChangeNotifier {
  RoutineJourneyController(
      {required this.scope,
      required this.activeScope,
      required this.routine,
      required this.store,
      required this.workouts,
      this.trackers = const ExerciseTrackerDispatcher(),
      required this.newId}) {
    if (store.scope != scope || workouts.scope != scope) {
      throw ArgumentError('Routine account mismatch');
    }
  }
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final PublishedRoutine routine;
  final RoutineJourneyStore store;
  final WorkoutRepository workouts;
  final ExerciseTrackerDispatcher trackers;
  final String Function() newId;
  RoutineCheckpoint? _checkpoint;
  List<WorkoutSessionSummary> _history = [];
  bool _disposed = false;
  bool busy = false;
  String? error;
  int day = 1;
  Future<void> _tail = Future.value();
  bool get authorized => !_disposed && activeScope() == scope;
  RoutineCheckpoint? get checkpoint => authorized ? _checkpoint : null;
  List<int> get days =>
      (routine.exercises.map((e) => e.dayNumber).toSet().toList()..sort());
  List<int> get dayIndices => [
        for (var i = 0; i < routine.exercises.length; i++)
          if (routine.exercises[i].dayNumber == day) i
      ];
  int get selectedIndex => checkpoint?.selectedIndex ?? dayIndices.first;
  String get _signature => jsonEncode([
        routine.id,
        routine.sourceBlueprintId,
        for (final e in routine.exercises)
          [e.exerciseId, e.dayNumber, e.sets, e.reps]
      ]);

  void _guard() {
    if (!authorized) throw StateError('Routine account is no longer active');
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
              'Routine progress could not be saved. Retry before continuing.';
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

  Future<void> _save(RoutineCheckpoint next) async {
    _guard();
    next = next.copyWith(attempt: _snapshot(next));
    if (store case final RevisionedRoutineJourneyStore revisioned) {
      await revisioned.saveRevision(next,
          expectedUpdatedAtMicros:
              _checkpoint?.id == next.id ? _checkpoint!.updatedAtMicros : null);
    } else {
      await store.save(next);
    }
    _guard();
    _checkpoint = next;
  }

  Future<void> openDay(int selectedDay) => _run(() => _openDay(selectedDay));
  Future<void> openLatest() => _run(() async {
        final checkpoints = (await store.load())
            .where((e) =>
                e.scope == scope &&
                e.routineId == routine.id &&
                e.planSignature == _signature &&
                days.contains(e.day))
            .toList()
          ..sort((a, b) => b.updatedAtMicros.compareTo(a.updatedAtMicros));
        _guard();
        await _openDay(
            checkpoints.isEmpty ? days.first : checkpoints.first.day);
      });
  Future<void> _openDay(int selectedDay) async {
    if (!days.contains(selectedDay)) throw ArgumentError('Unknown routine day');
    day = selectedDay;
    _checkpoint = null;
    _history = [];
    final existing = (await store.load())
        .where((e) =>
            e.scope == scope &&
            e.routineId == routine.id &&
            e.day == day &&
            e.planSignature == _signature)
        .toList()
      ..sort((a, b) => b.updatedAtMicros.compareTo(a.updatedAtMicros));
    _guard();
    if (existing.isEmpty) {
      await _newAttempt();
    } else {
      _checkpoint = existing.first;
    }
    await _reload();
    await _save(_checkpoint!.copyWith());
  }

  Future<void> _newAttempt() => _save(RoutineCheckpoint(
      id: newId(),
      scope: scope,
      routineId: routine.id,
      planSignature: _signature,
      day: day,
      selectedIndex: dayIndices.first,
      startedAtMicros: DateTime.now().toUtc().microsecondsSinceEpoch,
      updatedAtMicros: DateTime.now().toUtc().microsecondsSinceEpoch));
  Future<void> startNewAttempt() => _run(() async {
        await _newAttempt();
        await _reload();
      });
  Future<void> refresh({bool completeRoutine = false}) => _run(() async {
        await _reload();
        if (completeRoutine && allTargetsCompleted && !_checkpoint!.finished) {
          await _save(_checkpoint!.copyWith(finished: true));
        }
      });

  Future<void> _reload() async {
    final records = await workouts.loadHistory();
    _guard();
    _history = records
        .map((e) => e.summary)
        .where((s) =>
            s.scope == scope &&
            s.provenance == WorkoutProvenance.realCamera &&
            s.poseMetrics != null)
        .toList();
    final current = _checkpoint!;
    final sessions = {...current.sessions};
    final pending = {...current.pending};
    var changed = false;
    for (final e in current.pending.entries) {
      if (!dayIndices.contains(e.key)) {
        throw StateError('Checkpoint day mismatch');
      }
      final matches = _history.where((s) =>
          s.sessionId == e.value &&
          s.exerciseId == routine.exercises[e.key].exerciseId &&
          s.poseMetrics!.publishedRoutineId == routine.id);
      if (matches.isEmpty) continue;
      if (sessions.entries
          .any((row) => row.key != e.key && row.value.contains(e.value))) {
        throw StateError('Capture already belongs to another routine entry');
      }
      sessions[e.key] = {...?sessions[e.key], e.value}.toList();
      pending.remove(e.key);
      changed = true;
    }
    if (changed) {
      await _save(current.copyWith(sessions: sessions, pending: pending));
      await _advance();
    }
  }

  ExerciseTrackerResolution trackingFor(int index) => trackers.resolve(
      organizationId: scope.organizationId,
      exerciseId: routine.exercises[index].exerciseId);
  ExerciseTrackingCapability capabilityFor(int index) =>
      trackingFor(index).capability;
  bool supportsTracking(int index) => capabilityFor(index).hasPoseTracking;
  bool perArmTargetsFor(int index) =>
      trackingFor(index).tracker == ExerciseTracker.sideViewCurl;
  String targetsFor(int index) {
    final e = routine.exercises[index];
    return '${e.sets} sets · ${e.reps} reps${perArmTargetsFor(index) ? ' per arm' : ''} per set';
  }

  int manualSetsFor(int index) => authorized && dayIndices.contains(index)
      ? (checkpoint?.manualSets[index] ?? 0)
          .clamp(0, routine.exercises[index].sets)
      : 0;
  int get selfReportedSets =>
      dayIndices.fold(0, (sum, index) => sum + manualSetsFor(index));
  List<WorkoutSessionSummary> sessionsFor(int index) =>
      _sessionsFor(index, checkpoint);
  List<WorkoutSessionSummary> _sessionsFor(
      int index, RoutineCheckpoint? value) {
    if (!authorized || !dayIndices.contains(index)) return const [];
    final ids = value?.sessions[index] ?? const <String>[];
    return _history
        .where((s) =>
            ids.contains(s.sessionId) &&
            s.exerciseId == routine.exercises[index].exerciseId &&
            s.poseMetrics?.publishedRoutineId == routine.id)
        .toList();
  }

  List<WorkoutSessionSummary> get measuredSessions {
    if (!authorized) return const [];
    return {
      for (final i in dayIndices)
        for (final s in sessionsFor(i)) s.sessionId: s
    }.values.toList();
  }

  int get fullRepetitions =>
      measuredSessions.fold(0, (sum, s) => sum + s.repetitions);
  int get partialRepetitions => measuredSessions.fold(
      0, (sum, s) => sum + (s.poseMetrics?.partialRepetitions ?? 0));
  int get trackedDurationMicros =>
      measuredSessions.fold(0, (sum, s) => sum + s.trackedDurationMicros);
  int get completedExercises => !authorized
      ? 0
      : dayIndices
          .where((index) => {
                RoutineExerciseStatus.completed,
                RoutineExerciseStatus.selfReportedCompleted
              }.contains(statusFor(index)))
          .length;
  bool get allTargetsCompleted =>
      authorized &&
      dayIndices.isNotEmpty &&
      completedExercises == dayIndices.length;
  RoutineExerciseStatus statusFor(int index) => _statusFor(index, checkpoint);
  RoutineExerciseStatus _statusFor(int index, RoutineCheckpoint? value) {
    final sessions = _sessionsFor(index, value), e = routine.exercises[index];
    final manualSets = (value?.manualSets[index] ?? 0).clamp(0, e.sets);
    if (sessions.any((s) =>
        s.poseMetrics?.curlArms?.completes(e.sets, e.reps) ??
        (s.repetitions >= e.sets * e.reps))) {
      return RoutineExerciseStatus.completed;
    }
    if (value?.skipped.contains(index) == true) {
      return RoutineExerciseStatus.skipped;
    }
    if (manualSets > 0) {
      return manualSets >= e.sets
          ? RoutineExerciseStatus.selfReportedCompleted
          : RoutineExerciseStatus.selfReportedPartial;
    }
    if (value?.reviewed.contains(index) == true && !supportsTracking(index)) {
      return RoutineExerciseStatus.instructionsReviewed;
    }
    return sessions.isEmpty
        ? RoutineExerciseStatus.notStarted
        : RoutineExerciseStatus.partial;
  }

  bool _handled(int index) => {
        RoutineExerciseStatus.completed,
        RoutineExerciseStatus.selfReportedCompleted,
        RoutineExerciseStatus.skipped
      }.contains(statusFor(index));
  List<int> get unfinishedIndices =>
      dayIndices.where((i) => !_handled(i)).toList();
  Future<void> select(int index) => _run(() async {
        if (!dayIndices.contains(index)) {
          throw ArgumentError('Exercise not in selected day');
        }
        await _save(
            _checkpoint!.copyWith(selectedIndex: index, finished: false));
      });
  Future<void> _advance() async {
    final remaining = unfinishedIndices;
    if (remaining.isNotEmpty) {
      await _save(_checkpoint!.copyWith(selectedIndex: remaining.first));
    }
  }

  Future<String> prepareCapture(int index) => _run(() async {
        if (!dayIndices.contains(index) || !supportsTracking(index)) {
          throw StateError('Exercise is instructional only');
        }
        await _reload();
        final id = newId();
        await _save(_checkpoint!.copyWith(
            selectedIndex: index,
            finished: false,
            pending: {..._checkpoint!.pending, index: id},
            skipped: {..._checkpoint!.skipped}..remove(index)));
        return id;
      });
  Future<void> reviewInstructions(int index) => _run(() async {
        if (!dayIndices.contains(index) || supportsTracking(index)) {
          throw StateError('Not an instructional exercise');
        }
        await _save(_checkpoint!.copyWith(
            reviewed: {..._checkpoint!.reviewed, index},
            skipped: {..._checkpoint!.skipped}..remove(index)));
        await _advance();
      });
  Future<void> skip(int index) => _run(() async {
        if (!dayIndices.contains(index)) {
          throw ArgumentError('Exercise not in selected day');
        }
        await _save(
            _checkpoint!.copyWith(skipped: {..._checkpoint!.skipped, index}));
        await _advance();
      });
  Future<void> markManualSet(int index) => _run(() async {
        if (!dayIndices.contains(index) || supportsTracking(index)) {
          throw StateError('Exercise is not manual');
        }
        final sets = manualSetsFor(index);
        if (sets >= routine.exercises[index].sets) return;
        await _save(_checkpoint!.copyWith(
            finished: false,
            manualSets: {..._checkpoint!.manualSets, index: sets + 1},
            skipped: {..._checkpoint!.skipped}..remove(index)));
        if (sets + 1 == routine.exercises[index].sets) await _advance();
      });
  Future<void> undoManualSet(int index) => _run(() async {
        if (!dayIndices.contains(index) || supportsTracking(index)) {
          throw StateError('Exercise is not manual');
        }
        final sets = manualSetsFor(index);
        if (sets == 0) return;
        await _save(_checkpoint!.copyWith(
            finished: false,
            selectedIndex: index,
            manualSets: {..._checkpoint!.manualSets, index: sets - 1},
            skipped: {..._checkpoint!.skipped}..remove(index)));
      });
  Future<void> finish() => _run(() async {
        await _reload();
        await _save(_checkpoint!.copyWith(finished: true));
      });
  Future<void> resume() => _run(() async {
        if (allTargetsCompleted && _checkpoint!.finished) return;
        await _save(_checkpoint!.copyWith(finished: false, skipped: {}));
        await _advance();
      });
  RoutineAttempt _snapshot(RoutineCheckpoint value) => RoutineAttempt(
          id: value.id,
          scope: scope,
          routine: value.attempt?.routine ?? routine,
          day: value.day,
          finished: value.finished,
          startedAtMicros: value.startedAtMicros,
          finishedAtMicros: !value.finished || value.startedAtMicros == null
              ? null
              : value.attempt?.finishedAtMicros ?? value.updatedAtMicros,
          updatedAtMicros: value.updatedAtMicros,
          entries: [
            for (final i in dayIndices)
              RoutineExerciseResult(
                  index: i,
                  status: _statusFor(i, value),
                  sessionIds: List.unmodifiable(
                      _sessionsFor(i, value).map((s) => s.sessionId)),
                  fullRepetitions: _sessionsFor(i, value)
                      .fold(0, (n, s) => n + s.repetitions),
                  partialRepetitions: _sessionsFor(i, value).fold(0,
                      (n, s) => n + (s.poseMetrics?.partialRepetitions ?? 0)),
                  trackedDurationMicros: _sessionsFor(i, value)
                      .fold(0, (n, s) => n + s.trackedDurationMicros),
                  manualSets: (value.manualSets[i] ?? 0)
                      .clamp(0, routine.exercises[i].sets))
          ]);

  Future<void> openAttempt(String id) => _run(() async {
        final matches = (await store.load()).where((v) =>
            v.id == id &&
            v.scope == scope &&
            v.routineId == routine.id &&
            v.planSignature == _signature);
        _guard();
        if (matches.length != 1) throw StateError('Saved attempt unavailable');
        _checkpoint = matches.single;
        day = _checkpoint!.day;
        await _reload();
      });
  int? get nextDay => days.where((d) => d > day).firstOrNull;
  Future<void> startNextDay() => _run(() async {
        final next = nextDay;
        if (!allTargetsCompleted || !_checkpoint!.finished || next == null) {
          throw StateError('Complete this day before starting the next day');
        }
        // Existing unfinished work on the next day is resumed rather than replaced.
        await _openDay(next);
        if (_checkpoint!.finished) await _newAttempt();
      });
  void accountChanged() {
    if (!authorized) {
      _history = [];
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
