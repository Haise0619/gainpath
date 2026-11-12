import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/routine_attempt.dart';
import '../workout_presentation.dart';
import '../../domain/workout_contracts.dart';
import 'widgets/workout_result_content.dart';

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
      this.onOpenSession,
      this.summaries = const []});
  final RoutineAttempt attempt;
  final String? trainingSource;
  final Widget? saveStatus;
  final VoidCallback? onResume, onRepeat, onNextDay;
  final Set<String> availableSessionIds;
  final ValueChanged<String>? onOpenSession;
  final List<WorkoutSessionSummary> summaries;
  @override
  Widget build(BuildContext context) {
    final a = attempt;
    final action = !a.isComplete ? onResume : onNextDay ?? onRepeat;
    return Scaffold(
        appBar: AppBar(title: const Text('Workout summary')),
        bottomNavigationBar: action == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                        onPressed: action,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(!a.isComplete
                            ? 'Resume unfinished exercises'
                            : onNextDay != null
                                ? 'Next routine day'
                                : 'Repeat this workout')))),
        body: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              if (trainingSource != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(trainingSource!,
                        style: const TextStyle(color: AppColors.inkSoft))),
              RoutineCompletionContent(
                  attempt: a,
                  summaries: summaries,
                  saveStatus: saveStatus,
                  availableSessionIds: availableSessionIds,
                  onOpenSession: onOpenSession == null
                      ? null
                      : (id) {
                          if (availableSessionIds.contains(id)) {
                            onOpenSession!(id);
                          }
                        }),
              if (onRepeat != null && (!a.isComplete || onNextDay != null))
                OutlinedButton(
                    onPressed: onRepeat,
                    child: const Text('Repeat this workout')),
            ]));
  }
}
