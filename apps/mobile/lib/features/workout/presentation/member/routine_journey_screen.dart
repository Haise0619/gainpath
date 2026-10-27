import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/routine_journey_controller.dart';
import '../../domain/routine_journey.dart';
import '../../domain/workout_rewards.dart';
import 'widgets/routine_workout_reward_panel.dart';

class RoutineJourneyScreen extends StatefulWidget {
  const RoutineJourneyScreen(
      {super.key,
      required this.controller,
      required this.onTrack,
      required this.onTutorial,
      this.onViewProgress,
      this.onViewHistory});
  final RoutineJourneyController controller;
  final VoidCallback? onViewProgress, onViewHistory;
  final Future<void> Function(int index) onTrack, onTutorial;
  @override
  State<RoutineJourneyScreen> createState() => _RoutineJourneyScreenState();
}

class _RoutineJourneyScreenState extends State<RoutineJourneyScreen> {
  bool _working = false, _showSummary = false;
  Future<void> _act(Future<void> Function() action) async {
    if (_working || widget.controller.busy) return;
    setState(() => _working = true);
    try {
      await action();
      final c = widget.controller;
      if (c.allTargetsCompleted && c.checkpoint?.finished == false) {
        await c.finish();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not update routine progress. Your saved workout results are retained.')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _status(RoutineExerciseStatus status) => switch (status) {
        RoutineExerciseStatus.notStarted => 'Not started',
        RoutineExerciseStatus.partial =>
          'Partial result saved · retry exercise',
        RoutineExerciseStatus.completed => 'Measured target complete',
        RoutineExerciseStatus.selfReportedPartial =>
          'Self-reported sets in progress',
        RoutineExerciseStatus.selfReportedCompleted =>
          'Self-reported sets complete · not AI measured',
        RoutineExerciseStatus.instructionsReviewed =>
          'Instructions reviewed · not measured',
        RoutineExerciseStatus.skipped => 'Skipped',
      };
  Future<void> _finish() => _act(() async {
        final c = widget.controller;
        if (!c.allTargetsCompleted) {
          final yes = await confirmSheet(context,
              title: 'Finish with unfinished exercises?',
              message:
                  'Saved results are retained. Unfinished exercises stay clearly marked in your routine summary.',
              confirmLabel: 'View summary');
          if (!yes || !mounted || !c.authorized) return;
        }
        await c.finish();
        if (mounted) setState(() => _showSummary = true);
      });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        if (!c.authorized) {
          return const Scaffold(
              body: Center(
                  child: Text('Sign in to view this account’s routine.')));
        }
        final ready = c.checkpoint != null;
        final summary = ready && (_showSummary || c.checkpoint!.finished);
        return PopScope(
            canPop: !_working && !c.busy,
            child: Scaffold(
                appBar: AppBar(
                    title: Text(summary ? 'Routine summary' : c.routine.title),
                    actions: [
                      if (ready && !summary)
                        IconButton(
                            tooltip: 'Routine summary',
                            onPressed: () =>
                                setState(() => _showSummary = true),
                            icon: const Icon(Icons.summarize_outlined))
                    ]),
                body: !ready
                    ? Center(
                        child: c.busy
                            ? const CircularProgressIndicator()
                            : FilledButton(
                                onPressed: () => _act(() => c.openDay(c.day)),
                                child: const Text('Retry routine')))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        children: [
                            if (c.error != null)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(c.error!,
                                      style: const TextStyle(
                                          color: AppColors.danger))),
                            if (summary)
                              ..._summary(context)
                            else
                              ..._journey(context),
                            if (_working || c.busy)
                              const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: LinearProgressIndicator()),
                            SizedBox(
                                height: MediaQuery.paddingOf(context).bottom),
                          ])));
      });

  List<Widget> _journey(BuildContext context) {
    final c = widget.controller,
        selected = c.routine.exercises[c.selectedIndex];
    final supported = c.supportsTracking(c.selectedIndex);
    final status = c.statusFor(c.selectedIndex);
    final disabled = _working || c.busy;
    return [
      Row(children: [
        Expanded(
            child: Text('Your workout journey',
                style: Theme.of(context).textTheme.titleLarge)),
        DropdownButton<int>(
            value: c.day,
            items: [
              for (final day in c.days)
                DropdownMenuItem(value: day, child: Text('Day $day'))
            ],
            onChanged: disabled ? null : (day) => _act(() => c.openDay(day!))),
      ]),
      const SizedBox(height: 8),
      const Text(
          'Progress saves on this device. Resume from your last saved exercise; unsaved camera attempts are not recovered.',
          style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
      const SizedBox(height: 16),
      for (final index in c.dayIndices)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
                color: index == c.selectedIndex
                    ? AppColors.primaryTint
                    : AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                        color: index == c.selectedIndex
                            ? AppColors.primary
                            : AppColors.hairline)),
                child: ListTile(
                    onTap: disabled ? null : () => _act(() => c.select(index)),
                    leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceAlt,
                        child: Text('${c.dayIndices.indexOf(index) + 1}',
                            style: const TextStyle(color: AppColors.primary))),
                    title: Text(c.routine.exercises[index].name),
                    subtitle: Text(
                        '${c.targetsFor(index)}\n${_status(c.statusFor(index))}'),
                    isThreeLine: true,
                    trailing: Tooltip(
                        message: c.trackingFor(index).description,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              c.supportsTracking(index)
                                  ? Icons.videocam_outlined
                                  : Icons.menu_book_outlined,
                              color: AppColors.primary),
                          Text(
                              c
                                  .capabilityFor(index)
                                  .displayLabel
                                  .replaceFirst(' · ', '\n'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.inkSoft)),
                        ]))))),
      const SizedBox(height: 14),
      Text(
          '${c.completedExercises} / ${c.dayIndices.length} exercises complete',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      LinearProgressIndicator(
          value: c.completedExercises / c.dayIndices.length,
          semanticsLabel: 'Routine progress'),
      const SizedBox(height: 12),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(selected.name, style: Theme.of(context).textTheme.titleLarge),
        Align(
            alignment: Alignment.centerLeft,
            child: Chip(
                avatar: Icon(
                    supported
                        ? Icons.auto_awesome_rounded
                        : Icons.menu_book_outlined,
                    size: 16),
                label: Text(c.capabilityFor(c.selectedIndex).displayLabel),
                backgroundColor: AppColors.primaryTint,
                side: BorderSide.none)),
        const SizedBox(height: 6),
        if (c.trackingFor(c.selectedIndex).unavailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(c.trackingFor(c.selectedIndex).description,
                style: const TextStyle(color: AppColors.inkSoft)),
          ),
        Text(c.targetsFor(c.selectedIndex),
            style: const TextStyle(color: AppColors.inkSoft)),
        if (selected.cue.trim().isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(selected.cue)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: disabled
                ? null
                : () => _act(() => widget.onTutorial(c.selectedIndex)),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Watch exercise tutorial')),
        if (supported) ...[
          const SizedBox(height: 8),
          if (status == RoutineExerciseStatus.completed)
            const Text(
                'Measured target complete. Select another exercise or view your routine summary.')
          else
            FilledButton.icon(
                onPressed: disabled
                    ? null
                    : () => _act(() => widget.onTrack(c.selectedIndex)),
                icon: const Icon(Icons.videocam_rounded),
                label: Text(status == RoutineExerciseStatus.partial
                    ? 'Retry guided exercise'
                    : 'Start guided exercise')),
          if (status == RoutineExerciseStatus.partial)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'The earlier partial result is retained. A retry starts the published targets again.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 12))),
        ] else ...[
          const SizedBox(height: 10),
          const Text(
              'Guided only · mark sets as done yourself. Completion is self-reported; no AI repetitions or form score are generated.',
              style: TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          Text(
              '${c.manualSetsFor(c.selectedIndex)} / ${selected.sets} sets · self-reported',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed:
                  disabled || c.manualSetsFor(c.selectedIndex) >= selected.sets
                      ? null
                      : () => _act(() => c.markManualSet(c.selectedIndex)),
              icon: const Icon(Icons.check_rounded),
              label: Text(c.manualSetsFor(c.selectedIndex) >= selected.sets
                  ? 'All sets marked done'
                  : 'Mark set ${c.manualSetsFor(c.selectedIndex) + 1} done')),
          if (c.manualSetsFor(c.selectedIndex) > 0)
            TextButton(
                onPressed: disabled
                    ? null
                    : () => _act(() => c.undoManualSet(c.selectedIndex)),
                child: const Text('Undo last set')),
          OutlinedButton.icon(
              onPressed: disabled
                  ? null
                  : () => _act(() => c.reviewInstructions(c.selectedIndex)),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Mark instructions reviewed')),
        ],
        TextButton(
            onPressed:
                disabled ? null : () => _act(() => c.skip(c.selectedIndex)),
            child: const Text('Skip exercise')),
      ])),
      const SizedBox(height: 16),
      FilledButton.tonalIcon(
          onPressed: disabled ? null : _finish,
          icon: const Icon(Icons.checklist_rounded),
          label: const Text('Finish routine')),
    ];
  }

  List<Widget> _summary(BuildContext context) {
    final c = widget.controller;
    final complete = c.dayIndices
        .where((i) => c.statusFor(i) == RoutineExerciseStatus.completed)
        .length;
    return [
      Text('Routine completion',
          style: Theme.of(context).textTheme.titleMedium),
      Text(c.checkpoint?.attempt?.statusLabel ?? 'Routine result',
          style: Theme.of(context).textTheme.headlineSmall),
      Text('${c.routine.title} · Day ${c.day}',
          style: Theme.of(context).textTheme.titleLarge),
      Text(
          '${c.completedExercises}/${c.dayIndices.length} exercise targets completed'),
      const SizedBox(height: 12),
      Panel(
          background: AppColors.primaryTint,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '$complete measured exercise${complete == 1 ? '' : 's'} complete',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
                '${c.fullRepetitions} full reps · ${c.partialRepetitions} partial reps'),
            Text(
                '${c.trackedDurationMicros ~/ 1000000}s tracked across ${c.measuredSessions.length} saved sessions'),
            const Divider(),
            Text(
                '${c.selfReportedSets} self-reported sets · separate from AI measurements'),
            const SizedBox(height: 8),
            const Text(
                'Camera measurements and self-reported completion stay separate. Manual sets add no AI reps, form score or rewards.',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ])),
      const SizedBox(height: 16),
      RoutineWorkoutRewardPanel(
          reference: WorkoutRewardAttemptReference(
              scope: c.scope,
              attemptId: c.checkpoint!.id,
              routineId: c.routine.id,
              day: c.day),
          isCurrent: () => c.authorized,
          difficulty: (c.checkpoint?.attempt?.routine ?? c.routine).difficulty),
      const SizedBox(height: 16),
      for (final index in c.dayIndices)
        Card(
            child: ListTile(
                leading: Icon(
                    c.statusFor(index) == RoutineExerciseStatus.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: AppColors.primary),
                title: Text(c.routine.exercises[index].name),
                subtitle: Text(
                    '${_status(c.statusFor(index))}${c.supportsTracking(index) ? '' : '\n${c.manualSetsFor(index)} / ${c.routine.exercises[index].sets} sets self-reported'}${c.sessionsFor(index).isEmpty ? '' : '\n${c.sessionsFor(index).fold<int>(0, (n, s) => n + s.repetitions)} measured full reps'}${c.sessionsFor(index).where((s) => s.poseMetrics?.curlArms != null).map((s) => '\n${s.poseMetrics!.curlArms!.mode.label} · ${s.poseMetrics!.curlArms!.countLabel}').join()}'))),
      const SizedBox(height: 12),
      if (!c.allTargetsCompleted)
        FilledButton(
            onPressed: _working || c.busy
                ? null
                : () => _act(() async {
                      await c.resume();
                      if (mounted) setState(() => _showSummary = false);
                    }),
            child: const Text('Resume unfinished exercises')),
      if (c.allTargetsCompleted && c.checkpoint!.finished && c.nextDay != null)
        FilledButton.icon(
            onPressed: _working || c.busy
                ? null
                : () => _act(() async {
                      await c.startNextDay();
                      if (mounted) setState(() => _showSummary = false);
                    }),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Next routine day')),
      if (widget.onViewProgress != null)
        OutlinedButton(
            onPressed: widget.onViewProgress,
            child: const Text('View progress')),
      if (widget.onViewHistory != null)
        TextButton(
            onPressed: widget.onViewHistory,
            child: const Text('Routine history')),
      OutlinedButton(
          onPressed: _working || c.busy
              ? null
              : () => _act(() async {
                    await c.startNewAttempt();
                    if (mounted) setState(() => _showSummary = false);
                  }),
          child: const Text('Repeat this workout')),
      TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to workouts')),
    ];
  }
}
