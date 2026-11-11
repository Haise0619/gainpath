import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../application/guided_workout_progress.dart';
import '../../../application/pose_preview_controller.dart';
import '../../../application/measured_workout_session.dart';
import '../../../application/workout_set_continuation.dart';
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
      this.uploadNotice,
      this.sidePanel = false});
  final RoutineWorkoutContext? routineContext;
  final MeasuredWorkoutSession session;
  final DraggableScrollableController controller;
  final String exerciseName;
  final int targetRepetitions;
  final VoidCallback onEnd, onDiscard;
  final String? uploadNotice;
  final bool sidePanel;

  static bool _stackControls(BuildContext context, double width) {
    final safe = MediaQuery.paddingOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return (width - safe.horizontal) / scale < 382;
  }

  static double _actionHeight(BuildContext context) =>
      math.max(48, MediaQuery.textScalerOf(context).scale(13) * 2 * 1.12 + 12);

  static double collapsedHeight(
      BuildContext context, Size size, MeasuredWorkoutSession session) {
    final scale = MediaQuery.textScalerOf(context);
    final stacked = _stackControls(context, size.width);
    final twoLabelLines = session is UnilateralWorkoutSession && stacked;
    final metricHeight = scale.scale(11) * 1.2 * (twoLabelLines ? 2 : 1) +
        scale.scale(38) * 1.08;
    final actions = _actionHeight(context);
    final rows =
        stacked ? metricHeight + 4 + actions : math.max(metricHeight, actions);
    // The drag handle, progress track and safe area have fixed padding. The
    // metric and action rows reserve their own scaled text height.
    final needed = 16 + rows + 12 + MediaQuery.paddingOf(context).bottom;
    return math.max(size.height * .18, needed.ceilToDouble());
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
  void didUpdateWidget(covariant WorkoutSessionSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sidePanel != widget.sidePanel) _expanded = false;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_extentChanged);
    super.dispose();
  }

  void _toggle() {
    if (widget.sidePanel) {
      setState(() => _expanded = !_expanded);
      return;
    }
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
        final headerHeight = WorkoutSessionSheet.collapsedHeight(
            context, bounds.biggest, widget.session);
        final header = _header(context, bounds.maxWidth);
        if (widget.sidePanel) {
          return _surface(headerHeight > bounds.maxHeight
              ? SingleChildScrollView(
                  child: Column(children: [
                  SizedBox(height: headerHeight, child: header),
                  if (_expanded) _details(context),
                ]))
              : Column(children: [
                  SizedBox(height: headerHeight, child: header),
                  if (_expanded)
                    Expanded(
                        child: SingleChildScrollView(child: _details(context))),
                ]));
        }
        _minExtent = headerHeight / bounds.maxHeight;
        _maxExtent = math.max(.55, _minExtent + .2).clamp(0, .92);
        return DraggableScrollableSheet(
          controller: widget.controller,
          initialChildSize: _minExtent,
          minChildSize: _minExtent,
          maxChildSize: _maxExtent,
          snap: true,
          snapSizes: [_minExtent, _maxExtent],
          snapAnimationDuration: const Duration(milliseconds: 220),
          shouldCloseOnMinExtent: false,
          builder: (context, scrollController) => _surface(CustomScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedWorkoutHeader(
                        height: headerHeight, child: header)),
                if (_expanded) SliverToBoxAdapter(child: _details(context)),
              ])),
        );
      });

  Widget _surface(Widget child) => Material(
        key: const ValueKey('workout-sheet-surface'),
        color: AppColors.surface,
        elevation: 12,
        shadowColor: Colors.black38,
        borderRadius: widget.sidePanel
            ? BorderRadius.circular(22)
            : const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _header(BuildContext context, double width) {
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
    final continuation = c is WorkoutSetContinuationSession
        ? (c as WorkoutSetContinuationSession).setContinuation
        : null;
    final countingDown =
        resting && continuation?.status == SetContinuationStatus.countdown;
    final setLabel = flow == null
        ? 'LIVE WORKOUT'
        : 'SET ${resting && !countingDown ? flow.completedSets : flow.currentSet} / ${flow.sets}';
    final currentReps = arm?.armRepetitionLabel.split(' / ').first ??
        '${flow?.setRepetitions ?? c.analysis?.repetitions ?? 0}';
    final target = flow?.repetitions ?? widget.targetRepetitions;
    final (value, suffix, valueDescription) =
        switch ((saving, resting, complete)) {
      (true, _, _) => ('Saving…', '', 'Saving result'),
      (_, true, _) when countingDown => (
          '${continuation!.remainingSeconds}',
          ' s',
          '${continuation.remainingSeconds} seconds until next set'
        ),
      (_, true, _) => (
          '${flow!.remainingRestSeconds}',
          ' s',
          '${flow.remainingRestSeconds} seconds of rest remaining'
        ),
      (_, _, true) => ('Complete', '', 'Target complete'),
      _ => (currentReps, ' / $target', '$currentReps of $target repetitions'),
    };
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

    final primaryText =
        switch ((retry, saving, complete, paused, switching, resting)) {
      (true, _, _, _, _, _) => 'Retry save',
      (_, true, _, _, _, _) => 'Saving…',
      (_, _, true, _, _, _) =>
        widget.routineContext == null ? 'Save result' : 'Continue',
      (_, _, _, true, _, _) => c.isManuallyPaused ? 'Resume' : 'Retry camera',
      (_, _, _, _, true, _) => 'Switch arm',
      (_, _, _, _, _, true) => 'Next set',
      _ => 'Pause',
    };
    final primaryEnabled = (active || retry) && !saving && !c.isRecalibrating;
    final safe = MediaQuery.paddingOf(context);
    final stacked = WorkoutSessionSheet._stackControls(context, width);
    final metric = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          resting
              ? '${countingDown ? 'NEXT' : 'REST'} · $setLabel'
              : arm != null
                  ? '${arm.armLabel.toUpperCase()} · $setLabel'
                  : setLabel,
          maxLines: arm != null && stacked ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
              color: AppColors.primaryDark),
        ),
        Semantics(
          label: valueDescription,
          excludeSemantics: true,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(text: value, children: [
                TextSpan(
                    text: suffix,
                    style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w700)),
              ]),
              key: const ValueKey('workout-rep-counter'),
              style: TextStyle(
                  fontSize: saving || complete && !resting ? 25 : 38,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: AppColors.ink),
            ),
          ),
        ),
      ],
    );
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      textStyle: const TextStyle(
          fontSize: 13, height: 1.12, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    final primaryButton = Tooltip(
      message: primaryLabel,
      child: FilledButton(
        style: buttonStyle.merge(FilledButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: Colors.white)),
        onPressed: primaryEnabled ? primary : null,
        child: Text(primaryText, textAlign: TextAlign.center),
      ),
    );
    final actions = SizedBox(
      height: WorkoutSessionSheet._actionHeight(context),
      child: Row(
          mainAxisSize: stacked ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (stacked) Expanded(child: primaryButton) else primaryButton,
            const SizedBox(width: 6),
            Tooltip(
              message: widget.routineContext == null
                  ? 'End session'
                  : 'Finish exercise early',
              child: FilledButton.tonal(
                style: buttonStyle.merge(FilledButton.styleFrom(
                    backgroundColor: AppColors.dangerTint,
                    foregroundColor: AppColors.ink)),
                onPressed: saving || c.viewPhase == MeasuredWorkoutPhase.closed
                    ? null
                    : widget.onEnd,
                child: const Text('Stop'),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: _expanded
                  ? 'Collapse workout details'
                  : 'Expand workout details',
              onPressed: _toggle,
              color: AppColors.primaryDark,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: Icon(_expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded),
            ),
          ]),
    );
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16 + safe.left, 0, 12 + safe.right, 4 + safe.bottom),
        child: Column(children: [
          GestureDetector(
            key: const ValueKey('workout-sheet-handle'),
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            excludeFromSemantics: true,
            child: SizedBox(
              height: 16,
              width: double.infinity,
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          Expanded(
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Expanded(
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: metric)),
                        const SizedBox(height: 4),
                        actions,
                      ])
                : Row(children: [
                    Expanded(child: metric),
                    const SizedBox(width: 6),
                    actions,
                  ]),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                color: AppColors.primary,
                backgroundColor: AppColors.primaryTint,
                semanticsLabel: 'Workout progress'),
          ),
        ]),
      ),
    );
  }

  Widget _details(BuildContext context) {
    final c = widget.session, u = c.analysis, flow = c.guidance;
    final active = c.viewPhase == MeasuredWorkoutPhase.active;
    final resting = flow?.stage == GuidedWorkoutStage.resting;
    final arm =
        c is UnilateralWorkoutSession ? c as UnilateralWorkoutSession : null;
    final safe = MediaQuery.paddingOf(context);
    return Padding(
        padding: EdgeInsets.fromLTRB(18 + safe.left, 4, 18 + safe.right, 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (arm != null) ...[
            CurlArmStats(metrics: arm.armMetrics),
            if (arm.awaitingArmSwitch) ...[
              Text(
                  'Turn side-on with your ${arm.nextArmLabel.toLowerCase()} closest to the camera, then tap Switch arm. Lower the arm to recalibrate.'),
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
              (u == null ? '—' : '${u.repetitions}', 'Full reps'),
              (u == null ? '—' : '${u.partialRepetitions}', 'Partial reps'),
              (
                u == null
                    ? '—'
                    : '${(u.trackedDurationMicros / 1000000).floor()}s',
                'Tracked time'
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
                          for (final seconds
                              in ({
                            0,
                            30,
                            60,
                            90,
                            120,
                            180,
                            300,
                            flow.restSeconds
                          }.toList()
                                ..sort()))
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
