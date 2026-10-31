import 'package:flutter_bloc/flutter_bloc.dart';
import 'admin_reporting_gateway.dart';

abstract interface class AdminWorkoutReportingGateway {
  Future<AdminWorkoutReport> loadWorkouts(AdminReportQuery query);
}

class AdminWorkoutReportException implements Exception {
  const AdminWorkoutReportException(this.message);
  final String message;
}

class WorkoutTotals {
  WorkoutTotals(Map<String, int> values) : values = Map.unmodifiable(values);
  static const keys = {
    'sessions',
    'fullReps',
    'partialReps',
    'trackedMicros',
    'routineAttempts',
    'completedRoutineDays',
    'partialRoutineDays',
    'inProgressRoutineDays',
    'unknownCompletionDays',
    'manualSets'
  };
  final Map<String, int> values;
  int get sessions => values['sessions']!;
  int get fullReps => values['fullReps']!;
  int get partialReps => values['partialReps']!;
  int get trackedMicros => values['trackedMicros']!;
  int get routineAttempts => values['routineAttempts']!;
  int get completedRoutineDays => values['completedRoutineDays']!;
  int get partialRoutineDays => values['partialRoutineDays']!;
  int get inProgressRoutineDays => values['inProgressRoutineDays']!;
  int get unknownCompletionDays => values['unknownCompletionDays']!;
  int get manualSets => values['manualSets']!;
}

class WorkoutReportDay {
  const WorkoutReportDay(this.date, this.totals);
  final String date;
  final WorkoutTotals totals;
  int get sessions => totals.sessions;
}

class WorkoutExerciseUsage {
  const WorkoutExerciseUsage(
      {required this.exerciseId,
      required this.name,
      required this.sessions,
      required this.fullReps,
      required this.partialReps,
      required this.trackedMicros,
      required this.manualSets});
  final String exerciseId, name;
  final int sessions, fullReps, partialReps, trackedMicros, manualSets;
}

class WorkoutFormDay {
  const WorkoutFormDay(this.date, this.count, this.sum);
  final String date;
  final int count;
  final double sum;
  double get average => sum / count;
}

class WorkoutFormGroup {
  WorkoutFormGroup(
      {required this.exerciseId,
      required this.scoringVersion,
      required this.detectorId,
      required this.detectorVersion,
      required this.cameraView,
      required this.armMode,
      required this.scoredSessions,
      required this.scoreSum,
      required List<WorkoutFormDay> daily})
      : daily = List.unmodifiable(daily);
  final String exerciseId,
      scoringVersion,
      detectorId,
      detectorVersion,
      cameraView,
      armMode;
  final int scoredSessions;
  final double scoreSum;
  final List<WorkoutFormDay> daily;
  double get average => scoreSum / scoredSessions;
  String get label =>
      '$exerciseId · $scoringVersion · $detectorId/$detectorVersion · $cameraView · $armMode';
}

class AdminWorkoutReport {
  AdminWorkoutReport(
      {required this.query,
      required this.capturedAt,
      required this.scanStartedAt,
      required this.totals,
      required Map<String, int> coverage,
      required List<WorkoutReportDay> daily,
      required List<WorkoutExerciseUsage> exercises,
      required List<WorkoutFormGroup> forms})
      : coverage = Map.unmodifiable(coverage),
        daily = List.unmodifiable(daily),
        exercises = List.unmodifiable(exercises),
        forms = List.unmodifiable(forms);
  final AdminReportQuery query;
  final DateTime capturedAt, scanStartedAt;
  final WorkoutTotals totals;
  final Map<String, int> coverage;
  final List<WorkoutReportDay> daily;
  final List<WorkoutExerciseUsage> exercises;
  final List<WorkoutFormGroup> forms;
  List<WorkoutReportDay> trend({required bool weekly}) {
    if (!weekly) return daily;
    final buckets = <String, Map<String, int>>{};
    for (final d in daily) {
      final date = DateTime.parse('${d.date}T00:00:00Z');
      final monday = date
          .subtract(Duration(days: date.weekday - 1))
          .toIso8601String()
          .substring(0, 10);
      final values = buckets.putIfAbsent(
          monday, () => {for (final k in WorkoutTotals.keys) k: 0});
      for (final k in WorkoutTotals.keys) {
        values[k] = values[k]! + d.totals.values[k]!;
      }
    }
    return [
      for (final e in buckets.entries)
        WorkoutReportDay(e.key, WorkoutTotals(e.value))
    ];
  }

  List<List<Object?>> toCsv() {
    final rows = <List<Object?>>[
      ['GainPath workout analytics', 'provisional_member_backup'],
      ['Timezone', 'Asia/Kuala_Lumpur UTC+08:00'],
      ['Start inclusive UTC', query.range.start.toUtc().toIso8601String()],
      ['End exclusive UTC', query.range.end.toUtc().toIso8601String()],
      ['Source scan started UTC', scanStartedAt.toIso8601String()],
      ['Captured UTC', capturedAt.toIso8601String()],
      [
        'Basis',
        'Latest backups of current active Member accounts only; not all workouts, gym attendance, accepted results or rewards.'
      ],
      [
        'Dates',
        'Camera sessions by end time; routine attempts by finish time or last-update fallback. Counts can move between windows after resume.'
      ],
      [
        'Manual sets',
        totals.manualSets,
        'Device-reported; no generated repetitions or form scores'
      ],
      ['Coverage', 'Count'],
      for (final e in coverage.entries)
        [
          e.key
              .replaceAll('RoutineDays', 'RoutineAttempts')
              .replaceAll('unknownCompletionDays', 'unknownCompletionAttempts'),
          e.value
        ],
      [],
      ['Metric', 'Count / microseconds'],
      for (final e in totals.values.entries)
        [
          e.key
              .replaceAll('RoutineDays', 'RoutineAttempts')
              .replaceAll('unknownCompletionDays', 'unknownCompletionAttempts'),
          e.value
        ],
      [],
      [
        'Malaysia date',
        ...WorkoutTotals.keys.map((k) => k
            .replaceAll('RoutineDays', 'RoutineAttempts')
            .replaceAll('unknownCompletionDays', 'unknownCompletionAttempts'))
      ],
      for (final d in daily)
        [d.date, for (final k in WorkoutTotals.keys) d.totals.values[k]],
      [],
      [
        'Exercise ID',
        'Snapshot name',
        'Camera sessions',
        'Full reps',
        'Partial reps',
        'Tracked micros',
        'Manual sets'
      ],
      for (final e in exercises)
        [
          e.exerciseId,
          e.name,
          e.sessions,
          e.fullReps,
          e.partialReps,
          e.trackedMicros,
          e.manualSets
        ],
      [],
      [
        'Exercise ID',
        'Rule',
        'Detector',
        'Model',
        'View',
        'Arm mode',
        'Scored sessions',
        'Estimated mean %',
        'Malaysia date'
      ],
      for (final f in forms)
        for (final d in f.daily)
          [
            f.exerciseId,
            f.scoringVersion,
            f.detectorId,
            f.detectorVersion,
            f.cameraView,
            f.armMode,
            d.count,
            d.average,
            d.date
          ],
    ];
    // Snapshot names/rule labels are untrusted text, including in spreadsheet exports.
    return [
      for (final row in rows) [for (final v in row) _csvCell(v)]
    ];
  }
}

Object? _csvCell(Object? value) {
  if (value is! String) return value;
  final text = value.replaceAll(RegExp(r'[\r\n]'), ' ');
  return RegExp(r'^[\s]*[=+@\-]').hasMatch(text) ? "'$text" : text;
}

class AdminWorkoutReportingState {
  const AdminWorkoutReportingState(
      {required this.query, this.report, this.loading = false, this.error});
  final AdminReportQuery query;
  final AdminWorkoutReport? report;
  final bool loading;
  final String? error;
}

class AdminWorkoutReportingCubit extends Cubit<AdminWorkoutReportingState> {
  AdminWorkoutReportingCubit(
      {required this.gateway, required AdminReportQuery query})
      : super(AdminWorkoutReportingState(query: query));
  final AdminWorkoutReportingGateway gateway;
  int _generation = 0;
  Future<void> load([AdminReportQuery? target]) async {
    if (isClosed) return;
    final query = target ?? state.query, generation = ++_generation;
    final retained = query == state.query &&
            (gateway is! AdminReportingSessionGuard ||
                (gateway as AdminReportingSessionGuard).canRetainSnapshot)
        ? state.report
        : null;
    emit(AdminWorkoutReportingState(
        query: query, report: retained, loading: true));
    try {
      final report = await gateway.loadWorkouts(query);
      if (isClosed || generation != _generation) return;
      if (gateway is AdminReportingSessionGuard &&
          !(gateway as AdminReportingSessionGuard).canRetainSnapshot) {
        throw StateError('Reporting account changed');
      }
      if (report.query != query) {
        throw const FormatException('Workout report query mismatch');
      }
      emit(AdminWorkoutReportingState(query: query, report: report));
    } catch (error) {
      if (isClosed || generation != _generation) return;
      emit(AdminWorkoutReportingState(
          query: query,
          report:
              (error is AdminReportingException && error.invalidatesSnapshot) ||
                      error is StateError ||
                      error is FormatException ||
                      (gateway is AdminReportingSessionGuard &&
                          !(gateway as AdminReportingSessionGuard)
                              .canRetainSnapshot)
                  ? null
                  : retained,
          error: error is AdminReportingException
              ? error.message
              : error is AdminWorkoutReportException
                  ? error.message
                  : 'Could not load workout analytics. Check your connection and retry.'));
    }
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}
