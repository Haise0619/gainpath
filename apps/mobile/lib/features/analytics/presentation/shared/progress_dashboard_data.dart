import 'package:gainpath_domain/analytics.dart';
import '../../domain/local_member_progress_repository.dart';
import '../../domain/member_workout_report.dart';
import '../../../workout/domain/routine_attempt.dart';

/// Presentation-only aggregation. Saved measurements and compatibility are intact.
class ProgressDashboardData {
  ProgressDashboardData(
      MemberLocalProgress progress, RoutineProgress? routines) {
    final source = LocalMemberProgressSnapshot(
        records: progress.records,
        attempts: routines?.records ?? const [],
        routineHistoryAvailable: routines != null);
    report = MemberWorkoutReport.build(
        scope: progress.scope,
        source: source,
        filter: WorkoutReportFilter.all(),
        asOf: progress.asOf);
    final end = progress.weekEnd.subtract(const Duration(microseconds: 1));
    weekly = MemberWorkoutReport.build(
        scope: progress.scope,
        source: source,
        filter: WorkoutReportFilter(
            startDay: DateTime.parse(reportDate(progress.weekStart)),
            endDay: DateTime.parse(reportDate(end))),
        asOf: progress.asOf);
    final byExercise = <String, ProgressAssessment>{};
    for (final record in report.sessions) {
      if (!hasFormAssessment(record) ||
          byExercise.containsKey(record.exerciseId)) {
        continue;
      }
      final previous = report.sessions
          .where((r) =>
              r.versionKey == record.versionKey &&
              r.endedAt.isBefore(record.endedAt) &&
              hasFormAssessment(r))
          .firstOrNull;
      byExercise[record.exerciseId] = ProgressAssessment(record, previous);
    }
    assessments = List.unmodifiable(byExercise.values);
  }
  late final MemberWorkoutReport report, weekly;
  late final List<ProgressAssessment> assessments;
}

class ProgressAssessment {
  const ProgressAssessment(this.latest, this.previous);
  final LocalWorkoutProgressRecord latest;
  final LocalWorkoutProgressRecord? previous;
  double? get change => previous == null
      ? null
      : latest.formScorePercent! - previous!.formScorePercent!;
}

bool formScoringUnsupported(String version) => const {
      'standing-lateral-raise-front-v1',
      'dumbbell-shoulder-press-front-v1',
      'single-arm-row-side-v1',
      'reverse-lunge-side-v1',
    }.contains(version);

bool hasFormAssessment(LocalWorkoutProgressRecord record) =>
    !formScoringUnsupported(record.scoringVersion) &&
    record.attempts > 0 &&
    record.formScorePercent != null &&
    record.formScorePercent!.isFinite;
