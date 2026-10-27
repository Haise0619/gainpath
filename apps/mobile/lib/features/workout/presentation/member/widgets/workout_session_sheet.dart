import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../application/guided_workout_progress.dart';
import '../../../application/pose_preview_controller.dart';
import '../../../application/measured_workout_session.dart';
import '../../../domain/routine_workout_context.dart';
import 'curl_arm_stats.dart';

/// Presentation-only sheet. Its extent never changes camera constraints or
/// owns capture, inference, counting, timing, consent or persistence.
class WorkoutSessionSheet extends StatefulWidget {
  const WorkoutSessionSheet(
      {super.key,
      required this.session,
      required this.controller,
      required this.exerciseName,
      required this.targetRepetitions,
      required this.onEnd,
      required this.onDiscard,
      this.routineContext,
      this.uploadNotice});
  final RoutineWorkoutContext? routineContext;
  final MeasuredWorkoutSession session;
  final DraggableScrollableController controller;
  final String exerciseName;
  final int targetRepetitions;
  final VoidCallback onEnd, onDiscard;
  final String? uploadNotice;

  static double collapsedHeight(BuildContext context, double height) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return math
        .max(
            height * .18,
            132 +
                MediaQuery.paddingOf(context).bottom +
                math.max(0, scale - 1) * 42)
        .clamp(0, height * .48);
  }

  @override
  State<WorkoutSessionSheet> createState() => _WorkoutSessionSheetState();
}

class _WorkoutSessionSheetState extends State<WorkoutSessionSheet> {
  bool _expanded = false;
  double _minExtent = .18, _maxExtent = .82;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_extentChanged);
  }

  void _extentChanged() {
    if (!widget.controller.isAttached) return;
    final expanded = widget.controller.size > _minExtent + .055;
    if (expanded != _expanded && mounted) setState(() => _expanded = expanded);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_extentChanged);
    super.dispose();
  }

  void _toggle() {
    if (!widget.controller.isAttached) return;
    final target = _expanded ? _minExtent : _maxExtent;
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.controller.jumpTo(target);
    } else {
      unawaited(widget.controller.animateTo(target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic));
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final headerHeight =
            WorkoutSessionSheet.collapsedHeight(context, bounds.maxHeight);
        _minExtent = headerHeight / bounds.maxHeight;
        _maxExtent = math.max(.64, _minExtent + .25).clamp(0, .95);
        return DraggableScrollableSheet(
          controller: widget.controller,
          initialChildSize: _minExtent,
          minChildSize: _minExtent,
          maxChildSize: _maxExtent,
          snap: true,
          snapSizes: [_minExtent, _maxExtent],
          snapAnimationDuration: const Duration(milliseconds: 220),
          shouldCloseOnMinExtent: false,
          builder: (context, scrollController) => Material(
              key: const ValueKey('workout-sheet-surface'),
              color: AppColors.surface,
              elevation: 16,
              shadowColor: Colors.black38,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: CustomScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                        pinned: true,
                        delegate: _PinnedWorkoutHeader(
                            height: headerHeight, child: _header(context))),
                    if (_expanded) SliverToBoxAdapter(child: _details(context)),
                  ])),
        );
      });

  Widget _header(BuildContext context) {
    final c = widget.session, flow = c.guidance;
    final arm =
        c is UnilateralWorkoutSession ? c as UnilateralWorkoutSession : null;
    final switching = arm?.awaitingArmSwitch ?? false;
    final paused =
        c.isManuallyPaused || c.preview.phase == PosePreviewPhase.failure;
    final resting = flow?.stage == GuidedWorkoutStage.resting;
    final complete = flow?.stage == GuidedWorkoutStage.complete;
    final active = c.viewPhase == MeasuredWorkoutPhase.active;
    final saving = c.viewPhase == MeasuredWorkoutPhase.saving;
    final retry = c.viewPhase == MeasuredWorkoutPhase.saveFailed;
    final exerciseLabel = widget.routineContext == null
        ? ''
        : 'EXERCISE ${widget.routineContext!.exerciseNumber} / ${widget.routineContext!.totalExercises} · ';
    final setLabel = flow == null
        ? 'LIVE WORKOUT'
        : '${arm != null && !resting ? '${arm.armLabel.toUpperCase()} · ' : ''}${exerciseLabel}SET ${resting ? flow.completedSets : flow.currentSet} / ${flow.sets}';
    final value = saving
        ? 'Saving…'
        : resting
            ? '${flow!.remainingRestSeconds}s'
            : complete
                ? (widget.routineContext == null
                    ? 'Complete'
                    : 'Exercise complete')
                : switching
                    ? 'Switch arms'
                    : arm?.armRepetitionLabel ??
                        '${flow?.setRepetitions ?? c.analysis?.repetitions ?? 0} / ${flow?.repetitions ?? widget.targetRepetitions}';
    final progress = flow == null
        ? ((c.analysis?.repetitions ?? 0) /
                math.max(1, widget.targetRepetitions))
            .clamp(0.0, 1.0)
        : complete
            ? 1.0
            : ((flow.completedSets +
                        (!resting
                            ? flow.setRepetitions / flow.repetitions
                            : 0)) /
                    flow.sets)
                .clamp(0.0, 1.0);
    final primaryLabel = retry
        ? 'Retry save'
        : complete
            ? (widget.routineContext == null
                ? 'Save result'
                : 'Save & continue')
            : paused
                ? 'Resume / retry camera'
                : switching
                    ? 'Start ${arm!.nextArmLabel.toLowerCase()}'
                    : resting
                        ? (flow!.remainingRestSeconds > 0
                            ? 'Skip rest & start set ${flow.completedSets + 1}'
                            : 'Start set ${flow.completedSets + 1}')
                        : 'Pause';
    void primary() {
      if (retry || complete) {
        widget.onEnd();
      } else if (paused) {
        unawaited(c.resume());
      } else if (switching) {
        arm!.confirmArmSwitch();
      } else if (resting) {
        c.startNextSet(skipRest: flow!.remainingRestSeconds > 0);
      } else {
        unawaited(c.pause());
      }
    }

    return ColoredBox(
        color: AppColors.surface,
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                18, 0, 14, 12 + MediaQuery.paddingOf(context).bottom),
            child: Column(children: [
              GestureDetector(
                  key: const ValueKey('workout-sheet-handle'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: Semantics(
                      button: true,
                      label: _expanded
                          ? 'Collapse workout details'
                          : 'Expand workout details',
                      child: SizedBox(
                          height: 28,
                          width: double.infinity,
                          child: Center(
                              child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: AppColors.hairline,
                                      borderRadius:
                                          BorderRadius.circular(8))))))),
              Expanded(
                  child: Row(children: [
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          paused
                              ? 'PAUSED · $setLabel'
                              : resting
                                  ? 'REST · $setLabel'
                                  : setLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .8,
                              color: AppColors.inkSoft)),
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                    ])),
                const SizedBox(width: 6),
                Tooltip(
                    message: primaryLabel,
                    child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                        onPressed:
                            (active || retry) && !saving && !c.isRecalibrating
                                ? primary
                                : null,
                        child: retry
                            ? const Text('Retry save')
                            : saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : complete && widget.routineContext != null
                                    ? const Text('Continue')
                                    : switching && !paused
                                        ? const Text('Switch')
                                        : resting && !paused
                                            ? const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                    Text('Next'),
                                                    SizedBox(width: 2),
                                                    Icon(
                                                        Icons
                                                            .chevron_right_rounded,
                                                        size: 20)
                                                  ])
                                            : Icon(complete
                                                ? Icons.check_rounded
                                                : paused
                                                    ? Icons.play_arrow_rounded
                                                    : Icons.pause_rounded))),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                    tooltip: widget.routineContext == null
                        ? 'End session'
                        : 'Finish exercise early',
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.dangerTint,
                        foregroundColor: AppColors.danger,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    onPressed:
                        saving || c.viewPhase == MeasuredWorkoutPhase.closed
                            ? null
                            : widget.onEnd,
                    icon: const Icon(Icons.stop_rounded)),
                IconButton(
                    tooltip: _expanded
                        ? 'Collapse workout details'
                        : 'Expand workout details',
                    onPressed: _toggle,
                    color: AppColors.primary,
                    icon: Icon(_expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded)),
              ])),
              const SizedBox(height: 10),
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: resting ? AppColors.accent : AppColors.primary,
                      backgroundColor: AppColors.primaryTint,
                      semanticsLabel: 'Workout progress')),
            ])));
  }

  Widget _details(BuildContext context) {
    final c = widget.session, u = c.analysis, flow = c.guidance;
    final active = c.viewPhase == MeasuredWorkoutPhase.active;
    final resting = flow?.stage == GuidedWorkoutStage.resting;
    final arm =
        c is UnilateralWorkoutSession ? c as UnilateralWorkoutSession : null;
    return Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (arm != null) ...[
            CurlArmStats(metrics: arm.armMetrics),
            if (arm.awaitingArmSwitch) ...[
              Text(
                  'Turn side-on with your ${arm.nextArmLabel.toLowerCase()} closest to the camera, then tap Switch. Lower the arm to recalibrate.'),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
          ],
          if (resting) ...[
            const Text(
                'Counting is paused. Start the next set when you are ready.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
            const SizedBox(height: 10),
            FilledButton.icon(
                onPressed: active && !c.isManuallyPaused && !c.isRecalibrating
                    ? () =>
                        c.startNextSet(skipRest: flow!.remainingRestSeconds > 0)
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(flow!.remainingRestSeconds > 0
                    ? 'Skip rest & start set ${flow.completedSets + 1}'
                    : 'Start set ${flow.completedSets + 1}')),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(builder: (context, bounds) {
            final columns = bounds.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18
                ? 2
                : 4;
            final stats = [
              ('${u?.repetitions ?? 0}', 'Full reps'),
              ('${u?.partialRepetitions ?? 0}', 'Partial reps'),
              (
                '${((u?.trackedDurationMicros ?? 0) / 1000000).floor()}s',
                'Tracked'
              ),
              (
                u?.formScorePercent == null
                    ? '—'
                    : '${u!.formScorePercent!.round()}%',
                'Est. form'
              ),
            ];
            return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.bg,
                    border: Border.all(color: AppColors.hairline),
                    borderRadius: BorderRadius.circular(18)),
                child: Wrap(runSpacing: 12, children: [
                  for (final stat in stats)
                    SizedBox(
                        width: (bounds.maxWidth - 2) / columns,
                        child: Column(children: [
                          Text(stat.$1,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink)),
                          Text(stat.$2,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.inkSoft)),
                        ]))
                ]));
          }),
          const SizedBox(height: 12),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Form guidance'),
              leading:
                  const Icon(Icons.insights_rounded, color: AppColors.primary),
              children: [
                Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(c.formGuidance,
                        style: const TextStyle(color: AppColors.inkSoft))),
              ]),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Session details'),
              leading: const Icon(Icons.assignment_outlined,
                  color: AppColors.primary),
              children: [
                if (widget.routineContext != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          '${widget.routineContext!.routineTitle} · Day ${widget.routineContext!.day}')),
                if (widget.routineContext?.nextExerciseName != null)
                  Text('Up next: ${widget.routineContext!.nextExerciseName}'),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(widget.exerciseName),
                    subtitle: Text(flow == null
                        ? '${widget.targetRepetitions} target reps'
                        : '${flow.sets} sets · ${flow.repetitions} reps per set')),
                if (flow != null)
                  Row(children: [
                    const Expanded(child: Text('Rest between sets')),
                    DropdownButton<int>(
                        value: flow.restSeconds,
                        items: [
                          for (final seconds in [0, 30, 60, 90, 120, 180, 300])
                            DropdownMenuItem(
                                value: seconds, child: Text('${seconds}s'))
                        ],
                        onChanged: active && !resting
                            ? (seconds) => c.setRestSeconds(seconds!)
                            : null),
                  ]),
              ]),
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Privacy & tracking'),
              leading: const Icon(Icons.verified_user_outlined,
                  color: AppColors.primary),
              children: [
                const Text(
                    'Camera tracking runs on this device. Results save locally; upload requires separate opt-in.',
                    style: TextStyle(color: AppColors.inkSoft)),
                if (widget.uploadNotice != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(widget.uploadNotice!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft))),
                const SizedBox(height: 16),
              ]),
          if (c.errorMessage != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(c.errorMessage!,
                    style: const TextStyle(color: AppColors.danger))),
          const SizedBox(height: 8),
          TextButton.icon(
              onPressed: c.viewPhase == MeasuredWorkoutPhase.saving
                  ? null
                  : widget.onDiscard,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Discard session')),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ]));
  }
}

class _PinnedWorkoutHeader extends SliverPersistentHeaderDelegate {
  _PinnedWorkoutHeader({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;
  @override
  bool shouldRebuild(_PinnedWorkoutHeader oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}
