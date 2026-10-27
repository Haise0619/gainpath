import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../workout/domain/routine_attempt.dart';

class RoutineProgressCard extends StatelessWidget {
  const RoutineProgressCard(
      {super.key,
      required this.progress,
      this.onOpenHistory,
      this.onOpenAttempt});
  final RoutineProgress? progress;
  final VoidCallback? onOpenHistory;
  final void Function(RoutineAttempt)? onOpenAttempt;
  @override
  Widget build(BuildContext context) => Panel(
      background: AppColors.primaryTint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            progress == null
                ? 'Routine progress unavailable'
                : '${progress!.weeklyCompleted} routine day${progress!.weeklyCompleted == 1 ? '' : 's'} completed this week',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
            'Completed targets · measured and self-reported activity stay separate.'),
        if (progress != null) ...[
          for (final a in progress!.records.take(3))
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${a.routine.title} · Day ${a.day}'),
                subtitle: Text(
                    '${a.statusLabel} · ${a.completedExercises}/${a.entries.length} exercises'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onOpenAttempt == null
                    ? onOpenHistory
                    : () => onOpenAttempt!(a)),
          if (progress!.records.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Your routine attempts will appear here.')),
        ],
        TextButton.icon(
            onPressed: onOpenHistory,
            icon: const Icon(Icons.history_rounded),
            label: const Text('Routine history')),
      ]));
}
