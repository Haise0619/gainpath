import 'package:flutter/material.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/member_workout_report.dart';
import '../member/widgets/local_progress_widgets.dart';
import 'progress_dashboard_data.dart';
import 'member_progress_overview.dart' show progressSurface, progressWeekLabel;

class ProgressAssessmentRow extends StatelessWidget {
  const ProgressAssessmentRow(
      {super.key, required this.assessment, required this.report, this.onOpen});
  final ProgressAssessment assessment;
  final MemberWorkoutReport report;
  final ValueChanged<LocalWorkoutProgressRecord>? onOpen;
  @override
  Widget build(BuildContext context) {
    final latest = assessment.latest, change = assessment.change;
    final score = latest.formScorePercent!;
    return InkWell(
        onTap: onOpen == null ? null : () => onOpen!(latest),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.accessibility_new_rounded,
                      size: 22, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(report.exerciseName(latest.exerciseId),
                              style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              '${score == score.roundToDouble() ? score.toInt() : score.toStringAsFixed(1)}/100',
                              style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                        ]),
                    const SizedBox(height: 4),
                    Text('${reportDate(latest.endedAt)} · Estimated form',
                        style: const TextStyle(
                            color: AppColors.inkSoft, fontSize: 13)),
                    if (change != null) ...[
                      const SizedBox(height: 4),
                      Text(
                          '${change >= 0 ? '+' : ''}${change == change.roundToDouble() ? change.toInt() : change.toStringAsFixed(1)} points vs previous assessment',
                          style: const TextStyle(
                              color: AppColors.primaryDark, fontSize: 13))
                    ],
                  ])),
              if (onOpen != null)
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary, size: 20),
            ])));
  }
}

/// Full list is secondary; scoreless records remain discoverable and tappable.
class ProgressAssessmentsScreen extends StatelessWidget {
  const ProgressAssessmentsScreen(
      {super.key, required this.data, this.onOpen, this.onTrends});
  final ProgressDashboardData data;
  final ValueChanged<LocalWorkoutProgressRecord>? onOpen;
  final VoidCallback? onTrends;
  @override
  Widget build(BuildContext context) {
    final latest = <String, LocalWorkoutProgressRecord>{};
    for (final record in data.report.sessions) {
      latest.putIfAbsent(record.exerciseId, () => record);
    }
    final assessed = {for (final a in data.assessments) a.latest.exerciseId: a};
    const known = <String, (String, List<String>)>{
      'Squat': (
        'squat',
        ['squat', 'F3b8xIr8ynBDd3gEICKX', 'bodyweight-squat-side-v1']
      ),
      'Biceps Curl': ('curl', ['curl', 'standing-single-arm-curl-side-v1']),
      'Calf Raise': ('calf', ['calf', 'standing-calf-raise-side-v1']),
      'Floor Push-Up': (
        'push',
        ['push-up', 'push_up', 'standard-floor-push-up-side-v1']
      ),
      'Lateral Raise': (
        'standing-lateral-raise-front-v1',
        ['standing-lateral-raise-front-v1']
      ),
      'Shoulder Press': (
        'dumbbell-shoulder-press-front-v1',
        ['dumbbell-shoulder-press-front-v1']
      ),
    };
    final missing = known.entries.where((entry) => !latest.values.any((r) =>
        entry.value.$2.contains(r.exerciseId) ||
        r.scoringVersion.contains(entry.value.$1)));
    return Scaffold(
        appBar: AppBar(title: const Text('All assessments')),
        body: PageBody(children: [
          const Text('Latest saved results · All time',
              style: TextStyle(color: AppColors.inkSoft)),
          if (onTrends != null)
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: onTrends,
                    child: const Text('View Form Trends'))),
          for (final record in latest.values)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: progressSurface(assessed[record.exerciseId] != null
                    ? ProgressAssessmentRow(
                        assessment: assessed[record.exerciseId]!,
                        report: data.report,
                        onOpen: onOpen)
                    : _unscored(
                        data.report.exerciseName(record.exerciseId),
                        formScoringUnsupported(record.scoringVersion)
                            ? 'Form scoring not available'
                            : 'Session saved · no form score',
                        record))),
          for (final entry in missing)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: progressSurface(_unscored(
                    entry.key,
                    formScoringUnsupported(entry.value.$1)
                        ? 'Form scoring not available'
                        : 'No sessions yet',
                    null))),
          const SizedBox(height: 6),
          const Text(
              'Form scores are estimates. Comparisons use matching exercise, tracker and camera settings.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
        ]));
  }

  Widget _unscored(
          String title, String status, LocalWorkoutProgressRecord? record) =>
      InkWell(
          onTap:
              record == null || onOpen == null ? null : () => onOpen!(record),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(status,
                          style: const TextStyle(
                              color: AppColors.inkSoft, fontSize: 14)),
                    ])),
                if (record != null && onOpen != null)
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary),
              ])));
}

class ProgressMeasurementScreen extends StatelessWidget {
  const ProgressMeasurementScreen({super.key, required this.progress});
  final MemberLocalProgress progress;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Measurement details')),
      body: PageBody(children: [
        Text('${progressWeekLabel(progress)} · Malaysia time',
            style: const TextStyle(color: AppColors.inkSoft)),
        const SizedBox(height: 16),
        progressSurface(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${progress.weeklySessions} camera captures this week'),
          const SizedBox(height: 8),
          Text(
              '${progress.weeklyRepetitions} full reps · ${progress.weeklyPartialRepetitions} partial attempts this week'),
          const SizedBox(height: 8),
          Text(
              'Measurement coverage: ${progress.weeklyCoverage == null ? 'Unavailable' : localProgressCoverage(progress.weeklyCoverage)}'),
        ])),
        const SizedBox(height: 16),
        const Text(
            'Training days use saved workout start dates. Linked camera results count with their workout, not as another training day.'),
        const SizedBox(height: 12),
        const Text(
            'Activity totals use the Malaysia Monday–Sunday week: camera sessions by end date; timed and manual workouts by saved finish date, or last update when unfinished. Workouts spanning weeks are not split.'),
        const SizedBox(height: 12),
        const Text(
            'Camera measurements are provisional. Manual sets are self-reported. Tracker versions may differ.'),
        const SizedBox(height: 12),
        const Text(
            'Form scores use the latest valid recorded assessment for each exercise. Changes compare earlier scored sessions only when exercise, scoring rules, detector, camera view and arm mode match. They do not establish physical accuracy or fitness gains.'),
        const SizedBox(height: 12),
        const Text(
            'Goal calculations retain their saved target definitions. Training-frequency goals use Monday–Sunday UTC; the activity dashboard uses Malaysia time.'),
      ]));
}
