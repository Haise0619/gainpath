import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/member_workout_report.dart';
import '../../../../workout/presentation/member/widgets/workout_result_content.dart';

class WorkoutReportOverview extends StatelessWidget {
  const WorkoutReportOverview({super.key, required this.report});
  final MemberWorkoutReport report;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Workout completion',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  report.completedRoutineDays == null
                      ? 'History unavailable'
                      : '${report.completedRoutineDays} completed workouts',
                  style: Theme.of(context).textTheme.titleLarge),
              const Text('Whole routine days within the selected records.'),
            ])),
        const SizedBox(height: 12),
        _mode(
            context,
            'AI Tracked',
            Icons.videocam_outlined,
            [
              WorkoutFact('${report.sessions.length}', 'AI results'),
              WorkoutFact('${report.fullReps}', 'Full reps'),
              WorkoutFact('${report.partialReps}', 'Partial attempts'),
              WorkoutFact(reportDuration(report.trackedMicros), 'Tracked time'),
            ],
            'Repetitions from saved camera results only.'),
        _mode(
            context,
            'Video Timed',
            Icons.timer_outlined,
            [
              WorkoutFact(report.timedSets?.toString() ?? '—', 'Timed sets'),
              WorkoutFact(
                  report.guidedMicros == null
                      ? '—'
                      : reportDuration(report.guidedMicros!),
                  'Active time'),
            ],
            'Timer recorded. Repetitions and form are not assessed.'),
        _mode(
            context,
            'Manual',
            Icons.checklist_rounded,
            [
              WorkoutFact(
                  report.manualSets?.toString() ?? '—', 'User-recorded sets'),
            ],
            'Sets confirmed by you, separate from AI measurements.'),
        const Text(
            'Video and manual totals describe matching workout records, not a per-day activity log.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
      ]);
  Widget _mode(BuildContext context, String title, IconData icon,
          List<Widget> facts, String note) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icon, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)))
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: facts),
                    const SizedBox(height: 8),
                    Text(note,
                        style: const TextStyle(
                            color: AppColors.inkSoft, fontSize: 13)),
                  ])));
}
