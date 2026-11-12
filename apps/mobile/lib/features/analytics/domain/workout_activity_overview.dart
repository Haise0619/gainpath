import 'package:gainpath_domain/analytics.dart';
import '../../workout/domain/routine_attempt.dart';
import 'member_workout_report.dart';

bool hasWorkoutActivity(RoutineAttempt a) =>
    a.trackedDurationMicros > 0 ||
    a.guidedDurationMicros > 0 ||
    a.selfReportedSets > 0;

/// Overview is workout-centered. The complete report retains every capture.
List<WorkoutReportTimelineEntry> overviewWorkoutEvents(
    MemberWorkoutReport report) {
  final workouts = report.routines
      .where((r) => hasWorkoutActivity(r.attempt) || r.attempt.finished);
  final ids = workouts.map((r) => r.attempt.id).toSet();
  final linked =
      workouts.expand((r) => r.entries).expand((e) => e.sessionIds).toSet();
  return report.timeline
      .where((event) => event.kind == WorkoutTimelineKind.routine
          ? ids.contains(event.id)
          : !linked.contains(event.id))
      .toList();
}

/// Saved start dates, not a reconstructed calendar of every active second.
Set<String> workoutStartDays(
    MemberLocalProgress progress, Iterable<RoutineAttempt> attempts) {
  final dates = <String>{}, linked = <String>{};
  bool inWeek(DateTime d) =>
      !d.isBefore(progress.weekStart) &&
      d.isBefore(progress.weekEnd) &&
      !d.isAfter(progress.asOf);
  for (final a in attempts) {
    if (a.scope != progress.scope ||
        a.startedAtMicros == null ||
        !hasWorkoutActivity(a)) {
      continue;
    }
    linked.addAll(a.entries.expand((e) => e.sessionIds));
    final start =
        DateTime.fromMicrosecondsSinceEpoch(a.startedAtMicros!, isUtc: true);
    if (inWeek(start)) dates.add(reportDate(start));
  }
  for (final s in progress.records) {
    if (!linked.contains(s.sessionId) &&
        s.trackedDurationMicros > 0 &&
        inWeek(s.startedAt)) {
      dates.add(reportDate(s.startedAt));
    }
  }
  return dates;
}

String routineActivitySummary(RoutineAttempt a,
    {Iterable<RoutineExerciseResult>? entries}) {
  final rows = (entries ?? a.entries).toList();
  final reps = rows.fold<int>(0, (n, e) => n + e.fullRepetitions);
  final guided =
      rows.fold<int>(0, (n, e) => n + (e.guided?.totalActiveMicroseconds ?? 0));
  final timedSets =
      rows.fold<int>(0, (n, e) => n + (e.guided?.completedSets ?? 0));
  final manual = rows.fold<int>(0, (n, e) => n + e.manualSets);
  return [
    if (rows.any((e) => e.sessionIds.isNotEmpty)) '$reps AI full reps',
    if (guided > 0) '$timedSets timed sets · ${reportDuration(guided)} active',
    if (manual > 0) '$manual self-reported sets',
    if (!rows.any((e) => e.sessionIds.isNotEmpty) && guided == 0 && manual == 0)
      '${rows.where((e) => e.completed).length}/${rows.length} exercises completed',
  ].join(' · ');
}

String progressArmModeLabel(String? mode) => switch (mode) {
      'leftOnly' => 'Left only',
      'rightOnly' => 'Right only',
      'both' => 'Both arms',
      _ => 'Arm mode unknown',
    };

String progressFormLabel(LocalWorkoutProgressRecord record) => const {
      'standing-lateral-raise-front-v1',
      'dumbbell-shoulder-press-front-v1',
      'single-arm-row-side-v1',
      'reverse-lunge-side-v1'
    }.contains(record.scoringVersion)
        ? 'Form assessment not available for this exercise.'
        : record.formScorePercent == null
            ? record.attempts == 0
                ? 'No movements assessed yet'
                : 'Not enough evidence for a form assessment'
            : '${record.formScorePercent!.toStringAsFixed(1)}% estimated form';
