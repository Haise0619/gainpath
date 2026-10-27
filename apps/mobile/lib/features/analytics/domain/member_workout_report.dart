import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../workout/domain/routine_attempt.dart';
import 'local_member_progress_repository.dart';

const workoutReportOffset = Duration(hours: 8);
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
  const WorkoutReportFormPoint(this.date, this.score);
  final String date;
  final double score;
  Map<String, Object> toJson() => {'label': date, 'score': score};
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
  String exerciseName(String id) => exerciseNames[id] ?? id;

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
    final routineNames = <String, String>{}, exerciseNames = <String, String>{};
    for (final a in all) {
      routineNames.putIfAbsent(a.routine.id, () => a.routine.title);
      for (final e in a.routine.exercises) {
        exerciseNames.putIfAbsent(e.exerciseId, () => e.name);
      }
    }
    for (final s in base.records) {
      exerciseNames.putIfAbsent(s.exerciseId, () => s.exerciseId);
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
      final points = <String, List<LocalWorkoutProgressRecord>>{};
      for (final s in g.records.where((s) => s.formScorePercent != null)) {
        points.putIfAbsent(reportDate(s.endedAt), () => []).add(s);
      }
      charts.add(WorkoutReportFormChart(
          '${exerciseNames[g.exerciseId]} · ${g.scoringVersion} · ${g.detectorId}/${g.detectorVersion} · ${g.cameraView}',
          [
            for (final date in points.keys.toList()..sort())
              WorkoutReportFormPoint(
                  date,
                  points[date]!.fold<double>(
                          0, (n, s) => n + s.formScorePercent! * s.attempts) /
                      points[date]!.fold<int>(0, (n, s) => n + s.attempts))
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
      'Provisional AI estimates; backup is not workout verification or a reward award.',
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
      'ESTIMATED FORM | compatible exercise/rule/model/view groups',
      if (formGroups.isEmpty) 'No estimated form available.',
      for (final g in formGroups) ...[
        '${exerciseName(g.exerciseId)} | ${g.scoringVersion} | ${g.detectorId}/${g.detectorVersion} | ${g.cameraView}',
        'Weighted estimate: ${g.meanScore?.toStringAsFixed(1) ?? 'Unavailable'}${g.meanScore == null ? '' : '%'} | ${g.scoredAttempts} scored / ${g.unassessedAttempts} unassessed attempts',
      ],
      '',
      'CAMERA SESSION DETAILS',
      for (final s in sessions) ...[
        '${reportDate(s.endedAt)} | ${exerciseName(s.exerciseId)} | ${s.sessionId}',
        '${s.repetitions} full | ${s.partialRepetitions} partial | ${reportDuration(s.trackedDurationMicros)} tracked | Estimated form ${s.formScorePercent?.toStringAsFixed(1) ?? 'unavailable'}${s.formScorePercent == null ? '' : '%'}',
        'Status: ${s.status.name} | ${s.scoringVersion} | ${s.detectorId}/${s.detectorVersion} | ${s.cameraView}',
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
