import 'dart:convert';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'published_routine_view.dart';

/// Navigation and scheduling metadata only. Completion is read from typed
/// routine attempts, never accepted from this journal or a UI checkbox.
class ProgramDayProgress {
  const ProgramDayProgress({this.attemptId, this.skipped = false});
  final String? attemptId;
  final bool skipped;
  Map<String, dynamic> toJson() => {'attemptId': attemptId, 'skipped': skipped};
  factory ProgramDayProgress.fromJson(Map<String, dynamic> json) {
    if (json.keys.any((k) => !{'attemptId', 'skipped'}.contains(k)) ||
        json['skipped'] is! bool ||
        (json['attemptId'] != null && !_validId(json['attemptId']))) {
      throw const FormatException('Invalid program day progress');
    }
    return ProgramDayProgress(
        attemptId: json['attemptId'] as String?,
        skipped: json['skipped'] as bool);
  }
}

bool _validId(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

String canonicalProgramJson(Object? value) {
  Object? sorted(Object? input) {
    if (input is Map) {
      final keys = input.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: sorted(input[key])};
    }
    if (input is List) return input.map(sorted).toList();
    return input;
  }

  return jsonEncode(sorted(value));
}

class ProgramEnrollment {
  ProgramEnrollment(
      {required this.id,
      required this.program,
      required List<ScheduledProgramDay> schedule,
      Map<String, ProgramDayProgress> progress = const {}})
      : schedule = List.unmodifiable(schedule),
        progress = Map.unmodifiable(progress);
  final String id;
  final WorkoutProgram program;
  final List<ScheduledProgramDay> schedule;
  final Map<String, ProgramDayProgress> progress;
  ProgramEnrollment copyWith(
          {List<ScheduledProgramDay>? schedule,
          Map<String, ProgramDayProgress>? progress}) =>
      ProgramEnrollment(
          id: id,
          program: program,
          schedule: schedule ?? this.schedule,
          progress: progress ?? this.progress);
  Map<String, dynamic> toJson() => {
        'id': id,
        'program': program.toJson(),
        'schedule': [for (final day in schedule) day.toJson()],
        'progress': {for (final e in progress.entries) e.key: e.value.toJson()}
      };
  factory ProgramEnrollment.fromJson(Map<String, dynamic> json) {
    if (!_validId(json['id']) ||
        json['program'] is! Map ||
        json['schedule'] is! List ||
        json['progress'] is! Map) {
      throw const FormatException('Invalid program enrollment');
    }
    final program = WorkoutProgram.fromJson(
        Map<String, dynamic>.from(json['program'] as Map));
    program.validate(published: true);
    final schedule = (json['schedule'] as List)
        .map((d) =>
            ScheduledProgramDay.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList();
    final originalKeys = {
      for (final d in program.days) 'w${d.week}-d${d.weekday}'
    };
    if (schedule.length != 28 ||
        schedule.map((d) => d.key).toSet().length != 28 ||
        schedule.any((d) => !originalKeys.contains(d.key))) {
      throw const FormatException('Invalid program schedule');
    }
    ProgramSchedule.validateRecovery(schedule);
    for (final scheduled in schedule) {
      final original = program.days.singleWhere((d) =>
          d.week == scheduled.definition.week &&
          d.weekday == scheduled.definition.weekday);
      if (canonicalProgramJson(original.toJson()) !=
          canonicalProgramJson(scheduled.definition.toJson())) {
        throw const FormatException(
            'Program schedule changed its published targets');
      }
    }
    final progress = <String, ProgramDayProgress>{};
    for (final e in (json['progress'] as Map).entries) {
      if (!originalKeys.contains(e.key)) {
        throw const FormatException('Invalid program day key');
      }
      progress[e.key as String] = ProgramDayProgress.fromJson(
          Map<String, dynamic>.from(e.value as Map));
    }
    final linked =
        progress.values.map((p) => p.attemptId).whereType<String>().toList();
    if (linked.toSet().length != linked.length) {
      throw const FormatException('Duplicate program attempts');
    }
    return ProgramEnrollment(
        id: json['id'] as String,
        program: program,
        schedule: schedule,
        progress: progress);
  }
}

class ProgramJournal {
  ProgramJournal(
      {required this.revision, required this.enrollments, this.activeId});
  factory ProgramJournal.empty() =>
      ProgramJournal(revision: 0, enrollments: const []);
  final int revision;
  final String? activeId;
  final List<ProgramEnrollment> enrollments;
  ProgramEnrollment? get active => activeId == null
      ? null
      : enrollments.where((e) => e.id == activeId).firstOrNull;
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'revision': revision,
        'activeId': activeId,
        'enrollments': [for (final e in enrollments) e.toJson()]
      };
  factory ProgramJournal.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['revision'] is! int ||
        (json['revision'] as int) < 0 ||
        json['enrollments'] is! List ||
        (json['enrollments'] as List).length > 100) {
      throw const FormatException('Invalid program journal');
    }
    final records = (json['enrollments'] as List)
        .map((e) =>
            ProgramEnrollment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (records.map((e) => e.id).toSet().length != records.length ||
        (json['activeId'] != null &&
            !records.any((e) => e.id == json['activeId']))) {
      throw const FormatException('Invalid active program');
    }
    return ProgramJournal(
        revision: json['revision'] as int,
        activeId: json['activeId'] as String?,
        enrollments: List.unmodifiable(records));
  }
}

abstract interface class ProgramEnrollmentStore {
  SessionScope get scope;
  Future<ProgramJournal> load();
  Future<void> save(ProgramJournal journal, {required int expectedRevision});
}

abstract interface class WorkoutProgramCatalog {
  SessionScope get scope;
  Future<List<WorkoutProgram>> load();
}

class ProgramRoutineLaunch {
  const ProgramRoutineLaunch(
      {required this.routine,
      required this.routineDay,
      required this.attemptId});
  final PublishedRoutine routine;
  final int routineDay;
  final String attemptId;
}
