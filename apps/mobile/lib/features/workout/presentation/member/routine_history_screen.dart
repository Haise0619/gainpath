import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/routine_attempt.dart';
import '../workout_presentation.dart';

String _date(int micros) {
  final d = DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true)
      .add(const Duration(hours: 8));
  return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} MYT';
}

enum _HistoryFilter { all, completed, unfinished }

class RoutineHistoryScreen extends StatefulWidget {
  const RoutineHistoryScreen(
      {super.key,
      required this.attempts,
      required this.onOpenAttempt,
      this.onRefresh,
      this.onOpenBackup,
      this.embedded = false,
      this.available = true});
  final List<RoutineAttempt> attempts;
  final void Function(RoutineAttempt) onOpenAttempt;
  final Future<void> Function()? onRefresh;
  final bool available;
  final bool embedded;
  final VoidCallback? onOpenBackup;

  @override
  State<RoutineHistoryScreen> createState() => _RoutineHistoryScreenState();
}

class _RoutineHistoryScreenState extends State<RoutineHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final attempts = widget.attempts
        .where((attempt) => switch (_filter) {
              _HistoryFilter.all => true,
              _HistoryFilter.completed => attempt.isComplete,
              _HistoryFilter.unfinished => !attempt.isComplete,
            })
        .toList()
      ..sort((a, b) => (b.finishedAtMicros ?? b.updatedAtMicros)
          .compareTo(a.finishedAtMicros ?? a.updatedAtMicros));
    return Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(title: const Text('Routine history'), actions: [
                if (widget.onOpenBackup != null)
                  IconButton(
                      tooltip: 'Workout backup',
                      onPressed: widget.onOpenBackup,
                      icon: const Icon(Icons.cloud_upload_outlined)),
                if (widget.onRefresh != null)
                  IconButton(
                      tooltip: 'Refresh',
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh_rounded))
              ]),
        body: RefreshIndicator(
            onRefresh: widget.onRefresh ?? () async {},
            child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (!widget.available)
                    const Panel(
                        child: Text(
                            'Routine history is unavailable. Refresh to retry.'))
                  else if (widget.attempts.isEmpty)
                    const Panel(
                        child: Text(
                            'No routine attempts yet. Start a routine to record your progress.'))
                  else ...[
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      for (final filter in _HistoryFilter.values)
                        ChoiceChip(
                            label: Text(switch (filter) {
                              _HistoryFilter.all => 'All',
                              _HistoryFilter.completed => 'Completed',
                              _HistoryFilter.unfinished => 'Unfinished',
                            }),
                            selected: _filter == filter,
                            onSelected: (_) =>
                                setState(() => _filter = filter)),
                    ]),
                    const SizedBox(height: 8),
                    if (attempts.isEmpty)
                      const Panel(
                          child: Text('No attempts match this filter.')),
                  ],
                  for (final a
                      in widget.available ? attempts : <RoutineAttempt>[])
                    Card(
                        child: ListTile(
                            leading: Icon(
                                a.isComplete
                                    ? Icons.check_circle_rounded
                                    : Icons.timelapse_rounded,
                                color: AppColors.primary),
                            title: Text(routineDayTitle(a.routine, a.day)),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(workoutAttemptLabel(a)),
                                  Text(
                                      '${a.completedExercises}/${a.entries.length} exercises'),
                                  Text(_date(
                                      a.finishedAtMicros ?? a.updatedAtMicros)),
                                ]),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => widget.onOpenAttempt(a))),
                ])));
  }
}

class RoutineAttemptDetailScreen extends StatelessWidget {
  const RoutineAttemptDetailScreen(
      {super.key,
      required this.attempt,
      this.trainingSource,
      this.saveStatus,
      this.onResume,
      this.onRepeat,
      this.onNextDay,
      this.availableSessionIds = const {},
      this.onOpenSession});
  final RoutineAttempt attempt;
  final String? trainingSource;
  final Widget? saveStatus;
  final VoidCallback? onResume, onRepeat, onNextDay;
  final Set<String> availableSessionIds;
  final ValueChanged<String>? onOpenSession;
  @override
  Widget build(BuildContext context) {
    final a = attempt;
    final repeatIsPrimary = a.isComplete && onNextDay == null;
    return Scaffold(
        appBar: AppBar(title: const Text('Routine result')),
        bottomNavigationBar: (!a.isComplete && onResume != null ||
                a.isComplete && (onNextDay != null || onRepeat != null))
            ? SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!a.isComplete && onResume != null)
                            FilledButton.icon(
                                onPressed: onResume,
                                icon: const Icon(Icons.play_arrow_rounded),
                                label:
                                    const Text('Resume unfinished exercises')),
                          if (a.isComplete && onNextDay != null)
                            FilledButton.icon(
                                onPressed: onNextDay,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('Next routine day')),
                          if (repeatIsPrimary && onRepeat != null)
                            FilledButton.icon(
                                onPressed: onRepeat,
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text('Repeat this workout')),
                        ])))
            : null,
        body: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              Text(routineDayTitle(a.routine, a.day),
                  style: Theme.of(context).textTheme.headlineSmall),
              if (trainingSource != null) Text(trainingSource!),
              const SizedBox(height: 8),
              Text(workoutAttemptLabel(a),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.primary)),
              Text(
                  '${a.completedExercises}/${a.entries.length} exercises completed'),
              const SizedBox(height: 6),
              saveStatus ?? const Text('Saved on this device'),
              const SizedBox(height: 12),
              Panel(
                  background: AppColors.primaryTint,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (a.entries.any((r) => r.sessionIds.isNotEmpty)) ...[
                          Text(
                              '${a.fullRepetitions} measured full reps · ${a.partialRepetitions} partial reps'),
                          Text(
                              '${workoutDurationLabel(a.trackedDurationMicros)} camera-tracked'),
                        ],
                        if (a.selfReportedSets > 0)
                          Text('${a.selfReportedSets} self-reported sets'),
                        if (a.entries.any((r) => r.isTimed && r.guided != null))
                          Text(
                              '${workoutDurationLabel(a.entries.where((r) => r.isTimed).fold<int>(0, (total, r) => total + (r.guided?.totalActiveMicroseconds ?? 0)))} active · Timer recorded'),
                        if (a.startedAtMicros != null)
                          Text('Started ${_date(a.startedAtMicros!)}'),
                        if (a.finishedAtMicros != null)
                          Text('Ended ${_date(a.finishedAtMicros!)}'),
                        if (a.elapsedDurationMicros != null)
                          Text(
                              '${workoutDurationLabel(a.elapsedDurationMicros!)} elapsed · includes breaks and time away'),
                        if (a.finished && a.finishedAtMicros == null)
                          const Text(
                              'Completion time unavailable for this older attempt.'),
                      ])),
              const SizedBox(height: 16),
              for (final result in a.entries)
                _ExerciseResult(
                    attempt: a,
                    result: result,
                    availableSessionIds: availableSessionIds,
                    onOpenSession: onOpenSession),
              const SizedBox(height: 12),
              if (!repeatIsPrimary && onRepeat != null)
                OutlinedButton(
                    onPressed: onRepeat,
                    child: const Text('Repeat this workout')),
            ]));
  }
}

class _ExerciseResult extends StatelessWidget {
  const _ExerciseResult(
      {required this.attempt,
      required this.result,
      required this.availableSessionIds,
      this.onOpenSession});
  final RoutineAttempt attempt;
  final RoutineExerciseResult result;
  final Set<String> availableSessionIds;
  final ValueChanged<String>? onOpenSession;
  @override
  Widget build(BuildContext context) {
    final e = attempt.routine.exercises[result.index];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: Theme.of(context).textTheme.titleMedium),
              Text(ExercisePresentation.forExercise(e,
                      organizationId: attempt.scope.organizationId)
                  .targetsWithRest),
              Text(ExercisePresentation.forExercise(e,
                      organizationId: attempt.scope.organizationId)
                  .label),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(
                    isExerciseTargetComplete(result.status)
                        ? Icons.check_circle_rounded
                        : result.status == RoutineExerciseStatus.skipped
                            ? Icons.skip_next_rounded
                            : Icons.timelapse_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(exerciseStatusLabel(result.status))),
              ]),
              Text(exerciseResultSummary(result)),
              if (onOpenSession != null)
                for (final id
                    in result.sessionIds.where(availableSessionIds.contains))
                  TextButton.icon(
                      onPressed: () => onOpenSession!(id),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('View saved exercise session')),
            ])));
  }
}
