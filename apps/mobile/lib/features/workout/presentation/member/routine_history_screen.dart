import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/routine_attempt.dart';

String _date(int micros) {
  final d = DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true)
      .add(const Duration(hours: 8));
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} MYT';
}

String _duration(int micros) {
  final seconds = micros ~/ 1000000;
  return seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m ${seconds % 60}s';
}

class RoutineHistoryScreen extends StatelessWidget {
  const RoutineHistoryScreen(
      {super.key,
      required this.attempts,
      required this.onOpenAttempt,
      this.onRefresh,
      this.onOpenBackup,
      this.available = true});
  final List<RoutineAttempt> attempts;
  final void Function(RoutineAttempt) onOpenAttempt;
  final Future<void> Function()? onRefresh;
  final bool available;
  final VoidCallback? onOpenBackup;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Routine history'), actions: [
        if (onOpenBackup != null)
          IconButton(
              tooltip: 'Workout backup',
              onPressed: onOpenBackup,
              icon: const Icon(Icons.cloud_upload_outlined)),
        if (onRefresh != null)
          IconButton(
              tooltip: 'Refresh',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded))
      ]),
      body: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          child: ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const Text(
                    'Saved on this device · each entry is one routine-day attempt.'),
                const SizedBox(height: 12),
                if (!available)
                  const Panel(
                      child: Text(
                          'Routine history is unavailable. Refresh to retry.'))
                else if (attempts.isEmpty)
                  const Panel(
                      child: Text(
                          'No routine attempts yet. Start a routine to record your progress.')),
                for (final a in attempts)
                  Card(
                      child: ListTile(
                          leading: Icon(
                              a.isComplete
                                  ? Icons.check_circle_rounded
                                  : Icons.timelapse_rounded,
                              color: AppColors.primary),
                          title: Text('${a.routine.title} · Day ${a.day}'),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.statusLabel),
                                Text(
                                    '${a.completedExercises}/${a.entries.length} exercises'),
                                Text(_date(
                                    a.finishedAtMicros ?? a.updatedAtMicros)),
                              ]),
                          onTap: () => onOpenAttempt(a))),
              ])));
}

class RoutineAttemptDetailScreen extends StatelessWidget {
  const RoutineAttemptDetailScreen(
      {super.key,
      required this.attempt,
      this.onResume,
      this.onRepeat,
      this.onNextDay,
      this.onViewProgress});
  final RoutineAttempt attempt;
  final VoidCallback? onResume, onRepeat, onNextDay, onViewProgress;
  @override
  Widget build(BuildContext context) {
    final a = attempt;
    return Scaffold(
        appBar: AppBar(title: const Text('Routine result')),
        body: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              Text('${a.routine.title} · Day ${a.day}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(a.statusLabel,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.primary)),
              Text(
                  '${a.completedExercises}/${a.entries.length} exercises completed'),
              const SizedBox(height: 12),
              Panel(
                  background: AppColors.primaryTint,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${a.fullRepetitions} measured full reps · ${a.partialRepetitions} partial reps'),
                        Text(
                            '${_duration(a.trackedDurationMicros)} camera-tracked'),
                        Text(
                            '${a.selfReportedSets} self-reported sets · no AI measurements'),
                        if (a.startedAtMicros != null)
                          Text('Started ${_date(a.startedAtMicros!)}'),
                        if (a.finishedAtMicros != null)
                          Text('Ended ${_date(a.finishedAtMicros!)}'),
                        if (a.elapsedDurationMicros != null)
                          Text(
                              '${_duration(a.elapsedDurationMicros!)} elapsed · includes breaks and time away'),
                        if (a.finished && a.finishedAtMicros == null)
                          const Text(
                              'Completion time unavailable for this older attempt.'),
                      ])),
              const SizedBox(height: 16),
              for (final result in a.entries)
                _ExerciseResult(attempt: a, result: result),
              const SizedBox(height: 12),
              if (!a.isComplete && onResume != null)
                FilledButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume unfinished exercises')),
              if (a.isComplete && onNextDay != null)
                FilledButton.icon(
                    onPressed: onNextDay,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next routine day')),
              if (onViewProgress != null)
                OutlinedButton(
                    onPressed: onViewProgress,
                    child: const Text('View progress')),
              if (onRepeat != null)
                OutlinedButton(
                    onPressed: onRepeat,
                    child: const Text('Repeat this workout')),
            ]));
  }
}

class _ExerciseResult extends StatelessWidget {
  const _ExerciseResult({required this.attempt, required this.result});
  final RoutineAttempt attempt;
  final RoutineExerciseResult result;
  @override
  Widget build(BuildContext context) {
    final e = attempt.routine.exercises[result.index];
    final label = switch (result.status) {
      RoutineExerciseStatus.completed => 'Measured target complete',
      RoutineExerciseStatus.selfReportedCompleted => 'Self-reported complete',
      RoutineExerciseStatus.partial => 'Measured partial result',
      RoutineExerciseStatus.selfReportedPartial => 'Self-reported partial',
      RoutineExerciseStatus.skipped => 'Skipped',
      RoutineExerciseStatus.instructionsReviewed => 'Instructions reviewed',
      RoutineExerciseStatus.notStarted => 'Not started',
    };
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: Theme.of(context).textTheme.titleMedium),
              Text('Target: ${e.sets} sets × ${e.reps} reps'),
              Text(label),
              if (result.sessionIds.isNotEmpty)
                Text(
                    '${result.fullRepetitions} full · ${result.partialRepetitions} partial · ${_duration(result.trackedDurationMicros)} tracked'),
              if (result.manualSets > 0)
                Text('${result.manualSets}/${e.sets} sets self-reported'),
            ])));
  }
}
