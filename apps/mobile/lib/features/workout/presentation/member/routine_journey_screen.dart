import 'dart:async';
import '../workout_presentation.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/routine_journey_controller.dart';
import '../../domain/exercise_tracker_dispatcher.dart';
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
      this.onOpenSettings,
      this.onViewHistory});
  final RoutineJourneyController controller;
  final VoidCallback? onViewHistory;
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                          ])));
      });

  Widget _buildHeaderCard(BuildContext context, bool disabled) {
    final c = widget.controller;
    final total = c.dayIndices.length;
    final completed = c.completedExercises;
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final isFinished = c.checkpoint?.finished == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E5F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.routine.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF190F2E),
                  ),
                ),
              ),
              if (c.days.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: c.day,
                    isDense: true,
                    items: [
                      for (final day in c.days)
                        DropdownMenuItem(
                          value: day,
                          child: Text(
                            'Day $day',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                    ],
                    onChanged: disabled || c.isScheduled
                        ? null
                        : (day) => _act(() => c.openDay(day!)),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Day ${c.day}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completed of $total completed',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isFinished
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isFinished ? 'Finished' : 'In progress',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isFinished
                        ? const Color(0xFF15803D)
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              semanticsLabel: 'Routine progress',
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(
                Icons.phone_android_rounded,
                size: 13,
                color: AppColors.inkSoft,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Saved on this device',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _cameraHint(ExerciseTracker? tracker) => switch (tracker) {
        ExerciseTracker.frontViewLateralRaise ||
        ExerciseTracker.frontViewShoulderPress =>
          'Front camera view · Stand facing camera with full body visible',
        ExerciseTracker.sideViewFloorPushUp =>
          'Floor side view · Place device on floor 2-3m away facing your side',
        ExerciseTracker.sideViewSquat ||
        ExerciseTracker.sideViewCurl ||
        ExerciseTracker.sideViewCalfRaise ||
        ExerciseTracker.sideViewWallPushUp ||
        ExerciseTracker.sideViewRow ||
        ExerciseTracker.sideViewReverseLunge =>
          'Side camera view · Place device 2m away facing your profile',
        _ => null,
      };

  List<Widget> _journey(BuildContext context) {
    final c = widget.controller,
        selected = c.routine.exercises[c.selectedIndex];
    final supported = c.supportsTracking(c.selectedIndex);
    final presentation = ExercisePresentation.forExercise(selected,
        organizationId: c.scope.organizationId);
    final status = c.statusFor(c.selectedIndex);
    final disabled = _working || c.busy;
    final cameraHint =
        supported ? _cameraHint(c.trackingFor(c.selectedIndex).tracker) : null;
    return [
      _buildHeaderCard(context, disabled),
      const SizedBox(height: 16),
      for (final index in c.dayIndices)
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
                color: index == c.selectedIndex
                    ? const Color(0xFFFBF9FF)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: index == c.selectedIndex
                            ? AppColors.primary
                            : (index == c.unfinishedIndices.firstWhere((i) => true, orElse: () => -1) &&
                                    !isExerciseTargetComplete(
                                        c.statusFor(index))
                                ? const Color(0x666D28D9)
                                : const Color(0xFFE9E5F0)),
                        width: index == c.selectedIndex ? 2.0 : 1.0)),
                child: ListTile(
                    onTap: disabled ? null : () => _act(() => c.select(index)),
                    leading: CircleAvatar(
                        radius: 13,
                        backgroundColor: isExerciseTargetComplete(c.statusFor(index))
                            ? const Color(0xFFDCFCE7)
                            : (index == c.selectedIndex
                                ? AppColors.primary
                                : const Color(0xFFF1EEF8)),
                        child: isExerciseTargetComplete(c.statusFor(index))
                            ? const Icon(Icons.check_rounded,
                                size: 15, color: Color(0xFF16A34A))
                            : Text('${c.dayIndices.indexOf(index) + 1}',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: index == c.selectedIndex ? Colors.white : AppColors.primary))),
                    title: Text(c.routine.exercises[index].name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: isExerciseTargetComplete(c.statusFor(index)) ? AppColors.inkSoft : AppColors.ink)),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isExerciseTargetComplete(c.statusFor(index))
                                ? const Color(0xFFF3F4F6)
                                : const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ExercisePresentation.forExercise(
                                    c.routine.exercises[index],
                                    organizationId: c.scope.organizationId)
                                .label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color:
                                  isExerciseTargetComplete(c.statusFor(index))
                                      ? const Color(0xFF6B7280)
                                      : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ExercisePresentation.forExercise(
                                    c.routine.exercises[index],
                                    organizationId: c.scope.organizationId)
                                .targetLabel,
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.inkSoft),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: Icon(
                        isExerciseTargetComplete(c.statusFor(index))
                            ? Icons.check_circle_rounded
                            : index == c.selectedIndex
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                        color: isExerciseTargetComplete(c.statusFor(index)) ? const Color(0xFF16A34A) : (index == c.selectedIndex ? AppColors.primary : const Color(0xFFCBC4D8)))))),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9E5F0), width: 1.0),
        ),
        child: isExerciseTargetComplete(status)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${selected.name} · Completed',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (c.sessionsFor(c.selectedIndex).isNotEmpty)
                    Text(
                      '${c.sessionsFor(c.selectedIndex).fold<int>(0, (n, s) => n + s.repetitions)} full reps · ${c.sessionsFor(c.selectedIndex).length} saved session${c.sessionsFor(c.selectedIndex).length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    )
                  else if (c.isTimed(c.selectedIndex))
                    Text(
                      '${c.checkpoint!.guidedProgress[c.selectedIndex]?.completedSets ?? 0}/${selected.sets} timed sets completed',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    )
                  else
                    Text(
                      '${c.manualSetsFor(c.selectedIndex)} / ${selected.sets} sets · self-reported',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: disabled
                        ? null
                        : () => _act(() => widget.onTutorial(c.selectedIndex)),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Watch exercise tutorial'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          presentation.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFE9D5FF), width: 1.0),
                        ),
                        child: Text(
                          '💡 Form Cue: ${selected.cue}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF581C87),
                          ),
                        ),
                      ),
                    ),
                  if (cameraHint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.videocam_outlined,
                                size: 15, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cameraHint,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: disabled
                          ? null
                          : () =>
                              _act(() => widget.onTutorial(c.selectedIndex)),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: const Text('Watch exercise tutorial')),
                  if (c.isTimed(c.selectedIndex)) ...[
                    const SizedBox(height: 10),
                    const Text(
                        'Video guided · elapsed workout time. Repetitions and form are not measured.',
                        style:
                            TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                        '${c.checkpoint!.guidedProgress[c.selectedIndex]?.completedSets ?? 0}/${selected.sets} timed sets',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.ink)),
                  ] else if (supported) ...[
                    const SizedBox(height: 8),
                    if (status == RoutineExerciseStatus.partial)
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                              'The earlier partial result is retained. A retry starts the published targets again.',
                              style: TextStyle(
                                  color: AppColors.inkSoft, fontSize: 12))),
                  ] else ...[
                    const SizedBox(height: 10),
                    const Text(
                        'Manual · log each completed set yourself. Repetitions and form are not measured.',
                        style:
                            TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(
                        '${c.manualSetsFor(c.selectedIndex)} / ${selected.sets} sets · self-reported',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.ink)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (c.manualSetsFor(c.selectedIndex) > 0) ...[
                          TextButton(
                              onPressed: disabled
                                  ? null
                                  : () => _act(
                                      () => c.undoManualSet(c.selectedIndex)),
                              child: const Text('Undo last set')),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                              onPressed: disabled
                                  ? null
                                  : () => _act(() =>
                                      c.reviewInstructions(c.selectedIndex)),
                              icon: const Icon(Icons.menu_book_rounded),
                              label: const Text('Mark instructions reviewed')),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: disabled
                            ? null
                            : () => _act(() => c.skip(c.selectedIndex)),
                        child: const Text('Skip exercise')),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton.icon(
          onPressed: disabled ? null : _finish,
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: Text(
            c.allTargetsCompleted ? 'Finish routine' : 'Finish early',
            style: const TextStyle(color: AppColors.inkSoft),
          ),
        ),
      ),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE9E5F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                e.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                p.targetLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _working || c.busy || complete
                    ? null
                    : () => _act(() => manual
                        ? (widget.onManualSet?.call(index) ??
                            c.markManualSet(index))
                        : widget.onTrack(index)),
                icon: Icon(p.icon),
                label: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE9E5F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _working || c.busy
                ? null
                : () {
                    if (!c.allTargetsCompleted) {
                      _act(() async {
                        await c.resume();
                        if (mounted) setState(() => _showSummary = false);
                      });
                    } else if (c.checkpoint!.finished && c.nextDay != null) {
                      _act(() async {
                        await c.startNextDay();
                        if (mounted) setState(() => _showSummary = false);
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  List<Widget> _summary(BuildContext context) {
    final c = widget.controller;
    final complete = c.dayIndices
        .where((i) => c.statusFor(i) == RoutineExerciseStatus.completed)
        .length;
    return [
      Text('Routine completion',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
      Text(
          c.checkpoint?.attempt == null
              ? 'In Progress'
              : workoutAttemptLabel(c.checkpoint!.attempt!),
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.ink)),
      Text(routineDayTitle(c.routine, c.day),
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
      Text(
          '${c.completedExercises}/${c.dayIndices.length} exercise targets completed',
          style: const TextStyle(color: AppColors.inkSoft)),
      Text(
          '${c.dayIndices.where((i) => c.statusFor(i) == RoutineExerciseStatus.skipped).length} skipped · ${c.dayIndices.where((i) => !isExerciseTargetComplete(c.statusFor(i)) && c.statusFor(i) != RoutineExerciseStatus.skipped).length} unfinished',
          style: const TextStyle(color: AppColors.inkSoft)),
      if (c.checkpoint?.finished == true && c.error == null)
        const Text('Saved on this device',
            style: TextStyle(color: AppColors.inkSoft)),
      if (widget.onViewHistory != null)
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
                onPressed: widget.onViewHistory,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Routine history'))),
      const SizedBox(height: 12),
      Panel(
          background: AppColors.primaryTint,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (c.measuredSessions.isNotEmpty) ...[
              Text(
                  '$complete measured exercise${complete == 1 ? '' : 's'} complete',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
              const SizedBox(height: 8),
              Text(
                  '${c.fullRepetitions} full reps · ${c.partialRepetitions} partial reps',
                  style: const TextStyle(color: AppColors.ink)),
              Text(
                  '${c.trackedDurationMicros ~/ 1000000}s tracked across ${c.measuredSessions.length} saved sessions',
                  style: const TextStyle(color: AppColors.inkSoft)),
            ],
            if (c.selfReportedSets > 0)
              Text(
                  '${c.selfReportedSets} self-reported sets · separate from AI measurements',
                  style: const TextStyle(color: AppColors.ink)),
            if (c.guidedDurationMicros > 0)
              Text(
                  '${c.guidedDurationMicros ~/ 1000000}s video-guided time · Not AI verified',
                  style: const TextStyle(color: AppColors.ink)),
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
