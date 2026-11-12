import 'package:flutter/material.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/member_workout_report.dart';
import '../../domain/workout_activity_overview.dart';
import '../../domain/local_member_progress_repository.dart';
import '../../../workout/domain/routine_attempt.dart';
import '../member/widgets/local_progress_widgets.dart';

/// Consumer-grade Member Progress Overview dashboard.
/// Reorganized into 4 distinct, clean sections:
/// 1. Training Consistency (Hero weekly consistency card + active day visualizer + schedule adherence)
/// 2. Training Activity (AI Tracked vs Video Timed vs Manual logs + Activity trends link)
/// 3. AI Form Assessments (Rule-based form estimates for camera-tracked exercises + Estimated Form link)
/// 4. Goals & More (Goals card + Recent workouts + Quick navigation + Progressive disclosure details)
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
      this.startLabel = 'Start workout',
      this.onHistory,
      this.onReports,
      this.onPerformance,
      this.onForm,
      this.onBackup,
      this.onWorkout,
      this.onRoutine});

  final MemberLocalProgress progress;
  final String startLabel;
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
    final days = workoutStartDays(progress, routines?.records ?? const []);

    // Guided & Manual stats from routines
    final guidedMicros = (routines?.records ?? const [])
        .fold<int>(0, (sum, r) => sum + r.guidedDurationMicros);
    final guidedSets = (routines?.records ?? const []).fold<int>(
        0,
        (sum, r) =>
            sum +
            r.entries
                .fold<int>(0, (s2, e) => s2 + (e.guided?.completedSets ?? 0)));
    final manualSets = (routines?.records ?? const [])
        .fold<int>(0, (sum, r) => sum + r.selfReportedSets);

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
              final stacked = constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final training = _metric('${days.length}', 'Workout start days',
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
                  const Text('Scheduled completion',
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
                            : (completed / scheduled).clamp(0.0, 1.0))),
            const SizedBox(height: 16),
            _buildWeekDaysVisualizer(progress, days),
            const SizedBox(height: 12),
            const Text('Monday–Sunday · Malaysia time · full-week schedule',
                style: TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ---------------------------------------------------------
      // SECTION 1: Training Consistency
      // ---------------------------------------------------------
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
          label: Text(startLabel)),

      // ---------------------------------------------------------
      // SECTION 2: Training Activity
      // ---------------------------------------------------------
      const SizedBox(height: 24),
      const Text('Training activity',
          style: TextStyle(
              color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text(
          'Breakdown of camera-tracked, video-guided, and manual workouts',
          style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final isNarrow = constraints.maxWidth < 450 || scale > 1.25;
        final cardWidth =
            isNarrow ? constraints.maxWidth : (constraints.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _activityCard(
              title: 'AI Tracked',
              primaryStat: '${progress.weeklyRepetitions} reps',
              secondaryStat:
                  '${progress.weeklySessions} sessions · ${progress.weeklyPartialRepetitions} partial',
              icon: Icons.videocam_rounded,
              tintColor: AppColors.primary,
              width: cardWidth,
            ),
            _activityCard(
              title: 'Video Timed',
              primaryStat:
                  guidedMicros > 0 ? reportDuration(guidedMicros) : '0 min',
              secondaryStat: guidedSets > 0
                  ? '$guidedSets sets completed'
                  : 'No timed sessions',
              icon: Icons.timer_rounded,
              tintColor: const Color(0xFFE67E22),
              width: cardWidth,
            ),
            _activityCard(
              title: 'Manual Logs',
              primaryStat: manualSets > 0 ? '$manualSets sets' : '0 sets',
              secondaryStat:
                  manualSets > 0 ? 'Self-reported' : 'No manual logs',
              icon: Icons.edit_note_rounded,
              tintColor: const Color(0xFF2980B9),
              width: cardWidth,
            ),
          ],
        );
      }),
      const SizedBox(height: 10),
      _quick('Activity trends', Icons.insights_outlined, onPerformance,
          double.infinity),

      // ---------------------------------------------------------
      // SECTION 3: AI Form Assessments
      // ---------------------------------------------------------
      const SizedBox(height: 24),
      const Text('AI Form Assessments',
          style: TextStyle(
              color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text('Rule-based form estimates for camera-tracked exercises',
          style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
      const SizedBox(height: 12),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _formExerciseRow('Squat', _latestRecord(progress, 'squat'), true,
            Icons.fitness_center_rounded),
        const Divider(height: 16, color: AppColors.hairline),
        _formExerciseRow('Biceps Curl', _latestRecord(progress, 'curl'), true,
            Icons.fitness_center_rounded),
        const Divider(height: 16, color: AppColors.hairline),
        _formExerciseRow('Calf Raise', _latestRecord(progress, 'calf'), true,
            Icons.fitness_center_rounded),
        const Divider(height: 16, color: AppColors.hairline),
        _formExerciseRow(
            'Floor Push-Up',
            _latestRecord(progress, 'push-up') ??
                _latestRecord(progress, 'push_up'),
            true,
            Icons.fitness_center_rounded),
        const Divider(height: 16, color: AppColors.hairline),
        _formExerciseRow('Standing Lateral Raise', null, false,
            Icons.accessibility_new_rounded),
        const Divider(height: 16, color: AppColors.hairline),
        _formExerciseRow('Dumbbell Shoulder Press', null, false,
            Icons.accessibility_new_rounded),
        const SizedBox(height: 12),
        _quick('Estimated Form Scores', Icons.accessibility_new_rounded, onForm,
            double.infinity),
      ])),

      // ---------------------------------------------------------
      // SECTION 4: Goals & More
      // ---------------------------------------------------------
      const SizedBox(height: 24),
      const Text('Goals & history',
          style: TextStyle(
              color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (goals != null) ...[goals!, const SizedBox(height: 16)],
      const Text('Recent workouts',
          style: TextStyle(
              color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      if (report.timeline.isEmpty)
        Panel(
            child: Text(routines == null
                ? 'No camera workouts recorded yet. Routine history is unavailable.'
                : 'No workouts recorded yet. Start a workout to see your progress here.'))
      else
        for (final event in overviewWorkoutEvents(report).take(3))
          _recent(context, report, event),
      const SizedBox(height: 16),
      const Text('Explore more',
          style: TextStyle(
              color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth >= 520
            ? 3
            : (constraints.maxWidth < 340 || scale > 1.3 ? 1 : 2);
        final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          _quick('History', Icons.history_rounded, onHistory, width),
          _quick('Training Report', Icons.bar_chart_rounded, onReports, width),
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
                  const Text(
                      'Workout start days use saved start dates. Linked AI results count with their workout, not as another workout day.'),
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

  Widget _buildWeekDaysVisualizer(
      MemberLocalProgress progress, Set<String> activeDates) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayStr = reportDate(progress.asOf);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final dayDate = progress.weekStart.add(Duration(days: index));
          final dateKey = reportDate(dayDate);
          final isActive = activeDates.contains(dateKey);
          final isToday = dateKey == todayStr;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? Colors.white : Colors.transparent,
                  border: Border.all(
                    color: isToday
                        ? Colors.white
                        : (isActive ? Colors.white : const Color(0x55FFFFFF)),
                    width: isToday && !isActive ? 2 : 1.5,
                  ),
                ),
                child: Center(
                  child: isActive
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: AppColors.primaryDark)
                      : Text(
                          dayLabels[index],
                          textScaler: const TextScaler.linear(1.0),
                          style: TextStyle(
                            color: isToday
                                ? Colors.white
                                : const Color(0xCCFFFFFF),
                            fontSize: 11,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dayLabels[index],
                textScaler: const TextScaler.linear(1.0),
                style: TextStyle(
                  color: isToday ? Colors.white : const Color(0x99FFFFFF),
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _activityCard({
    required String title,
    required String primaryStat,
    required String secondaryStat,
    required IconData icon,
    required Color tintColor,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tintColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: tintColor, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              primaryStat,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              secondaryStat,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static LocalWorkoutProgressRecord? _latestRecord(
      MemberLocalProgress progress, String keyword) {
    final matches = progress.records
        .where((r) => r.exerciseId.toLowerCase().contains(keyword));
    return matches.isEmpty ? null : matches.first;
  }

  Widget _formExerciseRow(String name, LocalWorkoutProgressRecord? record,
      bool available, IconData icon) {
    final scoreText = record?.formScorePercent != null
        ? '${record!.formScorePercent!.round()}/100'
        : null;
    return InkWell(
      onTap:
          record != null && onWorkout != null ? () => onWorkout!(record) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    available ? AppColors.primaryTint : const Color(0xFFF1F2F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: available ? AppColors.primary : AppColors.inkSoft,
                  size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    available
                        ? (scoreText != null
                            ? 'Estimated Form: $scoreText'
                            : 'No sessions yet')
                        : 'Assessment unavailable (rules pending)',
                    style: TextStyle(
                      color: available && scoreText != null
                          ? AppColors.primaryDark
                          : AppColors.inkSoft,
                      fontSize: 12,
                      fontWeight: available && scoreText != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (available && scoreText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  scoreText,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (record != null && onWorkout != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.inkSoft, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quick(
      String label, IconData icon, VoidCallback? action, double width) {
    final isFullWidth = width.isInfinite || width > 260;
    return SizedBox(
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
                    child: isFullWidth
                        ? Row(children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon,
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(label,
                                  style: const TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkSoft, size: 18),
                          ])
                        : Column(
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
  }

  Widget _recent(BuildContext context, MemberWorkoutReport report,
      WorkoutReportTimelineEntry event) {
    final captures = report.sessions.where((s) => s.sessionId == event.id);
    final attempts = report.routines.where((r) => r.attempt.id == event.id);
    final capture =
        event.kind == WorkoutTimelineKind.aiCapture && captures.isNotEmpty
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
                                        ? '${capture.repetitions} full reps · AI Tracked'
                                        : attempt == null
                                            ? 'Saved workout'
                                            : routineActivitySummary(attempt),
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
