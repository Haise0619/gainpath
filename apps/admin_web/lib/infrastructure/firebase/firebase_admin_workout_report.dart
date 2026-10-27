import 'dart:convert';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/analytics/application/admin_reporting_gateway.dart';
import '../../features/analytics/application/admin_workout_reporting.dart';

Map<String, dynamic> _map(Object? v) {
  if (v is! Map || v.keys.any((k) => k is! String)) {
    throw const FormatException('Invalid workout object');
  }
  return Map<String, dynamic>.from(v);
}

int _int(Object? v, [int max = 9007199254740991]) {
  if (v is! num || !v.isFinite || v < 0 || v > max || v != v.roundToDouble()) {
    throw const FormatException('Invalid workout integer');
  }
  return v.toInt();
}

String _text(Object? v, int max) {
  if (v is! String || v.length > max || v.contains('\u0000')) {
    throw const FormatException('Invalid workout text');
  }
  return v;
}

Map<String, int> _counts(Object? v, Set<String> keys) {
  final m = _map(v);
  if (m.length != keys.length || !m.keys.toSet().containsAll(keys)) {
    throw const FormatException('Invalid workout counts');
  }
  return m.map((k, v) => MapEntry(k, _int(v)));
}

List<dynamic> _list(Object? v, [int max = 2000]) {
  if (v is! List || v.length > max) {
    throw const FormatException('Invalid workout rows');
  }
  return v;
}

WorkoutTotals _totals(Object? v) {
  final totals = WorkoutTotals(_counts(v, WorkoutTotals.keys));
  if (totals.routineAttempts !=
      totals.completedRoutineDays +
          totals.partialRoutineDays +
          totals.inProgressRoutineDays +
          totals.unknownCompletionDays) {
    throw const FormatException('Routine totals mismatch');
  }
  return totals;
}

AdminWorkoutReport parseAdminWorkoutReport(
    Object? raw, SessionScope scope, AdminReportQuery query) {
  final m = _map(raw),
      start = query.range.start.millisecondsSinceEpoch,
      end = query.range.end.millisecondsSinceEpoch;
  if (query.branchId != null ||
      m['schemaVersion'] != 1 ||
      m['organizationId'] != scope.organizationId ||
      m['startAtMillis'] != start ||
      m['endAtMillis'] != end ||
      m['timezone'] != 'Asia/Kuala_Lumpur' ||
      m['classification'] != 'provisional_member_backup') {
    throw const FormatException('Workout report scope mismatch');
  }
  final scan = _int(m['sourceReadStartedAtMillis'], 8640000000000000),
      captured = _int(m['capturedAtMillis'], 8640000000000000);
  if (captured < scan) {
    throw const FormatException('Workout scan time mismatch');
  }
  final coverage = _counts(m['coverage'], {
    'membersScanned',
    'activeMembers',
    'membersWithBackups',
    'membersWithActivity',
    'backupRecords',
    'bytesRead'
  });
  if (coverage['membersScanned']! > 2000 ||
      coverage['activeMembers']! > 200 ||
      coverage['activeMembers']! > coverage['membersScanned']! ||
      coverage['membersWithBackups']! > coverage['activeMembers']! ||
      coverage['membersWithActivity']! > coverage['membersWithBackups']! ||
      coverage['backupRecords']! > 2000 ||
      coverage['membersWithBackups']! > coverage['backupRecords']! ||
      coverage['bytesRead']! > 16 * 1024 * 1024) {
    throw const FormatException('Workout coverage mismatch');
  }
  String date(Object? value) {
    final text = _text(value, 10),
        parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != text) {
      throw const FormatException('Invalid workout date');
    }
    final at = parsed.subtract(const Duration(hours: 8)).millisecondsSinceEpoch;
    if (at >= end || at + 86400000 <= start || at > captured) {
      throw const FormatException('Workout date outside query');
    }
    return text;
  }

  final totals = _totals(m['totals']), days = <WorkoutReportDay>[];
  String? previous;
  for (final value in _list(m['daily'])) {
    final d = _map(value), label = date(d.remove('date'));
    if (previous != null && previous.compareTo(label) >= 0) {
      throw const FormatException('Workout dates unordered');
    }
    previous = label;
    days.add(WorkoutReportDay(label, _totals(d)));
  }
  for (final k in WorkoutTotals.keys) {
    if (days.fold<int>(0, (n, d) => n + d.totals.values[k]!) !=
        totals.values[k]) {
      throw const FormatException('Workout daily totals mismatch');
    }
  }
  if (totals.sessions + totals.routineAttempts > coverage['backupRecords']! ||
      (totals.sessions + totals.routineAttempts == 0) !=
          (coverage['membersWithActivity'] == 0)) {
    throw const FormatException('Workout source totals mismatch');
  }
  final exercises = <WorkoutExerciseUsage>[], ids = <String>{};
  for (final value in _list(m['exercises'])) {
    final e = _map(value), id = _text(e['exerciseId'], 128);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) || !ids.add(id)) {
      throw const FormatException('Duplicate workout exercise');
    }
    exercises.add(WorkoutExerciseUsage(
        exerciseId: id,
        name: _text(e['name'], 100),
        sessions: _int(e['sessions']),
        fullReps: _int(e['fullReps']),
        partialReps: _int(e['partialReps']),
        trackedMicros: _int(e['trackedMicros']),
        manualSets: _int(e['manualSets'])));
  }
  if (exercises.fold<int>(0, (n, e) => n + e.sessions) != totals.sessions ||
      exercises.fold<int>(0, (n, e) => n + e.fullReps) != totals.fullReps ||
      exercises.fold<int>(0, (n, e) => n + e.partialReps) !=
          totals.partialReps ||
      exercises.fold<int>(0, (n, e) => n + e.trackedMicros) !=
          totals.trackedMicros ||
      exercises.fold<int>(0, (n, e) => n + e.manualSets) != totals.manualSets) {
    throw const FormatException('Exercise totals mismatch');
  }
  final forms = <WorkoutFormGroup>[],
      groups = <String>{},
      scoredByExercise = <String, int>{};
  double score(Object? v, int count) {
    if (v is! num || !v.isFinite || v < 0 || v > count * 100 || count < 1) {
      throw const FormatException('Invalid estimated score');
    }
    return v.toDouble();
  }

  for (final value in _list(m['forms'])) {
    final f = _map(value),
        identity = [
          for (final k in [
            'exerciseId',
            'scoringVersion',
            'detectorId',
            'detectorVersion',
            'cameraView',
            'armMode'
          ])
            _text(f[k], 256)
        ];
    if (!ids.contains(identity.first) ||
        !groups.add(jsonEncode(identity)) ||
        !['not_applicable', 'both', 'leftOnly', 'rightOnly']
            .contains(identity.last)) {
      throw const FormatException('Invalid form group');
    }
    final count = _int(f['scoredSessions']),
        sum = score(f['scoreSum'], count),
        daily = <WorkoutFormDay>[];
    String? last;
    for (final value in _list(f['daily'])) {
      final d = _map(value),
          label = date(d['date']),
          n = _int(d['scoredSessions']);
      if (last != null && last.compareTo(label) >= 0) {
        throw const FormatException('Form dates unordered');
      }
      last = label;
      daily.add(WorkoutFormDay(label, n, score(d['scoreSum'], n)));
    }
    if (daily.fold<int>(0, (n, d) => n + d.count) != count ||
        (daily.fold<double>(0, (n, d) => n + d.sum) - sum).abs() > 0.000001) {
      throw const FormatException('Form totals mismatch');
    }
    scoredByExercise[identity.first] =
        (scoredByExercise[identity.first] ?? 0) + count;
    forms.add(WorkoutFormGroup(
        exerciseId: identity[0],
        scoringVersion: identity[1],
        detectorId: identity[2],
        detectorVersion: identity[3],
        cameraView: identity[4],
        armMode: identity[5],
        scoredSessions: count,
        scoreSum: sum,
        daily: daily));
  }
  for (final e in exercises) {
    if ((scoredByExercise[e.exerciseId] ?? 0) > e.sessions) {
      throw const FormatException('Form source mismatch');
    }
  }
  return AdminWorkoutReport(
      query: query,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(captured, isUtc: true),
      scanStartedAt: DateTime.fromMillisecondsSinceEpoch(scan, isUtc: true),
      totals: totals,
      coverage: coverage,
      daily: days,
      exercises: exercises,
      forms: forms);
}
