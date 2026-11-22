import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/data/published_routine.dart';
import '../../features/workout/domain/routine_attempt.dart';
import '../../features/workout/domain/routine_plan_signature.dart';
import '../../features/analytics/domain/member_workout_report.dart';

RoutineAttempt? homeWorkoutAttempt(SessionScope scope,
    PublishedRoutine? routine, RoutineProgress? progress, DateTime now) {
  if (routine == null || progress == null) return null;
  final signature = routinePlanSignature(routine);
  final today = reportDate(now);
  for (final attempt in progress.records) {
    if (attempt.scope != scope ||
        attempt.updatedAtMicros > now.microsecondsSinceEpoch ||
        routinePlanSignature(attempt.routine) != signature) {
      continue;
    }
    if (!attempt.finished ||
        (attempt.finishedAtMicros != null &&
            reportDate(DateTime.fromMicrosecondsSinceEpoch(
                    attempt.finishedAtMicros!,
                    isUtc: true)) ==
                today)) {
      return attempt;
    }
  }
  return null;
}

enum HomeDayActivity { none, exerciseRecord, inProgress, completed }

/// Display markers share the exact calendar bounds of the existing totals.
List<HomeDayActivity> homeWeekActivity(
    RoutineProgress? routines, MemberLocalProgress? progress) {
  final days = List.filled(7, HomeDayActivity.none);
  final start = routines?.weekStart ?? progress?.weekStart;
  final end = routines?.weekEnd ?? progress?.weekEnd;
  final asOf = routines?.asOf ?? progress?.asOf;
  if (start == null || end == null || asOf == null) return days;

  void mark(DateTime at, HomeDayActivity status) {
    if (at.isBefore(start) || !at.isBefore(end) || at.isAfter(asOf)) return;
    final day = at.difference(start).inDays;
    if (status.index > days[day].index) days[day] = status;
  }

  for (final record
      in progress?.records ?? const <LocalWorkoutProgressRecord>[]) {
    mark(record.endedAt, HomeDayActivity.exerciseRecord);
  }
  for (final attempt in routines?.records ?? const <RoutineAttempt>[]) {
    final micros = attempt.isComplete
        ? attempt.finishedAtMicros
        : !attempt.finished
            ? attempt.updatedAtMicros
            : null;
    if (micros == null) continue;
    mark(
        DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true),
        attempt.isComplete
            ? HomeDayActivity.completed
            : HomeDayActivity.inProgress);
  }
  return days;
}

class HomeActivity {
  HomeActivity(
      {required this.title,
      required this.at,
      this.record,
      this.attempt,
      this.imageUrl = '',
      this.routineBackupLabel});
  final String? routineBackupLabel;
  final String title;
  final DateTime at;
  final LocalWorkoutProgressRecord? record;
  final RoutineAttempt? attempt;
  final String imageUrl;
  String get result => record != null
      ? '${record!.repetitions} reps${record!.partialRepetitions > 0 ? ' · ${record!.partialRepetitions} partial' : ''}'
      : '${attempt!.completedExercises}/${attempt!.entries.length} exercises · ${attempt!.statusLabel.toLowerCase()}';
  String get backupLabel => record == null
      ? routineBackupLabel ?? 'Saved on device'
      : record!.scope.datasetScope != null
          ? 'Fictional fixture'
          : switch (record!.status) {
              LocalWorkoutRecordStatus.accepted => 'Backed up',
              LocalWorkoutRecordStatus.localOnly => 'Saved on device',
              LocalWorkoutRecordStatus.pending =>
                'Saved on device · backup pending',
              LocalWorkoutRecordStatus.retryable =>
                'Saved on device · backup needs retry',
              LocalWorkoutRecordStatus.rejected =>
                'Saved on device · backup rejected',
              LocalWorkoutRecordStatus.unknown =>
                'Saved on device · backup status unknown',
            };
}

List<HomeActivity> homeRecentActivities(
    SessionScope scope,
    MemberLocalProgress? progress,
    RoutineProgress? routines,
    PublishedRoutine? selected) {
  final attempts = routines?.records.where((a) => a.scope == scope).toList() ??
      <RoutineAttempt>[];
  final names = reportExerciseNames(attempts);
  final images = <String, String>{
    for (final attempt in attempts)
      for (final exercise in attempt.routine.exercises.reversed)
        if (exercise.imageUrl.isNotEmpty)
          exercise.exerciseId: exercise.imageUrl,
  };
  if (selected != null) {
    for (final exercise in selected.exercises) {
      names.putIfAbsent(exercise.exerciseId, () => exercise.name);
      if (exercise.imageUrl.isNotEmpty) {
        images[exercise.exerciseId] = exercise.imageUrl;
      }
    }
  }
  final covered =
      attempts.expand((a) => a.entries).expand((e) => e.sessionIds).toSet();
  final captures = {
    for (final r in progress?.records ?? <LocalWorkoutProgressRecord>[])
      if (r.scope == scope) r.sessionId: r
  };
  String routineBackup(RoutineAttempt a) {
    final ids = a.entries.expand((e) => e.sessionIds).toSet();
    if (a.scope.datasetScope != null) {
      return 'Fictional fixture · saved on device';
    }
    if (ids.isEmpty) return 'Saved on device';
    final statuses = ids.map((id) => captures[id]?.status).toSet();
    if (statuses.contains(LocalWorkoutRecordStatus.rejected)) {
      return 'Saved on device · backup rejected';
    }
    if (statuses.contains(LocalWorkoutRecordStatus.retryable)) {
      return 'Saved on device · backup needs retry';
    }
    if (statuses.contains(LocalWorkoutRecordStatus.pending)) {
      return 'Saved on device · backup pending';
    }
    if (statuses.contains(null) ||
        statuses.contains(LocalWorkoutRecordStatus.unknown)) {
      return 'Saved on device · backup status unavailable';
    }
    if (statuses.length == 1 &&
        statuses.contains(LocalWorkoutRecordStatus.accepted)) {
      return 'Exercise records backed up · routine on device';
    }
    return 'Saved on device';
  }

  final items = [
    for (final a in attempts)
      HomeActivity(
          title: a.routine.title,
          at: DateTime.fromMicrosecondsSinceEpoch(
              a.finishedAtMicros ?? a.updatedAtMicros,
              isUtc: true),
          attempt: a,
          imageUrl: _routineThumbnail(a),
          routineBackupLabel: routineBackup(a)),
    for (final r in progress?.records ?? <LocalWorkoutProgressRecord>[])
      if (r.scope == scope && !covered.contains(r.sessionId))
        HomeActivity(
            title: names[r.exerciseId] ?? reportExerciseLabel(r.exerciseId),
            at: r.endedAt,
            imageUrl: images[r.exerciseId] ?? '',
            record: r),
  ]..sort((a, b) => b.at.compareTo(a.at));
  return items.take(2).toList();
}

String _routineThumbnail(RoutineAttempt attempt) {
  for (final exercise in attempt.routine.exercises) {
    if (exercise.dayNumber == attempt.day && exercise.imageUrl.isNotEmpty) {
      return exercise.imageUrl;
    }
  }
  return '';
}
