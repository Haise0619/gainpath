import 'package:flutter/material.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/member_workout_report.dart';
import '../../domain/local_member_progress_repository.dart';
import '../../../workout/domain/routine_attempt.dart';
import '../member/widgets/local_progress_widgets.dart';

/// Small read-only overview; detailed measurements remain in the reports.
class MemberProgressOverview extends StatelessWidget {
  const MemberProgressOverview(
      {super.key,
      required this.progress,
      this.routines,
      this.program,
      this.programBuilder,
      this.programStatsBuilder,
      this.goals,
      this.onStart,
      this.onHistory,
      this.onReports,
      this.onPerformance,
      this.onForm,
      this.onPoints,
      this.onBackup,
      this.onWorkout,
      this.onRoutine});
  final MemberLocalProgress progress;
  final RoutineProgress? routines;
  final Widget? program, goals;
  final Widget Function(Widget Function(BuildContext, int?))? programBuilder;
  final Widget Function(Widget Function(BuildContext, int?, int?))?
      programStatsBuilder;
  final VoidCallback? onStart,
      onHistory,
      onReports,
      onPerformance,
      onForm,
      onPoints,
      onBackup;
  final void Function(LocalWorkoutProgressRecord)? onWorkout;
  final void Function(RoutineAttempt)? onRoutine;
  @override
  Widget build(BuildContext context) {
    final report = MemberWorkoutReport.build(
        scope: progress.scope,
        source: LocalMemberProgressSnapshot(
            records: progress.records,
            attempts: routines?.records ?? const [],
            routineHistoryAvailable: routines != null),
        filter: WorkoutReportFilter.all(),
        asOf: progress.asOf);
    final days = <String>{};
    bool inWeek(DateTime at) =>
        !at.isBefore(progress.weekStart) &&
        at.isBefore(progress.weekEnd) &&
        !at.isAfter(progress.asOf);
    for (final record in progress.records) {
      if (inWeek(record.endedAt) && record.trackedDurationMicros > 0) {
        days.add(reportDate(record.endedAt));
      }
    }
    for (final attempt in routines?.records ?? <RoutineAttempt>[]) {
      if (attempt.startedAtMicros != null &&
          (attempt.trackedDurationMicros > 0 || attempt.selfReportedSets > 0)) {
        final at = DateTime.fromMicrosecondsSinceEpoch(attempt.startedAtMicros!,
            isUtc: true);
        if (inWeek(at)) days.add(reportDate(at));
      }
    }
    Widget summary(BuildContext context, int? completed, [int? scheduled]) =>
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(24)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Icon(Icons.bolt_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                  child: Text('This week',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 300 &&
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final training = _metric('${days.length}', 'Training days',
                  Icons.fitness_center_rounded,
                  key: const ValueKey('progress-training-days'));
              final completedMetric = _metric(
                  completed == null
                      ? '—'
                      : scheduled == null
                          ? '$completed'
                          : '$completed / $scheduled',
                  'Scheduled workouts completed',
                  Icons.task_alt_rounded);
              return stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          training,
                          const SizedBox(height: 16),
                          completedMetric
                        ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Expanded(child: training),
                          const SizedBox(width: 16),
                          Expanded(child: completedMetric)
                        ]);
            }),
            const SizedBox(height: 18),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  const Text('Adherence',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(
                      completed == null || scheduled == null || scheduled == 0
                          ? '—'
                          : '${(completed / scheduled * 100).round()}%',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: const Color(0xFF9D71D9),
                    color: Colors.white,
                    value:
                        completed == null || scheduled == null || scheduled == 0
                            ? 0
                            : completed / scheduled)),
            const SizedBox(height: 12),
            const Text('Monday–Sunday · Malaysia time',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (programStatsBuilder != null)
        programStatsBuilder!((context, completed, scheduled) =>
            summary(context, completed, scheduled))
      else if (programBuilder != null)
        programBuilder!((context, completed) => summary(context, completed))
      else ...[
        summary(context, null),
        const SizedBox(height: 12),
        if (program != null) program!
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start workout')),
      if (goals != null) ...[const SizedBox(height: 16), goals!],
      const SizedBox(height: 20),
      const Text('Recent workouts',
          style: TextStyle(
              color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (report.timeline.isEmpty)
        Panel(
            child: Text(routines == null
                ? 'No camera workouts recorded yet. Routine history is unavailable.'
                : 'No workouts recorded yet. Start a workout to see your progress here.')),
      for (final event in report.timeline.take(3))
        _recent(context, report, event),
      const SizedBox(height: 8),
      Text('Explore progress',
          style: const TextStyle(
              color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          _quick('History', Icons.history_rounded, onHistory, width),
          _quick('View reports', Icons.bar_chart_rounded, onReports, width),
          _quick('Estimated Form Scores', Icons.accessibility_new_rounded,
              onForm, width),
          if (onPoints != null)
            _quick('Points & streak', Icons.stars_outlined, onPoints, width),
          if (onBackup != null)
            _quick('Workout backup', Icons.cloud_outlined, onBackup, width),
        ]);
      }),
      const SizedBox(height: 12),
      ExpansionTile(title: const Text('Measurement details'), children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${progress.weeklySessions} camera captures this week'),
                  Text(
                      '${progress.weeklyRepetitions} full reps · ${progress.weeklyPartialRepetitions} partial attempts this week'),
                  Text(
                      'Measurement coverage: ${progress.weeklyCoverage == null ? 'Unavailable' : localProgressCoverage(progress.weeklyCoverage)}'),
                  const Text(
                      'Camera measurements are provisional. Manual sets are self-reported. Tracker versions may differ.'),
                  TextButton(
                      onPressed: onPerformance,
                      child: const Text('Workout performance')),
                ]))
      ]),
    ]);
  }

  Widget _metric(String value, String label, IconData icon, {Key? key}) =>
      Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]);

  Widget _quick(
          String label, IconData icon, VoidCallback? action, double width) =>
      SizedBox(
          width: width,
          child: Material(
              key: ValueKey('progress-quick-$label'),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.hairline)),
              child: InkWell(
                  onTap: action,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, color: AppColors.primary, size: 22),
                            const SizedBox(height: 8),
                            Text(label,
                                style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ])))));
  Widget _recent(BuildContext context, MemberWorkoutReport report,
      WorkoutReportTimelineEntry event) {
    final captures = report.sessions.where((s) => s.sessionId == event.id);
    final attempts = report.routines.where((r) => r.attempt.id == event.id);
    final capture =
        event.sourceLabel == 'Measured AI capture' && captures.isNotEmpty
            ? captures.first
            : null;
    final attempt =
        capture == null && attempts.isNotEmpty ? attempts.first.attempt : null;
    final title =
        capture == null ? event.title : report.exerciseName(capture.exerciseId);
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
            child: InkWell(
                onTap: capture != null && onWorkout != null
                    ? () => onWorkout!(capture)
                    : attempt != null && onRoutine != null
                        ? () => onRoutine!(attempt)
                        : null,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(
                              capture != null
                                  ? Icons.videocam_outlined
                                  : Icons.checklist_rounded,
                              color: AppColors.primary,
                              size: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(event.dateTimeLabel.substring(0, 16),
                                style: const TextStyle(
                                    color: AppColors.inkSoft, fontSize: 12)),
                            const SizedBox(height: 6),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                    capture != null
                                        ? '${capture.repetitions} reps · Measured / provisional'
                                        : '${attempt?.statusLabel ?? 'Saved routine'} · ${attempt?.selfReportedSets ?? 0} self-reported sets',
                                    style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                          ])),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.inkSoft, size: 20),
                    ]))));
  }
}
