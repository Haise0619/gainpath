import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/member_workout_report.dart';

/// Camera repetitions, timed work and self-reported sets remain separate.
class WorkoutReportOverview extends StatelessWidget {
  const WorkoutReportOverview({super.key, required this.report});
  final MemberWorkoutReport report;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.task_alt_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Completed workouts',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(report.completedRoutineDays?.toString() ?? 'Unavailable',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ])),
          IconButton(
              tooltip: 'How completed workouts are counted',
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                          title: const Text('Completed workouts'),
                          content: const Text(
                              'Counts completed workout sessions. Multiple workouts on the same day are counted separately. An exercise filter selects matching workout records; completion still requires the whole workout’s targets.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Got it'))
                          ])),
              icon: const Icon(Icons.info_outline_rounded)),
        ]),
        const Divider(height: 24, thickness: 1, color: AppColors.hairline),
        _mode(
            context,
            'AI Tracked',
            Icons.videocam_outlined,
            '${report.fullReps} full reps · ${report.partialReps} partial attempts',
            '${report.sessions.length} AI results · ${reportDuration(report.trackedMicros)} tracked'),
        const SizedBox(height: 16),
        _mode(
            context,
            'Video Timed',
            Icons.timer_outlined,
            report.timedSets == null
                ? 'Unavailable'
                : '${report.timedSets} timed sets',
            report.guidedMicros == null
                ? 'History unavailable'
                : '${reportDuration(report.guidedMicros!)} active · timer recorded'),
        const SizedBox(height: 16),
        _mode(
            context,
            'Manual',
            Icons.checklist_rounded,
            report.manualSets == null
                ? 'Unavailable'
                : '${report.manualSets} user-recorded sets',
            'Self-reported activity'),
      ]));
  Widget _mode(BuildContext context, String title, IconData icon, String value,
          String detail) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary, size: 20)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(value),
          Text(detail,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkSoft, fontSize: 13)),
        ])),
      ]);
}
