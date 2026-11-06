import 'dart:convert';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'published_routine_view.dart';
import 'guided_timed_progress.dart';
import 'package:gainpath_domain/workout.dart';

enum RoutineExerciseStatus {
  notStarted,
  partial,
  completed,
  selfReportedPartial,
  selfReportedCompleted,
  instructionsReviewed,
  skipped,
  timerPartial,
  timerCompleted
}

/// A local record of one routine-day attempt. No cloud acceptance or rewards.
class RoutineExerciseResult {
  RoutineExerciseResult(
      {required this.index,
      required this.status,
      required this.sessionIds,
      required this.fullRepetitions,
      required this.partialRepetitions,
      required this.trackedDurationMicros,
      required this.manualSets,
      this.guided,
      this.isTimed = false});
  final GuidedTimedProgress? guided;
  final bool isTimed;
  factory RoutineExerciseResult.timed(
          {required int index,
          required RoutineExerciseStatus status,
          GuidedTimedProgress? guided}) =>
      RoutineExerciseResult(
          index: index,
          status: status,
          sessionIds: const [],
          fullRepetitions: 0,
          partialRepetitions: 0,
          trackedDurationMicros: 0,
          manualSets: 0,
          guided: guided,
          isTimed: true);
  final int index,
      fullRepetitions,
      partialRepetitions,
      trackedDurationMicros,
      manualSets;
  final RoutineExerciseStatus status;
  final List<String> sessionIds;
  bool get completed =>
      status == RoutineExerciseStatus.completed ||
      status == RoutineExerciseStatus.selfReportedCompleted ||
      status == RoutineExerciseStatus.timerCompleted;
  Map<String, dynamic> toJson() => isTimed
      ? {
          'kind': 'timed',
          'index': index,
          'status': status.name,
          if (guided != null) 'guided': guided!.toJson()
        }
      : {
          'index': index,
          'status': status.name,
          'sessionIds': sessionIds,
          'fullRepetitions': fullRepetitions,
          'partialRepetitions': partialRepetitions,
          'trackedDurationMicros': trackedDurationMicros,
          'manualSets': manualSets
        };
  factory RoutineExerciseResult.fromJson(Map<String, dynamic> data) {
    if (data['kind'] == 'timed') {
      if (data.keys
          .any((k) => !{'kind', 'index', 'status', 'guided'}.contains(k)))
        throw const FormatException('Unexpected timed result measurement');
      final status =
          RoutineExerciseStatus.values.byName(data['status'] as String);
      final guided = data['guided'] == null
          ? null
          : GuidedTimedProgress.fromJson(
              Map<String, dynamic>.from(data['guided'] as Map));
      if (!{
            RoutineExerciseStatus.notStarted,
            RoutineExerciseStatus.timerPartial,
            RoutineExerciseStatus.timerCompleted,
            RoutineExerciseStatus.skipped
          }.contains(status) ||
          status == RoutineExerciseStatus.timerCompleted &&
              guided?.completed != true ||
          status == RoutineExerciseStatus.timerPartial &&
              guided?.startedAt == null)
        throw const FormatException('Invalid timer result status');
      return RoutineExerciseResult.timed(
          index: _number(data, 'index', max: 49),
          status: status,
          guided: guided);
    }
    final status =
        RoutineExerciseStatus.values.where((s) => s.name == data['status']);
    final ids = data['sessionIds'];
    if (status.length != 1 ||
        ids is! List ||
        ids.length > 1000 ||
        ids.any((id) =>
            id is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) ||
        ids.toSet().length != ids.length) {
      throw const FormatException('Invalid routine result');
    }
    return RoutineExerciseResult(
        index: _number(data, 'index', max: 49),
        status: status.single,
        sessionIds: List.unmodifiable(ids.cast<String>()),
        fullRepetitions: _number(data, 'fullRepetitions'),
        partialRepetitions: _number(data, 'partialRepetitions'),
        trackedDurationMicros: _number(data, 'trackedDurationMicros'),
        manualSets: _number(data, 'manualSets', max: 50));
  }
}

int _number(Map<String, dynamic> data, String key,
    {int max = 9007199254740991}) {
  final value = data[key];
  if (value is! int || value < 0 || value > max) {
    throw const FormatException('Invalid routine result number');
  }
  return value;
}

Map<String, dynamic> routinePlanSnapshot(PublishedRoutine routine) => {
      'schemaVersion': routine.schemaVersion,
      'kind': routine.schemaVersion == 2 ? 'routine_v2' : 'routine',
      'status': 'published',
      'sourceBlueprintId': routine.sourceBlueprintId,
      'title': routine.title,
      'estimatedMinutes': routine.estimatedMinutes,
      if (routine.difficulty != null) 'difficulty': routine.difficulty,
      'exercises': [
        for (final e in routine.exercises)
          {
            'exerciseId': e.exerciseId,
            'dayNumber': e.dayNumber,
            'name': e.name,
            'category': e.category,
            'sets': e.sets,
            if (e.reps != null) 'reps': e.reps,
            if (routine.schemaVersion == 2) ...{
              'entryId': e.entryId,
              'executionMode': e.executionMode!.name,
              'restSeconds': e.restSeconds,
              if (e.durationSeconds != null)
                'durationSeconds': e.durationSeconds,
              if (e.mediaRevision != null) 'mediaRevision': e.mediaRevision,
              if (e.mediaGeneration != null)
                'mediaGeneration': e.mediaGeneration,
              if (e.mediaValidation != null)
                'mediaValidation': e.mediaValidation
            },
            if (e.restSeconds != 60) 'restSeconds': e.restSeconds,
            'cue': e.cue,
            'imageUrl': e.imageUrl,
            'muscleGroup': e.muscleGroup,
            'videoUrl': e.videoUrl ?? '',
            ...e.tutorial.toJson()
          }
      ]
    };

class RoutineAttempt {
  RoutineAttempt(
      {required this.id,
      required this.scope,
      required this.routine,
      required this.day,
      required this.finished,
      required this.updatedAtMicros,
      required this.entries,
      this.startedAtMicros,
      this.finishedAtMicros});
  final String id;
  final SessionScope scope;
  final PublishedRoutine routine;
  final int day, updatedAtMicros;
  final int? startedAtMicros, finishedAtMicros;
  final bool finished;
  final List<RoutineExerciseResult> entries;
  int get completedExercises => entries.where((e) => e.completed).length;
  bool get isComplete =>
      finished && entries.isNotEmpty && completedExercises == entries.length;
  String get statusLabel => isComplete
      ? 'Completed'
      : finished
          ? 'Partially completed'
          : 'In progress';
  int get fullRepetitions => entries.fold(0, (n, e) => n + e.fullRepetitions);
  int get partialRepetitions =>
      entries.fold(0, (n, e) => n + e.partialRepetitions);
  int get trackedDurationMicros =>
      entries.fold(0, (n, e) => n + e.trackedDurationMicros);
  int get selfReportedSets => entries.fold(0, (n, e) => n + e.manualSets);
  int get guidedDurationMicros =>
      entries.fold(0, (n, e) => n + (e.guided?.totalActiveMicroseconds ?? 0));
  int get timerCompletedSets =>
      entries.fold(0, (n, e) => n + (e.guided?.completedSets ?? 0));
  int? get elapsedDurationMicros =>
      startedAtMicros == null || finishedAtMicros == null
          ? null
          : finishedAtMicros! - startedAtMicros!;
  Map<String, dynamic> toJson() => {
        'schemaVersion': routine.schemaVersion,
        'id': id,
        'organizationId': scope.organizationId,
        'userId': scope.userId,
        'routineId': routine.id,
        'routine': routinePlanSnapshot(routine),
        'day': day,
        'finished': finished,
        'startedAtMicros': startedAtMicros,
        'finishedAtMicros': finishedAtMicros,
        'updatedAtMicros': updatedAtMicros,
        'entries': entries.map((e) => e.toJson()).toList()
      };
  factory RoutineAttempt.fromJson(Map<String, dynamic> data) {
    for (final key in ['id', 'organizationId', 'userId', 'routineId']) {
      if (data[key] is! String ||
          !(data[key] as String).isNotEmpty ||
          (data[key] as String).length > 128) {
        throw const FormatException('Invalid routine result identity');
      }
    }
    final raw = data['entries'];
    if (![1, 2].contains(data['schemaVersion']) ||
        data['finished'] is! bool ||
        data['routine'] is! Map ||
        raw is! List ||
        raw.isEmpty ||
        raw.length > 50) {
      throw const FormatException('Invalid routine attempt');
    }
    final routine = PublishedRoutine.fromDocument(data['routineId'] as String,
        Map<String, dynamic>.from(data['routine'] as Map));
    final day = _number(data, 'day');
    final entries = raw
        .map((e) =>
            RoutineExerciseResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (routine.schemaVersion != data['schemaVersion'])
      throw const FormatException('Routine contract mismatch');
    for (final result in entries) {
      if (result.index >= routine.exercises.length)
        throw const FormatException('Invalid result index');
      final row = routine.exercises[result.index];
      if ((row.executionMode == ExerciseExecutionMode.videoGuidedTimed) !=
          result.isTimed)
        throw const FormatException('Result execution mismatch');
      if (result.guided case final g?) {
        if (g.entryIndex != result.index ||
            g.entryId != row.entryId ||
            g.exerciseId != row.exerciseId ||
            jsonEncode(g.prescription.toJson()) !=
                jsonEncode(row.prescription.toJson()))
          throw const FormatException('Guided result identity mismatch');
      }
    }
    final indices = [
      for (var i = 0; i < routine.exercises.length; i++)
        if (routine.exercises[i].dayNumber == day) i
    ];
    if (jsonEncode(entries.map((e) => e.index).toList()) !=
        jsonEncode(indices)) {
      throw const FormatException('Routine result entries do not match day');
    }
    final sessionIds = entries.expand((e) => e.sessionIds).toList();
    if (sessionIds.toSet().length != sessionIds.length ||
        entries.any((e) => e.manualSets > routine.exercises[e.index].sets)) {
      throw const FormatException(
          'Duplicate captures or invalid manual targets');
    }
    final start = data['startedAtMicros'] == null
        ? null
        : _number(data, 'startedAtMicros');
    final end = data['finishedAtMicros'] == null
        ? null
        : _number(data, 'finishedAtMicros');
    if (end != null &&
        (data['finished'] != true || start == null || end < start)) {
      throw const FormatException('Invalid routine attempt times');
    }
    return RoutineAttempt(
        id: data['id'] as String,
        scope: SessionScope(
            userId: data['userId'] as String,
            organizationId: data['organizationId'] as String),
        routine: routine,
        day: day,
        finished: data['finished'] as bool,
        updatedAtMicros: _number(data, 'updatedAtMicros'),
        startedAtMicros: start,
        finishedAtMicros: end,
        entries: List.unmodifiable(entries));
  }
}

class RoutineProgress {
  RoutineProgress(
      {required SessionScope scope,
      required Iterable<RoutineAttempt> attempts,
      required DateTime asOf}) {
    final unique = <String, RoutineAttempt>{};
    final now = asOf.toUtc();
    for (final a in attempts) {
      if (a.scope != scope) {
        throw StateError('Routine history account mismatch');
      }
      final previous = unique[a.id];
      if (previous != null &&
          jsonEncode(previous.toJson()) != jsonEncode(a.toJson())) {
        throw StateError('Conflicting routine attempts');
      }
      unique[a.id] = a;
    }
    records = List.unmodifiable(unique.values.toList()
      ..sort((a, b) {
        final time = (b.finishedAtMicros ?? b.updatedAtMicros)
            .compareTo(a.finishedAtMicros ?? a.updatedAtMicros);
        return time == 0 ? a.id.compareTo(b.id) : time;
      }));
    final malaysia = now.add(const Duration(hours: 8));
    final monday = DateTime.utc(malaysia.year, malaysia.month, malaysia.day)
        .subtract(Duration(days: malaysia.weekday - 1, hours: 8));
    weekStart = monday;
    weekEnd = monday.add(const Duration(days: 7));
    final completedRecords = records.where((a) =>
        a.isComplete &&
        a.finishedAtMicros != null &&
        a.finishedAtMicros! <= now.microsecondsSinceEpoch);
    completed = completedRecords.length;
    weeklyCompleted = completedRecords
        .where((a) =>
            a.finishedAtMicros! >= weekStart.microsecondsSinceEpoch &&
            a.finishedAtMicros! < weekEnd.microsecondsSinceEpoch)
        .length;
  }
  late final List<RoutineAttempt> records;
  late final DateTime weekStart, weekEnd;
  late final int completed, weeklyCompleted;
}
