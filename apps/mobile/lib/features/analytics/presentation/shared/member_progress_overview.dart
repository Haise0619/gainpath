import 'package:flutter/material.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/member_workout_report.dart';
import '../../domain/workout_activity_overview.dart';
import '../../../workout/domain/routine_attempt.dart';
import 'progress_dashboard_data.dart';
import 'progress_dashboard_details.dart';

/// Read-only dashboard. All actions retain their account-owned destinations.
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
      this.startLabel = 'Training plan',
      this.onHistory,
      this.onReports,
      this.onPerformance,
      this.onForm,
      this.onBackup,
      this.onWorkout,
      this.onRoutine,
      this.onAssessments});
  final MemberLocalProgress progress;
  final RoutineProgress? routines;
  final Widget? program, goals;
  final Widget Function(Widget Function(BuildContext, int?))? programBuilder;
  final Widget Function(Widget Function(BuildContext, int?, int?))?
      programStatsBuilder;
  final String startLabel;
  final VoidCallback? onStart,
      onHistory,
      onReports,
      onPerformance,
      onForm,
      onBackup;
  final VoidCallback? onAssessments;
  final ValueChanged<LocalWorkoutProgressRecord>? onWorkout;
  final ValueChanged<RoutineAttempt>? onRoutine;

  @override
  Widget build(BuildContext context) {
    final data = ProgressDashboardData(progress, routines);
    final days = workoutStartDays(progress, routines?.records ?? const []);
    final latest = overviewWorkoutEvents(data.report).firstOrNull;
    Widget summary(BuildContext c, int? done, [int? total]) =>
        _weekly(c, days, done, total);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (programStatsBuilder != null)
        programStatsBuilder!((c, d, t) => summary(c, d, t))
      else if (programBuilder != null)
        programBuilder!((c, d) => summary(c, d))
      else
        summary(context, null),
      const SizedBox(height: 20),
      progressHeading('Training activity'),
      const SizedBox(height: 4),
      Text('${progressWeekLabel(progress)} · Malaysia time',
          style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
      const SizedBox(height: 10),
      _activity(data),
      _action('View Activity Trends', onPerformance),
      const SizedBox(height: 12),
      progressHeading('AI Form Assessments'),
      const SizedBox(height: 4),
      const Text('Latest scored sessions',
          style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
      const SizedBox(height: 10),
      if (data.assessments.isEmpty)
        _empty(
            Icons.accessibility_new_rounded,
            data.report.sessions.isEmpty
                ? 'Complete a camera workout to see your form.'
                : 'Your sessions are saved. No scored assessments yet.')
      else
        progressSurface(Column(children: [
          for (var i = 0; i < data.assessments.take(3).length; i++) ...[
            if (i > 0) const Divider(height: 20, color: AppColors.hairline),
            ProgressAssessmentRow(
                assessment: data.assessments[i],
                report: data.report,
                onOpen: onWorkout),
          ],
        ])),
      _action(
          'View All Assessments',
          onAssessments ??
              () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => ProgressAssessmentsScreen(
                          data: data, onOpen: onWorkout, onTrends: onForm)))),
      const SizedBox(height: 12),
      if (goals != null)
        goals!
      else
        progressSurface(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          progressHeading('Goals'),
          const SizedBox(height: 6),
          const Text('Set personal targets in your fitness profile.',
              style: TextStyle(color: AppColors.inkSoft)),
        ])),
      const SizedBox(height: 20),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            progressHeading('Latest workout'),
            TextButton(onPressed: onHistory, child: const Text('View History'))
          ]),
      const SizedBox(height: 6),
      if (latest == null)
        _empty(Icons.fitness_center_rounded,
            'Your next workout starts your story.')
      else
        _latest(data.report, latest),
    ]);
  }

  Widget _weekly(
      BuildContext context, Set<String> days, int? done, int? total) {
    final scheduled = done != null && total != null && total > 0;
    final openPlan = onStart ??
        (program == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Training plan')),
                        body: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: program!)))));
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text('This week',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                if (openPlan != null)
                  TextButton(
                      onPressed: openPlan,
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('Training plan  ›')),
              ]),
          const SizedBox(height: 6),
          Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${days.length} ',
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w800)),
                TextSpan(
                    text: days.length == 1 ? 'training day' : 'training days',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ]),
              key: const ValueKey('progress-training-days'),
              style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          Row(
              children: List.generate(7, (i) {
            final date = reportDate(progress.weekStart.add(Duration(days: i)));
            final active = days.contains(date),
                today = date == reportDate(progress.asOf);
            return Expanded(
                child: Semantics(
                    label:
                        '$date${today ? ', today' : ''}, ${active ? 'workout recorded' : 'no workout recorded'}',
                    child: ExcludeSemantics(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active ? Colors.white : Colors.transparent,
                              border: Border.all(
                                  color: today || active
                                      ? Colors.white
                                      : const Color(0x88FFFFFF),
                                  width: today ? 2 : 1)),
                          child: active
                              ? const Icon(Icons.check_rounded,
                                  size: 16, color: AppColors.primaryDark)
                              : null),
                    ]))));
          })),
          if (scheduled) ...[
            const SizedBox(height: 16),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text('$done / $total planned workouts',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                  Text('${(done / total * 100).round()}%',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    minHeight: 4,
                    value: (done / total).clamp(0, 1),
                    color: Colors.white,
                    backgroundColor: const Color(0x557D52B8))),
          ],
        ]));
  }

  Widget _activity(ProgressDashboardData data) {
    final w = data.weekly;
    final active = w.fullReps > 0 ||
        w.trackedMicros > 0 ||
        (w.guidedMicros ?? 0) > 0 ||
        (w.manualSets ?? 0) > 0;
    return progressSurface(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!active)
        const Text('No workouts recorded this week.',
            style: TextStyle(color: AppColors.inkSoft)),
      if (w.fullReps > 0 || w.trackedMicros > 0)
        _activityRow(Icons.videocam_outlined, 'AI repetitions',
            '${w.fullReps} reps', AppColors.primary),
      if ((w.guidedMicros ?? 0) > 0)
        _activityRow(Icons.timer_outlined, 'Video Timed',
            reportDuration(w.guidedMicros!), const Color(0xFFA8500A)),
      if ((w.manualSets ?? 0) > 0)
        _activityRow(Icons.edit_note_rounded, 'Manual Sets',
            '${w.manualSets} sets', const Color(0xFF1E6B99)),
      if (!w.routineHistoryAvailable) ...[
        const SizedBox(height: 6),
        const Text('Video and manual history unavailable.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13))
      ],
    ]));
  }

  Widget _activityRow(IconData icon, String title, String value, Color color) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                  Text(title,
                      style:
                          const TextStyle(color: AppColors.ink, fontSize: 15)),
                  Text(value,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ])),
          ]));
  Widget _action(String label, VoidCallback? action) => Align(
      alignment: Alignment.centerRight,
      child: TextButton(onPressed: action, child: Text(label)));
  Widget _empty(IconData icon, String text) => progressSurface(
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style:
                    const TextStyle(color: AppColors.inkSoft, fontSize: 14))),
      ]));

  Widget _latest(MemberWorkoutReport report, WorkoutReportTimelineEntry event) {
    final capture = event.kind == WorkoutTimelineKind.aiCapture
        ? report.sessions.where((r) => r.sessionId == event.id).firstOrNull
        : null;
    final attempt = event.kind == WorkoutTimelineKind.routine
        ? report.routines
            .where((r) => r.attempt.id == event.id)
            .firstOrNull
            ?.attempt
        : null;
    final action = capture != null && onWorkout != null
        ? () => onWorkout!(capture)
        : attempt != null && onRoutine != null
            ? () => onRoutine!(attempt)
            : null;
    return progressSurface(InkWell(
        key: const Key('progress-latest-workout'),
        onTap: action,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.fitness_center_rounded,
                  color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(event.title,
                        style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${event.dateTimeLabel.substring(0, 16)} MYT',
                        style: const TextStyle(
                            color: AppColors.inkSoft, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                        capture != null
                            ? '${capture.repetitions} full reps · AI Tracked'
                            : attempt != null
                                ? routineActivitySummary(attempt)
                                : 'Saved workout',
                        style: const TextStyle(
                            color: AppColors.inkSoft, fontSize: 14)),
                  ])),
              if (action != null)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary),
            ]))));
  }
}

Widget progressHeading(String text) => Semantics(
    header: true,
    child: Text(text,
        style: const TextStyle(
            color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w700)));
Widget progressSurface(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline)),
    child: child);
String progressWeekLabel(MemberLocalProgress progress) {
  final start = progress.weekStart.add(progress.utcOffset),
      end = progress.weekStart
          .add(progress.utcOffset)
          .add(const Duration(days: 6));
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${start.day}${start.month != end.month ? ' ${months[start.month - 1]}' : ''}–${end.day} ${months[end.month - 1]}';
}
