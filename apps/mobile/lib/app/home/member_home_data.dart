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

class HomeActivity {
  HomeActivity(
      {required this.title,
      required this.at,
      this.record,
      this.attempt,
      this.routineBackupLabel});
  final String? routineBackupLabel;
  final String title;
  final DateTime at;
  final LocalWorkoutProgressRecord? record;
  final RoutineAttempt? attempt;
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
  if (selected != null) {
    for (final exercise in selected.exercises) {
      names.putIfAbsent(exercise.exerciseId, () => exercise.name);
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
          routineBackupLabel: routineBackup(a)),
    for (final r in progress?.records ?? <LocalWorkoutProgressRecord>[])
      if (r.scope == scope && !covered.contains(r.sessionId))
        HomeActivity(
            title: names[r.exerciseId] ?? reportExerciseLabel(r.exerciseId),
            at: r.endedAt,
            record: r),
  ]..sort((a, b) => b.at.compareTo(a.at));
  return items.take(2).toList();
}
