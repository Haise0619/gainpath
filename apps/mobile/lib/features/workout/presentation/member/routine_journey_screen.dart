import 'dart:async';
import '../workout_presentation.dart';
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
      this.onManualSet,
      this.onViewProgress,
      this.onOpenSettings,
      this.onViewHistory});
  final RoutineJourneyController controller;
  final VoidCallback? onViewProgress, onViewHistory;
  final VoidCallback? onOpenSettings;
  final Future<void> Function(int index) onTrack, onTutorial;
  final Future<void> Function(int index)? onManualSet;
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

  String _status(RoutineExerciseStatus status) => exerciseStatusLabel(status);
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
                      if (widget.onOpenSettings != null)
                        IconButton(
                            tooltip: 'Workout settings',
                            onPressed: widget.onOpenSettings,
                            icon: const Icon(Icons.settings_outlined)),
                      if (ready && !summary)
                        IconButton(
                            tooltip: 'Routine summary',
                            onPressed: () =>
                                setState(() => _showSummary = true),
                            icon: const Icon(Icons.summarize_outlined))
                    ]),
                bottomNavigationBar: !ready
                    ? null
                    : summary
                        ? _summaryAction(context)
                        : _primaryAction(context),
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
    final presentation = ExercisePresentation.forExercise(selected,
        organizationId: c.scope.organizationId);
    final status = c.statusFor(c.selectedIndex);
    final disabled = _working || c.busy;
    return [
      Panel(
          background: AppColors.primaryTint,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c.routine.title,
                style: Theme.of(context).textTheme.titleLarge),
            Row(children: [
              Expanded(
                  child: Text(
                      '${c.completedExercises}/${c.dayIndices.length} complete',
                      style: Theme.of(context).textTheme.titleLarge)),
              DropdownButton<int>(
                  value: c.day,
                  items: [
                    for (final day in c.days)
                      DropdownMenuItem(value: day, child: Text('Day $day'))
                  ],
                  onChanged: disabled || c.isScheduled
                      ? null
                      : (day) => _act(() => c.openDay(day!))),
            ]),
            LinearProgressIndicator(
                value: c.completedExercises / c.dayIndices.length,
                semanticsLabel: 'Routine progress'),
            const SizedBox(height: 8),
            Text(c.checkpoint!.finished ? 'Finished' : 'In progress'),
          ])),
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
                        '${ExercisePresentation.forExercise(c.routine.exercises[index], organizationId: c.scope.organizationId).targetsWithRest}\n${ExercisePresentation.forExercise(c.routine.exercises[index], organizationId: c.scope.organizationId).label} · ${_status(c.statusFor(index))}'),
                    isThreeLine: true,
                    trailing: Icon(
                        isExerciseTargetComplete(c.statusFor(index))
                            ? Icons.check_circle_rounded
                            : index == c.selectedIndex
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                        color: AppColors.primary)))),
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
                label: Text(presentation.label),
                backgroundColor: AppColors.primaryTint,
                side: BorderSide.none)),
        const SizedBox(height: 6),
        if (c.trackingFor(c.selectedIndex).unavailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(c.trackingFor(c.selectedIndex).description,
                style: const TextStyle(color: AppColors.inkSoft)),
          ),
        Text(presentation.targetsWithRest,
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
        if (c.isTimed(c.selectedIndex)) ...[
          const SizedBox(height: 10),
          const Text(
              'Video guided · elapsed workout time. Repetitions and form are not measured.'),
          Text(
              '${c.checkpoint!.guidedProgress[c.selectedIndex]?.completedSets ?? 0}/${selected.sets} timed sets'),
        ] else if (supported) ...[
          const SizedBox(height: 8),
          if (status == RoutineExerciseStatus.partial)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'The earlier partial result is retained. A retry starts the published targets again.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 12))),
        ] else ...[
          const SizedBox(height: 10),
          const Text(
              'Manual · log each completed set yourself. Repetitions and form are not measured.',
              style: TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          Text(
              '${c.manualSetsFor(c.selectedIndex)} / ${selected.sets} sets · self-reported',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
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

  Widget _primaryAction(BuildContext context) {
    final c = widget.controller, index = widget.controller.selectedIndex;
    final e = c.routine.exercises[index];
    final p = ExercisePresentation.forExercise(e,
        organizationId: c.scope.organizationId);
    final status = c.statusFor(index);
    final complete = isExerciseTargetComplete(status);
    final manual = !c.isTimed(index) && !c.supportsTracking(index);
    final label = complete
        ? 'Exercise complete'
        : manual
            ? 'Mark set ${c.manualSetsFor(index) + 1} done'
            : status == RoutineExerciseStatus.timerPartial
                ? 'Resume Timed Workout'
                : status == RoutineExerciseStatus.partial
                    ? 'Retry AI Workout'
                    : p.startLabel;
    return SafeArea(
        top: false,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(e.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(p.targetLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  FilledButton.icon(
                      onPressed: _working || c.busy || complete
                          ? null
                          : () => _act(() => manual
                              ? (widget.onManualSet?.call(index) ??
                                  c.markManualSet(index))
                              : widget.onTrack(index)),
                      icon: Icon(p.icon),
                      label: Text(label)),
                  TextButton.icon(
                      onPressed: _working || c.busy
                          ? null
                          : () => _act(() => widget.onTutorial(index)),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Tutorial')),
                ])));
  }

  Widget _summaryAction(BuildContext context) {
    final c = widget.controller;
    final label = !c.allTargetsCompleted
        ? 'Resume unfinished exercises'
        : c.checkpoint!.finished && c.nextDay != null
            ? 'Next routine day'
            : c.isScheduled
                ? 'Back to weekly schedule'
                : 'Back to workouts';
    return SafeArea(
        top: false,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: _working || c.busy
                    ? null
                    : () {
                        if (!c.allTargetsCompleted) {
                          _act(() async {
                            await c.resume();
                            if (mounted) setState(() => _showSummary = false);
                          });
                        } else if (c.checkpoint!.finished &&
                            c.nextDay != null) {
                          _act(() async {
                            await c.startNextDay();
                            if (mounted) setState(() => _showSummary = false);
                          });
                        } else {
                          Navigator.pop(context);
                        }
                      },
                child: Text(label, textAlign: TextAlign.center))));
  }

  List<Widget> _summary(BuildContext context) {
    final c = widget.controller;
    final complete = c.dayIndices
        .where((i) => c.statusFor(i) == RoutineExerciseStatus.completed)
        .length;
    return [
      Text('Routine completion',
          style: Theme.of(context).textTheme.titleMedium),
      Text(
          c.checkpoint?.attempt == null
              ? 'In Progress'
              : workoutAttemptLabel(c.checkpoint!.attempt!),
          style: Theme.of(context).textTheme.headlineSmall),
      Text('${c.routine.title} · Day ${c.day}',
          style: Theme.of(context).textTheme.titleLarge),
      Text(
          '${c.completedExercises}/${c.dayIndices.length} exercise targets completed'),
      Text(
          '${c.dayIndices.where((i) => c.statusFor(i) == RoutineExerciseStatus.skipped).length} skipped · ${c.dayIndices.where((i) => !isExerciseTargetComplete(c.statusFor(i)) && c.statusFor(i) != RoutineExerciseStatus.skipped).length} unfinished'),
      if (c.checkpoint?.finished == true && c.error == null)
        const Text('Saved on this device'),
      const SizedBox(height: 12),
      Panel(
          background: AppColors.primaryTint,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (c.measuredSessions.isNotEmpty) ...[
              Text(
                  '$complete measured exercise${complete == 1 ? '' : 's'} complete',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                  '${c.fullRepetitions} full reps · ${c.partialRepetitions} partial reps'),
              Text(
                  '${c.trackedDurationMicros ~/ 1000000}s tracked across ${c.measuredSessions.length} saved sessions'),
            ],
            if (c.selfReportedSets > 0)
              Text(
                  '${c.selfReportedSets} self-reported sets · separate from AI measurements'),
            if (c.guidedDurationMicros > 0)
              Text(
                  '${c.guidedDurationMicros ~/ 1000000}s video-guided time · Not AI verified'),
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
                    isExerciseTargetComplete(c.statusFor(index))
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: AppColors.primary),
                title: Text(c.routine.exercises[index].name),
                subtitle: Text(
                    '${_status(c.statusFor(index))}${c.isTimed(index) ? '\n${c.checkpoint!.guidedProgress[index]?.completedSets ?? 0} timed sets · not AI verified' : c.supportsTracking(index) ? '' : '\n${c.manualSetsFor(index)} / ${c.routine.exercises[index].sets} sets self-reported'}${c.sessionsFor(index).isEmpty ? '' : '\n${c.sessionsFor(index).fold<int>(0, (n, s) => n + s.repetitions)} measured full reps'}${c.sessionsFor(index).where((s) => s.poseMetrics?.curlArms != null).map((s) => '\n${s.poseMetrics!.curlArms!.mode.label} · ${s.poseMetrics!.curlArms!.countLabel}').join()}'))),
      const SizedBox(height: 12),
      if (widget.onViewProgress != null)
        OutlinedButton(
            onPressed: widget.onViewProgress,
            child: const Text('View progress')),
      if (widget.onViewHistory != null)
        TextButton(
            onPressed: widget.onViewHistory,
            child: const Text('Routine history')),
      if (!c.isScheduled)
        OutlinedButton(
            onPressed: _working || c.busy
                ? null
                : () => _act(() async {
                      await c.startNewAttempt();
                      if (mounted) setState(() => _showSummary = false);
                    }),
            child: const Text('Repeat this workout')),
      if (!c.allTargetsCompleted || c.nextDay != null)
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(c.isScheduled
                ? 'Back to weekly schedule'
                : 'Back to workouts')),
    ];
  }
}
