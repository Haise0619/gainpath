import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../workout/domain/routine_attempt.dart';
import 'local_member_progress_repository.dart';

const workoutReportOffset = Duration(hours: 8);
String workoutAcceptanceLabel(LocalWorkoutProgressRecord record) =>
    record.status == LocalWorkoutRecordStatus.accepted &&
            record.acceptedAt != null
        ? 'Workout acceptance: server accepted'
        : 'Workout acceptance: not server accepted (acceptance held)';
String reportDate(DateTime instant) =>
    instant.toUtc().add(workoutReportOffset).toIso8601String().substring(0, 10);
String reportDuration(int micros) {
  final seconds = Duration(microseconds: micros).inSeconds;
  return '${seconds ~/ 60}m ${seconds % 60}s';
}

DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

class WorkoutReportFilter {
  WorkoutReportFilter(
      {DateTime? startDay, DateTime? endDay, this.routineId, this.exerciseId})
      : startDay = startDay == null ? null : _day(startDay),
        endDay = endDay == null ? null : _day(endDay) {
    if (this.startDay != null &&
        this.endDay != null &&
        this.endDay!.isBefore(this.startDay!)) {
      throw ArgumentError('End date precedes start date');
    }
  }
  factory WorkoutReportFilter.all() => WorkoutReportFilter();
  factory WorkoutReportFilter.lastDays(DateTime now, int days) {
    if (days < 1) throw ArgumentError('Positive date window required');
    final end = _day(now.toUtc().add(workoutReportOffset));
    return WorkoutReportFilter(
        startDay: end.subtract(Duration(days: days - 1)), endDay: end);
  }
  final DateTime? startDay, endDay;
  final String? routineId, exerciseId;
  bool includes(DateTime instant) {
    final d = _day(instant.toUtc().add(workoutReportOffset));
    return (startDay == null || !d.isBefore(startDay!)) &&
        (endDay == null || !d.isAfter(endDay!));
  }

  String get dateLabel => startDay == null && endDay == null
      ? 'All time'
      : '${startDay?.toIso8601String().substring(0, 10) ?? 'Any date'} to '
          '${endDay?.toIso8601String().substring(0, 10) ?? 'Any date'}';
}

class WorkoutReportDay {
  const WorkoutReportDay(
      this.date, this.fullReps, this.partialReps, this.trackedMicros);
  final String date;
  final int fullReps, partialReps, trackedMicros;
  Map<String, Object> toJson() =>
      {'label': date, 'full': fullReps, 'partial': partialReps};
}

class WorkoutReportFormPoint {
  const WorkoutReportFormPoint(this.date, this.score, {String? key})
      : key = key ?? date;
  final String date;
  final String key;
  final double? score;
  Map<String, Object?> toJson() => {'label': date, 'score': score};
}

class WorkoutReportFormChart {
  WorkoutReportFormChart(this.label, Iterable<WorkoutReportFormPoint> points)
      : points = List.unmodifiable(points);
  final String label;
  final List<WorkoutReportFormPoint> points;
  Map<String, Object> toJson() =>
      {'label': label, 'points': points.map((p) => p.toJson()).toList()};
}

class WorkoutReportDocument {
  WorkoutReportDocument(
      {required Iterable<String> lines,
      required Iterable<WorkoutReportDay> repTrend,
      required Iterable<WorkoutReportFormChart> formTrends})
      : lines = List.unmodifiable(lines),
        repTrend = List.unmodifiable(repTrend),
        formTrends = List.unmodifiable(formTrends);
  final List<String> lines;
  final List<WorkoutReportDay> repTrend;
  final List<WorkoutReportFormChart> formTrends;
  Map<String, Object> toJson() => {
        'lines': lines,
        'repTrend': repTrend.map((d) => d.toJson()).toList(),
        'formTrends': formTrends.map((g) => g.toJson()).toList()
      };
}

abstract interface class WorkoutReportExporter {
  Future<bool> save(WorkoutReportDocument document);
  Future<bool> open();
  Future<void> cancel();
}

class WorkoutReportRoutine {
  WorkoutReportRoutine(this.attempt, Iterable<RoutineExerciseResult> entries)
      : entries = List.unmodifiable(entries);
  final RoutineAttempt attempt;
  final List<RoutineExerciseResult> entries;
  int get manualSets => entries.fold(0, (n, e) => n + e.manualSets);
  DateTime get activityAt => DateTime.fromMicrosecondsSinceEpoch(
      attempt.finishedAtMicros ?? attempt.updatedAtMicros,
      isUtc: true);
  String get dateBasis => attempt.finishedAtMicros == null
      ? 'Updated; completion time unavailable'
      : 'Finished';
}

/// Readable identifier fallback only; this does not assert a catalogue title.
String reportExerciseLabel(String id) {
  if (RegExp(r'^[A-Za-z0-9]{16,}$').hasMatch(id)) return 'Saved exercise';
  final words = id.split('/').last.replaceAll(RegExp(r'[-_]'), ' ').trim();
  if (words.isEmpty) return 'Exercise';
  return words[0].toUpperCase() + words.substring(1);
}

/// Only a unique saved history label is used, never an unrelated catalogue title.
Map<String, String> reportExerciseNames(Iterable<RoutineAttempt> attempts) {
  final candidates = <String, Set<String>>{};
  for (final attempt in attempts) {
    for (final exercise in attempt.routine.exercises) {
      final name = exercise.name.trim();
      if (name.isNotEmpty) {
        candidates.putIfAbsent(exercise.exerciseId, () => <String>{}).add(name);
      }
    }
  }
  return {
    for (final entry in candidates.entries)
      entry.key: entry.value.length == 1
          ? entry.value.single
          : reportExerciseLabel(entry.key)
  };
}

/// Filtered read-only chronology. Routine snapshots are not additional AI captures.
class WorkoutReportTimelineEntry {
  WorkoutReportTimelineEntry(
      {required this.id,
      required this.title,
      required DateTime at,
      required this.sourceLabel,
      required this.dateBasis,
      required this.detail})
      : at = at.toUtc();
  final String id, title, sourceLabel, dateBasis, detail;
  final DateTime at;
  String get dateTimeLabel => at
      .add(workoutReportOffset)
      .toIso8601String()
      .substring(0, 19)
      .replaceFirst('T', ' ');
  String get documentLine =>
      '$dateTimeLabel MYT | $sourceLabel | $title | $dateBasis | $detail | $id';
}

class MemberWorkoutReport {
  MemberWorkoutReport._(
      {required this.scope,
      required this.asOf,
      required this.filter,
      required this.sessions,
      required this.routines,
      required this.routineHistoryAvailable,
      required this.formGroups,
      required this.days,
      required this.formCharts,
      required this.routineNames,
      required this.exerciseNames,
      required this.warnings});
  final SessionScope scope;
  final DateTime asOf;
  final WorkoutReportFilter filter;
  final List<LocalWorkoutProgressRecord> sessions;
  final List<WorkoutReportRoutine> routines;
  final bool routineHistoryAvailable;
  final List<FormProgressSeries> formGroups;
  final List<WorkoutReportDay> days;
  final List<WorkoutReportFormChart> formCharts;
  final Map<String, String> routineNames, exerciseNames;
  final List<String> warnings;
  int get fullReps => sessions.fold(0, (n, s) => n + s.repetitions);
  int get partialReps => sessions.fold(0, (n, s) => n + s.partialRepetitions);
  int get trackedMicros =>
      sessions.fold(0, (n, s) => n + s.trackedDurationMicros);
  int? get manualSets => routineHistoryAvailable
      ? routines.fold<int>(0, (n, r) => n + r.manualSets)
      : null;
  int? get completedRoutineDays => routineHistoryAvailable
      ? routines
          .where(
              (r) => r.attempt.isComplete && r.attempt.finishedAtMicros != null)
          .length
      : null;
  int get unknownCompletionDays => routines
      .where((r) => r.attempt.isComplete && r.attempt.finishedAtMicros == null)
      .length;
  String exerciseName(String id) =>
      exerciseNames[id] ?? reportExerciseLabel(id);

  List<WorkoutReportTimelineEntry> get timeline {
    final entries = <WorkoutReportTimelineEntry>[
      for (final s in sessions)
        WorkoutReportTimelineEntry(
            id: s.sessionId,
            title: exerciseName(s.exerciseId),
            at: s.endedAt,
            sourceLabel: 'Measured AI capture',
            dateBasis: 'Capture ended',
            detail:
                '${s.repetitions} full reps · ${s.partialRepetitions} partial attempts · ${reportDuration(s.trackedDurationMicros)} tracked · Estimated Form Score ${s.formScorePercent == null ? 'unavailable' : '${s.formScorePercent!.toStringAsFixed(1)}%'}'),
      for (final r in routines)
        WorkoutReportTimelineEntry(
            id: r.attempt.id,
            title: '${r.attempt.routine.title} · Day ${r.attempt.day}',
            at: r.activityAt,
            sourceLabel: 'Saved routine snapshot',
            dateBasis: r.dateBasis,
            detail:
                '${r.attempt.statusLabel} · ${r.manualSets} self-reported sets in selection · Whole routine: ${r.attempt.completedExercises}/${r.attempt.entries.length} exercises complete'),
    ]..sort((a, b) {
        final byDate = b.at.compareTo(a.at);
        if (byDate != 0) return byDate;
        final bySource = a.sourceLabel.compareTo(b.sourceLabel);
        return bySource != 0 ? bySource : a.id.compareTo(b.id);
      });
    return List.unmodifiable(entries);
  }

  factory MemberWorkoutReport.build(
      {required SessionScope scope,
      required LocalMemberProgressSnapshot source,
      required WorkoutReportFilter filter,
      required DateTime asOf}) {
    final base = calculateLocalMemberProgress(
        scope: scope, records: source.records, asOf: asOf);
    final history =
        RoutineProgress(scope: scope, attempts: source.attempts, asOf: asOf);
    final all = history.records;
    final routineNames = <String, String>{};
    final exerciseNames = reportExerciseNames(all);
    for (final a in all) {
      routineNames.putIfAbsent(a.routine.id, () => a.routine.title);
    }
    for (final s in base.records) {
      exerciseNames.putIfAbsent(
          s.exerciseId, () => reportExerciseLabel(s.exerciseId));
    }
    final linked = {
      for (final a in all)
        if (filter.routineId == null || a.routine.id == filter.routineId)
          ...a.entries.expand((e) => e.sessionIds)
    };
    final sessions = base.records
        .where((s) =>
            filter.includes(s.endedAt) &&
            (filter.exerciseId == null || s.exerciseId == filter.exerciseId) &&
            (filter.routineId == null || linked.contains(s.sessionId)))
        .toList();
    final routineRows = <WorkoutReportRoutine>[];
    if (source.routineHistoryAvailable) {
      for (final a in all) {
        if (filter.routineId != null && a.routine.id != filter.routineId) {
          continue;
        }
        final entries = a.entries
            .where((e) =>
                filter.exerciseId == null ||
                a.routine.exercises[e.index].exerciseId == filter.exerciseId)
            .toList();
        final r = WorkoutReportRoutine(a, entries);
        if (entries.isNotEmpty &&
            !r.activityAt.isAfter(asOf.toUtc()) &&
            filter.includes(r.activityAt)) {
          routineRows.add(r);
        }
      }
    }
    final filtered = calculateLocalMemberProgress(
        scope: scope, records: sessions, asOf: asOf);
    final buckets = <String, List<LocalWorkoutProgressRecord>>{};
    for (final s in sessions) {
      buckets.putIfAbsent(reportDate(s.endedAt), () => []).add(s);
    }
    final days = [
      for (final date in buckets.keys.toList()..sort())
        WorkoutReportDay(
            date,
            buckets[date]!.fold(0, (n, s) => n + s.repetitions),
            buckets[date]!.fold(0, (n, s) => n + s.partialRepetitions),
            buckets[date]!.fold(0, (n, s) => n + s.trackedDurationMicros))
    ];
    final charts = <WorkoutReportFormChart>[];
    for (final g in filtered.formSeries) {
      final records = g.records.toList()
        ..sort((a, b) {
          final order = a.endedAt.compareTo(b.endedAt);
          return order != 0 ? order : a.sessionId.compareTo(b.sessionId);
        });
      charts.add(WorkoutReportFormChart(
          '${exerciseNames[g.exerciseId]} · ${g.scoringVersion} · ${g.detectorId}/${g.detectorVersion} · ${g.cameraView}',
          [
            for (final record in records)
              WorkoutReportFormPoint(
                  record.endedAt
                      .toUtc()
                      .add(workoutReportOffset)
                      .toIso8601String()
                      .substring(0, 19)
                      .replaceFirst('T', ' '),
                  record.formScorePercent,
                  key:
                      '${record.endedAt.toUtc().toIso8601String()}/${record.sessionId}')
          ]));
    }
    return MemberWorkoutReport._(
        scope: scope,
        asOf: asOf.toUtc(),
        filter: filter,
        sessions: List.unmodifiable(sessions),
        routines: List.unmodifiable(routineRows),
        routineHistoryAvailable: source.routineHistoryAvailable,
        formGroups: filtered.formSeries,
        days: List.unmodifiable(days),
        formCharts: List.unmodifiable(charts),
        routineNames: Map.unmodifiable(routineNames),
        exerciseNames: Map.unmodifiable(exerciseNames),
        warnings: List.unmodifiable(source.warnings));
  }

  WorkoutReportDocument toDocument() {
    final lines = <String>[
      'GainPath | Workout progress report',
      'Generated: ${asOf.add(workoutReportOffset).toIso8601String().substring(0, 19)} | Asia/Kuala_Lumpur (UTC+08:00)',
      'Dates: ${filter.dateLabel}',
      'Routine: ${filter.routineId == null ? 'All routines' : routineNames[filter.routineId] ?? filter.routineId}',
      'Exercise: ${filter.exerciseId == null ? 'All exercises' : exerciseName(filter.exerciseId!)}',
      'Source: account-local saved history, including restored backups.',
      'Provisional AI estimates; workout acceptance is not Cloud Backup status or a reward award.',
      ...warnings.map((w) => 'Data warning: $w'),
      '',
      'SUMMARY',
      '${sessions.length} camera sessions | $fullReps full reps | $partialReps partial attempts',
      'Tracked duration: ${reportDuration(trackedMicros)}',
      if (routineHistoryAvailable) ...[
        'Completed routine days (whole day): $completedRoutineDays',
        'Other routine attempts: ${routines.length - completedRoutineDays! - unknownCompletionDays}',
        'Completion date unavailable: $unknownCompletionDays',
        'Self-reported sets in matching routine snapshots: $manualSets',
      ] else
        'Routine history unavailable',
      'Self-reported sets never contribute measured reps or form.',
      '',
      'DAILY MEASURED ACTIVITY',
      if (days.isEmpty) 'No saved camera sessions match these filters.',
      for (final d in days)
        '${d.date} | ${d.fullReps} full | ${d.partialReps} partial | ${reportDuration(d.trackedMicros)}',
      '',
      'ESTIMATED FORM SCORES | compatible exercise/rule/model/view groups',
      if (formGroups.isEmpty) 'No estimated form available.',
      for (final g in formGroups) ...[
        '${exerciseName(g.exerciseId)} | ${g.scoringVersion} | ${g.detectorId}/${g.detectorVersion} | ${g.cameraView}',
        'Weighted estimate: ${g.meanScore?.toStringAsFixed(1) ?? 'Unavailable'}${g.meanScore == null ? '' : '%'} | ${g.scoredAttempts} scored / ${g.unassessedAttempts} unassessed attempts',
      ],
      '',
      'PROGRESSION HISTORY TIMELINE | selected filters',
      if (timeline.isEmpty) 'No activity matches these filters.',
      for (final event in timeline) event.documentLine,
      'Routine snapshots describe progress; they are not added to measured capture totals.',
      '',
      'CAMERA SESSION DETAILS',
      for (final s in sessions) ...[
        '${reportDate(s.endedAt)} | ${exerciseName(s.exerciseId)} | ${s.sessionId}',
        '${s.repetitions} full | ${s.partialRepetitions} partial | ${reportDuration(s.trackedDurationMicros)} tracked | Estimated Form Score ${s.formScorePercent?.toStringAsFixed(1) ?? 'unavailable'}${s.formScorePercent == null ? '' : '%'}',
        '${workoutAcceptanceLabel(s)} | ${s.scoringVersion} | ${s.detectorId}/${s.detectorVersion} | ${s.cameraView}',
      ],
      '',
      'ROUTINE ATTEMPTS | measured and self-reported work remain separate',
      if (!routineHistoryAvailable) 'Routine history unavailable',
      if (routineHistoryAvailable && routines.isEmpty)
        'No routine attempts match these filters.',
      for (final r in routines) ...[
        '${r.attempt.routine.title} | Day ${r.attempt.day} | ${r.attempt.statusLabel} | ${r.attempt.id}',
        '${r.dateBasis}: ${reportDate(r.activityAt)} | Whole day: ${r.attempt.completedExercises}/${r.attempt.entries.length} exercises complete',
        for (final e in r.entries)
          '${r.attempt.routine.exercises[e.index].name}: ${e.status.name} | ${e.manualSets} self-reported sets | ${e.sessionIds.length} linked camera sessions',
      ],
      '',
      'Routine snapshots and camera session totals are not added together.',
      'Unknown historical completion times are not invented. No calories, load or clinical improvement is inferred.',
    ];
    // Export is an immutable copy of exactly the selected report.
    return WorkoutReportDocument(
        lines: lines, repTrend: days, formTrends: formCharts);
  }
}
