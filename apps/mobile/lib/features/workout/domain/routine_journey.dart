import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

import 'routine_attempt.dart';
import 'dart:convert';
import 'guided_timed_progress.dart';
import 'routine_plan_signature.dart';
export 'routine_attempt.dart' show RoutineExerciseStatus;

/// Local navigation/checkpoint metadata. Measurements remain in workout history.
class RoutineCheckpoint {
  RoutineCheckpoint(
      {required this.id,
      required this.scope,
      required this.routineId,
      required this.planSignature,
      required this.day,
      required this.selectedIndex,
      required this.updatedAtMicros,
      this.finished = false,
      this.startedAtMicros,
      this.attempt,
      Map<int, GuidedTimedProgress> guidedProgress = const {},
      Map<int, List<String>> sessions = const {},
      Map<int, String> pending = const {},
      Map<int, int> manualSets = const {},
      Set<int> reviewed = const {},
      Set<int> skipped = const {}})
      : sessions = Map.unmodifiable(sessions.map(
            (key, value) => MapEntry(key, List<String>.unmodifiable(value)))),
        pending = Map.unmodifiable(pending),
        guidedProgress = Map.unmodifiable(guidedProgress),
        manualSets = Map.unmodifiable(manualSets),
        reviewed = Set.unmodifiable(reviewed),
        skipped = Set.unmodifiable(skipped);
  final String id, routineId, planSignature;
  final SessionScope scope;
  final int day, selectedIndex, updatedAtMicros;
  final bool finished;
  final int? startedAtMicros;
  final RoutineAttempt? attempt;
  final Map<int, List<String>> sessions;
  final Map<int, String> pending;
  final Map<int, int> manualSets;
  final Map<int, GuidedTimedProgress> guidedProgress;
  int get schemaVersion =>
      attempt?.routine.schemaVersion ?? (guidedProgress.isEmpty ? 1 : 2);
  final Set<int> reviewed, skipped;

  RoutineCheckpoint copyWith(
          {int? selectedIndex,
          Map<int, GuidedTimedProgress>? guidedProgress,
          bool? finished,
          RoutineAttempt? attempt,
          Map<int, List<String>>? sessions,
          Map<int, String>? pending,
          Map<int, int>? manualSets,
          Set<int>? reviewed,
          Set<int>? skipped}) =>
      RoutineCheckpoint(
          id: id,
          scope: scope,
          routineId: routineId,
          planSignature: planSignature,
          day: day,
          selectedIndex: selectedIndex ?? this.selectedIndex,
          updatedAtMicros: DateTime.now().toUtc().microsecondsSinceEpoch,
          finished: finished ?? this.finished,
          startedAtMicros: startedAtMicros,
          attempt: attempt ?? this.attempt,
          guidedProgress: guidedProgress ?? this.guidedProgress,
          sessions: sessions ?? this.sessions,
          pending: pending ?? this.pending,
          manualSets: manualSets ?? this.manualSets,
          reviewed: reviewed ?? this.reviewed,
          skipped: skipped ?? this.skipped);

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        if (schemaVersion == 2)
          'guidedProgress': {
            for (final e in guidedProgress.entries) '${e.key}': e.value.toJson()
          },
        'id': id,
        'organizationId': scope.organizationId,
        'userId': scope.userId,
        'routineId': routineId,
        'planSignature': planSignature,
        'day': day,
        'selectedIndex': selectedIndex,
        'updatedAtMicros': updatedAtMicros,
        'finished': finished,
        'startedAtMicros': startedAtMicros,
        'attempt': attempt?.toJson(),
        'sessions': {for (final e in sessions.entries) '${e.key}': e.value},
        'pending': {for (final e in pending.entries) '${e.key}': e.value},
        'manualSets': {for (final e in manualSets.entries) '${e.key}': e.value},
        'reviewed': reviewed.toList(),
        'skipped': skipped.toList(),
      };

  factory RoutineCheckpoint.fromJson(Map<String, dynamic> data) {
    String id(String key) {
      final value = data[key];
      if (value is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
        throw const FormatException('Invalid routine checkpoint identity');
      }
      return value;
    }

    int index(dynamic value) {
      if (value is! int || value < 0 || value >= 50) {
        throw const FormatException('Invalid routine entry');
      }
      return value;
    }

    if (data['startedAtMicros'] != null &&
        (data['startedAtMicros'] is! int ||
            (data['startedAtMicros'] as int) < 0)) {
      throw const FormatException('Invalid routine start');
    }
    final attempt = data['attempt'] == null
        ? null
        : RoutineAttempt.fromJson(
            Map<String, dynamic>.from(data['attempt'] as Map));
    if (attempt != null &&
        (attempt.id != data['id'] ||
            attempt.routine.id != data['routineId'] ||
            attempt.day != data['day'] ||
            attempt.scope.userId != data['userId'] ||
            attempt.scope.organizationId != data['organizationId'] ||
            attempt.finished != data['finished'] ||
            attempt.startedAtMicros != data['startedAtMicros'])) {
      throw const FormatException('Routine result identity mismatch');
    }
    final sessionMap = data['sessions'], pendingMap = data['pending'];
    final manualMap = data['manualSets'] ?? <String, dynamic>{};
    final rawGuided = data['guidedProgress'] ?? <String, dynamic>{};
    if (![1, 2].contains(data['schemaVersion']) ||
        rawGuided is! Map ||
        rawGuided.length > 50 ||
        data['schemaVersion'] == 1 && rawGuided.isNotEmpty ||
        data['planSignature'] is! String ||
        (data['planSignature'] as String).length > 32768 ||
        data['day'] is! int ||
        (data['day'] as int) < 1 ||
        data['updatedAtMicros'] is! int ||
        (data['updatedAtMicros'] as int) < 0 ||
        data['finished'] is! bool ||
        sessionMap is! Map ||
        pendingMap is! Map ||
        manualMap is! Map ||
        manualMap.length > 50 ||
        sessionMap.length > 50 ||
        pendingMap.length > 50 ||
        data['reviewed'] is! List ||
        data['skipped'] is! List) {
      throw const FormatException('Invalid routine checkpoint');
    }
    String sessionId(dynamic value) {
      if (value is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
        throw const FormatException('Invalid capture identity');
      }
      return value;
    }

    final sessions = <int, List<String>>{};
    for (final e in sessionMap.entries) {
      final key = index(int.tryParse(e.key.toString()));
      if (e.value is! List || (e.value as List).length > 1000) {
        throw const FormatException('Invalid session list');
      }
      sessions[key] = (e.value as List).map(sessionId).toList();
    }
    final linked = sessions.values.expand((e) => e).toList();
    final manualSets = <int, int>{};
    for (final e in manualMap.entries) {
      if (e.value is! int || e.value < 0 || e.value > 50) {
        throw const FormatException('Invalid self-reported set count');
      }
      manualSets[index(int.tryParse(e.key.toString()))] = e.value as int;
    }
    if (linked.toSet().length != linked.length ||
        (data['reviewed'] as List).length > 50 ||
        (data['skipped'] as List).length > 50) {
      throw const FormatException('Duplicate or excessive routine progress');
    }
    final guided = <int, GuidedTimedProgress>{};
    for (final row in rawGuided.entries) {
      final i = index(int.tryParse(row.key.toString()));
      guided[i] = GuidedTimedProgress.fromJson(
          Map<String, dynamic>.from(row.value as Map));
    }
    if (guided.values.map((g) => g.runId).toSet().length != guided.length)
      throw const FormatException('Guided run belongs to another entry');
    if (data['schemaVersion'] == 2 &&
        (attempt == null || attempt.routine.schemaVersion != 2))
      throw const FormatException('Missing typed routine snapshot');
    if (attempt != null) {
      for (final entry in attempt.entries.where((e) => e.isTimed)) {
        final g = guided[entry.index];
        if (jsonEncode(g?.toJson()) != jsonEncode(entry.guided?.toJson()))
          throw const FormatException('Guided checkpoint/result disagreement');
        final row = attempt.routine.exercises[entry.index];
        if (g != null &&
            (g.entryIndex != entry.index ||
                g.entryId != row.entryId ||
                g.exerciseId != row.exerciseId ||
                g.mediaIdentity !=
                    guidedTimedMediaIdentity(
                        videoUrl: row.videoUrl!,
                        mediaRevision: row.mediaRevision!,
                        mediaGeneration: row.mediaGeneration!) ||
                jsonEncode(g.prescription.toJson()) !=
                    jsonEncode(row.prescription.toJson())))
          throw const FormatException('Guided checkpoint identity mismatch');
        if ((manualSets[entry.index] ?? 0) != 0 ||
            sessions.containsKey(entry.index) ||
            pendingMap.containsKey('${entry.index}'))
          throw const FormatException('Measured evidence attached to timer');
        final skipped = (data['skipped'] as List).contains(entry.index);
        final expected = g?.completed == true
            ? RoutineExerciseStatus.timerCompleted
            : skipped
                ? RoutineExerciseStatus.skipped
                : g?.startedAt != null
                    ? RoutineExerciseStatus.timerPartial
                    : RoutineExerciseStatus.notStarted;
        if (entry.status != expected)
          throw const FormatException('Guided checkpoint status mismatch');
      }
      if (guided.keys
          .any((i) => !attempt.entries.any((e) => e.index == i && e.isTimed)))
        throw const FormatException('Unexpected guided entry');
      if (data['schemaVersion'] == 2 &&
          data['planSignature'] != routinePlanSignature(attempt.routine))
        throw const FormatException('Routine prescription signature mismatch');
    }
    return RoutineCheckpoint(
        id: id('id'),
        scope: SessionScope(
            userId: id('userId'), organizationId: id('organizationId')),
        routineId: id('routineId'),
        planSignature: data['planSignature'] as String,
        day: data['day'] as int,
        selectedIndex: index(data['selectedIndex']),
        updatedAtMicros: data['updatedAtMicros'] as int,
        finished: data['finished'] as bool,
        startedAtMicros: data['startedAtMicros'] as int?,
        attempt: attempt,
        guidedProgress: guided,
        sessions: sessions,
        manualSets: manualSets,
        pending: {
          for (final e in pendingMap.entries)
            index(int.tryParse(e.key.toString())): sessionId(e.value)
        },
        reviewed: (data['reviewed'] as List).map(index).toSet(),
        skipped: (data['skipped'] as List).map(index).toSet());
  }
}

abstract interface class RoutineJourneyStore {
  SessionScope get scope;
  Future<List<RoutineCheckpoint>> load();
  Future<void> save(RoutineCheckpoint checkpoint);
}

/// Atomic compare-and-save for durable stores shared by multiple views.
abstract interface class RevisionedRoutineJourneyStore
    implements RoutineJourneyStore {
  Future<void> saveRevision(RoutineCheckpoint checkpoint,
      {required int? expectedUpdatedAtMicros});
}
