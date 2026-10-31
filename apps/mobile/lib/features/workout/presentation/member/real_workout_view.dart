import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/pose_preview_controller.dart';
import '../../application/measured_workout_session.dart';
import 'workout_result_screen.dart';
import '../../domain/workout_contracts.dart';
import '../../domain/workout_audio_port.dart';
import '../../application/guided_workout_progress.dart';
import '../../domain/routine_workout_context.dart';
import 'widgets/workout_session_sheet.dart';
import 'widgets/workout_alignment_guide.dart';

class RealWorkoutView extends StatefulWidget {
  const RealWorkoutView(
      {super.key,
      required this.session,
      required this.viewport,
      required this.exerciseName,
      required this.targetRepetitions,
      this.uploadNotice,
      this.alignmentInstruction,
      this.routineContext,
      this.resultBuilder});
  final RoutineWorkoutContext? routineContext;
  final Widget Function(WorkoutSessionSummary)? resultBuilder;
  final MeasuredWorkoutSession session;
  final Widget viewport;
  final String exerciseName;
  final int targetRepetitions;
  final String? uploadNotice;
  final String? alignmentInstruction;
  @override
  State<RealWorkoutView> createState() => _RealWorkoutViewState();
}

class _RealWorkoutViewState extends State<RealWorkoutView> {
  bool _ending = false, _leaving = false;
  bool _completionScheduled = false;
  final _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    _sessionChanged();
  }

  @override
  void didUpdateWidget(covariant RealWorkoutView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_sessionChanged);
      widget.session.addListener(_sessionChanged);
    }
    _sessionChanged();
  }

  void _sessionChanged() {
    if (widget.routineContext == null ||
        _completionScheduled ||
        _ending ||
        _leaving ||
        widget.session.viewPhase != MeasuredWorkoutPhase.active ||
        widget.session.guidance?.stage != GuidedWorkoutStage.complete) {
      return;
    }
    _completionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _completionScheduled = false;
      if (mounted &&
          widget.routineContext != null &&
          widget.session.viewPhase == MeasuredWorkoutPhase.active &&
          widget.session.guidance?.stage == GuidedWorkoutStage.complete) {
        unawaited(_end(automatic: true));
      }
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _end({bool automatic = false}) async {
    if (_ending || _leaving) return;
    _ending = true;
    try {
      final c = widget.session;
      final wasManuallyPaused = c.isManuallyPaused;
      final completedRoutineExercise = widget.routineContext != null &&
          c.guidance?.stage == GuidedWorkoutStage.complete;
      if (!automatic &&
          !completedRoutineExercise &&
          c.viewPhase != MeasuredWorkoutPhase.saveFailed) {
        await c.pause();
        if (!mounted) return;
        final yes = await confirmSheet(context,
            title: widget.routineContext == null
                ? 'End this workout session?'
                : 'Finish this exercise early?',
            message: widget.routineContext == null
                ? 'Save the measured result on this device. Any eligible upload is tracked separately; no rewards are awarded.'
                : 'Save this partial result and return to your routine. This exercise stays unfinished so you can retry or skip it.',
            confirmLabel: 'Save result');
        if (!mounted) return;
        if (!yes) {
          if (!wasManuallyPaused) await c.resume();
          return;
        }
      }
      final result = await c.endAndSave();
      if (!mounted ||
          result == null ||
          c.viewPhase != MeasuredWorkoutPhase.saved) {
        return;
      }
      _leaving = true;
      if (widget.routineContext != null) {
        Navigator.pop(context, result);
        return;
      }
      Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
              builder: (_) =>
                  widget.resultBuilder?.call(result) ??
                  WorkoutResultScreen.measured(summary: result)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not finish the session. Retry or discard it.')));
      }
    } finally {
      _ending = false;
    }
  }

  Future<void> _discard() async {
    if (_ending || _leaving) return;
    _ending = true;
    try {
      final yes = await confirmSheet(context,
          title: 'Discard this session?',
          message: 'This unsaved result will be lost.',
          confirmLabel: 'Discard');
      if (!mounted || !yes) return;
      await widget.session.close();
      if (!mounted) return;
      setState(() => _leaving = true);
      Navigator.pop(context);
    } finally {
      _ending = false;
    }
  }

  Widget _cameraHeader(BuildContext context) {
    final c = widget.session;
    final active = c.viewPhase == MeasuredWorkoutPhase.active;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .14))),
        child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: Row(children: [
              IconButton(
                  tooltip: 'Back',
                  color: Colors.white,
                  onPressed: c.viewPhase == MeasuredWorkoutPhase.closed
                      ? () => Navigator.pop(context)
                      : _end,
                  icon: const Icon(Icons.arrow_back_rounded)),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(
                        widget.routineContext == null
                            ? 'AI WORKOUT'
                            : 'AI WORKOUT · ${widget.routineContext!.exerciseNumber} / ${widget.routineContext!.totalExercises}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3)),
                    Text(widget.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ])),
              PopupMenuButton<bool>(
                  tooltip: 'Skeleton display',
                  enabled: active,
                  initialValue: c.preview.responsivePreview,
                  onSelected: c.preview.setResponsivePreview,
                  itemBuilder: (_) => [
                        CheckedPopupMenuItem(
                            value: true,
                            checked: c.preview.responsivePreview,
                            child: const Text('Responsive · follows movement')),
                        CheckedPopupMenuItem(
                            value: false,
                            checked: !c.preview.responsivePreview,
                            child: const Text('Smooth · less shaking')),
                      ],
                  icon: const Icon(Icons.speed_rounded, color: Colors.white)),
              IconButton(
                  tooltip: 'Recalibrate camera',
                  color: Colors.white,
                  disabledColor: Colors.white38,
                  onPressed: active &&
                          !c.isManuallyPaused &&
                          !c.isRecalibrating &&
                          !(c is UnilateralWorkoutSession &&
                              (c as UnilateralWorkoutSession).awaitingArmSwitch)
                      ? () {
                          if (_sheetController.isAttached) {
                            _sheetController.reset();
                          }
                          c.beginRecalibration();
                        }
                      : null,
                  icon: const Icon(Icons.center_focus_strong_rounded)),
              PopupMenuButton<WorkoutVoiceMode>(
                  tooltip: 'Voice feedback: ${c.voiceMode.label}',
                  enabled: active,
                  initialValue: c.voiceMode,
                  onSelected: c.setVoiceMode,
                  itemBuilder: (_) => [
                        for (final mode in WorkoutVoiceMode.values)
                          CheckedPopupMenuItem(
                              value: mode,
                              checked: mode == c.voiceMode,
                              child: Text(mode.label))
                      ],
                  icon: Icon(
                      c.voiceEnabled
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: Colors.white)),
            ])));
  }

  String _cue(MeasuredWorkoutSession c) {
    if (c.viewPhase == MeasuredWorkoutPhase.closed) {
      return 'Session closed · account changed';
    }
    if (c.errorMessage != null) return c.errorMessage!;
    if (c.isManuallyPaused) return 'Paused · ready when you are';
    if (c is UnilateralWorkoutSession &&
        (c as UnilateralWorkoutSession).awaitingArmSwitch) {
      return '${(c as UnilateralWorkoutSession).armLabel} complete · turn to bring your ${(c as UnilateralWorkoutSession).nextArmLabel.toLowerCase()} closest to the camera';
    }
    if (c.guidance?.stage == GuidedWorkoutStage.complete) {
      return widget.routineContext == null
          ? 'Workout complete · save your result'
          : 'Exercise complete · saving routine progress';
    }
    if (c.guidance?.stage == GuidedWorkoutStage.resting) {
      return 'Rest · counting paused';
    }
    final u = c.analysis;
    if (u == null || !c.analysisAvailable || u.needsCalibration) {
      return c.calibrationCue;
    }
    if (u.health != TrackingStatus.healthy) {
      return 'Move fully into view · counting paused';
    }
    if (u.cues.isNotEmpty) return u.cues.first.text;
    return c.movementCue;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final c = widget.session;
        return PopScope(
            canPop: _leaving || c.viewPhase == MeasuredWorkoutPhase.closed,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) unawaited(_end());
            },
            child: Scaffold(
                backgroundColor: AppColors.ink,
                body: LayoutBuilder(builder: (context, bounds) {
                  final safeTop = MediaQuery.paddingOf(context).top;
                  final collapsedHeight = WorkoutSessionSheet.collapsedHeight(
                      context, bounds.maxHeight);
                  return Stack(fit: StackFit.expand, children: [
                    // Stable, full-screen constraints throughout every sheet gesture.
                    Positioned.fill(
                        child: RepaintBoundary(child: widget.viewport)),
                    const Positioned.fill(
                        child: IgnorePointer(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.center,
                                        colors: [
                          Colors.black38,
                          Colors.transparent
                        ]))))),
                    Positioned(
                        top: safeTop + 8,
                        left: 12,
                        right: 12,
                        child: _cameraHeader(context)),
                    if (!c.isRecalibrating)
                      Positioned(
                          top: safeTop + 80,
                          left: 16,
                          right: 16,
                          child: Align(
                              alignment: Alignment.topLeft,
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: .55),
                                      borderRadius: BorderRadius.circular(14)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            c.isManuallyPaused
                                                ? Icons
                                                    .pause_circle_outline_rounded
                                                : c.guidance?.stage ==
                                                        GuidedWorkoutStage
                                                            .resting
                                                    ? Icons.timer_outlined
                                                    : Icons
                                                        .accessibility_new_rounded,
                                            size: 16,
                                            color: Colors.white),
                                        const SizedBox(width: 8),
                                        Flexible(
                                            child: Text(_cue(c),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w500))),
                                      ])))),
                    if (c.preview.phase == PosePreviewPhase.opening)
                      const Positioned(
                          top: 160,
                          left: 24,
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))),
                    if (c.isRecalibrating)
                      Positioned(
                          top: safeTop + 76,
                          left: 12,
                          right: 12,
                          bottom: collapsedHeight + 8,
                          child: WorkoutAlignmentGuide(
                              instruction: widget.alignmentInstruction,
                              canConfirm: c.canConfirmRecalibration,
                              onConfirm: c.finishRecalibration)),
                    Positioned.fill(
                        child: WorkoutSessionSheet(
                            session: c,
                            controller: _sheetController,
                            exerciseName: widget.exerciseName,
                            targetRepetitions: widget.targetRepetitions,
                            routineContext: widget.routineContext,
                            uploadNotice: widget.uploadNotice,
                            onEnd: _end,
                            onDiscard: _discard)),
                  ]);
                })));
      });
}
