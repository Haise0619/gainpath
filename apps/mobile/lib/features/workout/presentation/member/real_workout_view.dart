import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/pose_preview_controller.dart';
import '../../application/workout_preferences_controller.dart';
import '../../application/workout_set_continuation.dart';
import '../../application/workout_voice_session.dart';
import '../../domain/retained_workout_feedback.dart';
import '../../application/measured_workout_session.dart';
import 'workout_result_screen.dart';
import '../../domain/workout_contracts.dart';
import '../../domain/workout_audio_port.dart';
import '../../application/guided_workout_progress.dart';
import '../../domain/routine_workout_context.dart';
import 'widgets/workout_session_sheet.dart';
import 'widgets/workout_alignment_guide.dart';
import 'widgets/workout_camera_feedback.dart';
import 'workout_ai_consent_guard.dart';

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
  int? _announcedReadySet;
  final _sheetController = DraggableScrollableController();
  WorkoutPreferencesController? _preferences;

  WorkoutSetContinuation? _continuationFor(MeasuredWorkoutSession session) =>
      session is WorkoutSetContinuationSession
          ? (session as WorkoutSetContinuationSession).setContinuation
          : null;

  WorkoutSetContinuation? get _continuation => _continuationFor(widget.session);

  void _applySetPreference() {
    final preferences = _preferences;
    if (preferences == null) return;
    final continuation = _continuation;
    if (!preferences.validConsent) continuation?.cancel();
    continuation?.setEnabled(
        preferences.validConsent && preferences.autoContinueBetweenSets);
  }

  void _applyCompletionCopy() {
    final continuation = _continuation;
    if (continuation != null) {
      continuation.completionAnnouncement =
          widget.routineContext?.nextExerciseName == null
              ? 'Workout complete.'
              : 'Exercise complete.';
    }
  }

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    _applyCompletionCopy();
    _sessionChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final preferences = WorkoutAiConsentGuard.preferencesOf(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_applySetPreference);
      _preferences = preferences;
      _preferences?.addListener(_applySetPreference);
      _applySetPreference();
    }
  }

  @override
  void didUpdateWidget(covariant RealWorkoutView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _announcedReadySet = null;
      oldWidget.session.removeListener(_sessionChanged);
      _continuationFor(oldWidget.session)?.cancel();
      widget.session.addListener(_sessionChanged);
      _applySetPreference();
    }
    _applyCompletionCopy();
    _sessionChanged();
  }

  void _sessionChanged() {
    final session = widget.session;
    final flow = session.guidance;
    final analysis = session.analysis;
    final set = flow?.completedSets ?? 0;
    if (_announcedReadySet != set &&
        !_ending &&
        !_leaving &&
        session is WorkoutVoiceSession &&
        session.voiceMode == WorkoutVoiceMode.fullCoaching &&
        session.viewPhase == MeasuredWorkoutPhase.active &&
        session.preview.phase == PosePreviewPhase.tracking &&
        !session.isPaused &&
        !session.isRecalibrating &&
        (flow == null || flow.stage == GuidedWorkoutStage.working) &&
        session.analysisAvailable &&
        analysis != null &&
        !analysis.needsCalibration &&
        analysis.health == TrackingStatus.healthy &&
        (flow?.setRepetitions ?? analysis.repetitions) == 0) {
      final announced = (session as WorkoutVoiceSession)
          .voiceFeedback
          .announceTransition('tracking-ready-$set', 'Ready.',
              nowMicros: session.preview.clockMicros());
      if (announced) _announcedReadySet = set;
    }
    if (widget.routineContext == null ||
        _completionScheduled ||
        _ending ||
        _leaving ||
        widget.session.isManuallyPaused ||
        widget.session.viewPhase != MeasuredWorkoutPhase.active ||
        widget.session.guidance?.stage != GuidedWorkoutStage.complete) {
      return;
    }
    _completionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _completionScheduled = false;
      if (mounted &&
          widget.routineContext != null &&
          !widget.session.isManuallyPaused &&
          widget.session.viewPhase == MeasuredWorkoutPhase.active &&
          widget.session.guidance?.stage == GuidedWorkoutStage.complete) {
        unawaited(_end(automatic: true));
      }
    });
  }

  @override
  void dispose() {
    _preferences?.removeListener(_applySetPreference);
    widget.session.removeListener(_sessionChanged);
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _end({bool automatic = false}) async {
    if (_ending || _leaving) return;
    final session = widget.session;
    if (!automatic &&
        session.viewPhase == MeasuredWorkoutPhase.active &&
        session.analysis == null &&
        session.preview.receivedFrames == 0) {
      await _discard(noCapture: true);
      return;
    }
    _ending = true;
    try {
      final c = widget.session;
      final wasManuallyPaused = c.isManuallyPaused;
      final completedRoutineExercise = widget.routineContext != null &&
          c.guidance?.stage == GuidedWorkoutStage.complete;
      if (!automatic &&
          !completedRoutineExercise &&
          c.viewPhase != MeasuredWorkoutPhase.saveFailed) {
        // Counting pauses synchronously. Do not hide the confirmation behind
        // a slow native camera shutdown; still await it before resume/save.
        final pausing = c.pause();
        if (!mounted) return;
        final yes = await confirmSheet(context,
            title: widget.routineContext == null
                ? 'End this workout session?'
                : 'Finish this exercise early?',
            message: widget.routineContext == null
                ? 'Save the measured result on this device. Any eligible upload is tracked separately; no rewards are awarded.'
                : 'Save this partial result and return to your routine. This exercise stays unfinished so you can retry or skip it.',
            confirmLabel: 'Save result');
        await pausing;
        if (!mounted) return;
        if (!yes) {
          if (!wasManuallyPaused) await c.resume();
          return;
        }
      }
      final result = await c.endAndSave();
      if (!automatic &&
          mounted &&
          result == null &&
          c.viewPhase == MeasuredWorkoutPhase.active &&
          c.preview.phase == PosePreviewPhase.failure) {
        _ending = false;
        await _discard();
        return;
      }
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

  Future<void> _discard({bool noCapture = false}) async {
    if (_ending || _leaving) return;
    _ending = true;
    try {
      final yes = await confirmSheet(context,
          title: noCapture ? 'Leave this exercise?' : 'Discard this session?',
          message: noCapture
              ? 'Leave without saving. You can try this exercise again.'
              : 'This unsaved result will be lost.',
          confirmLabel: noCapture ? 'Leave exercise' : 'Discard');
      if (!mounted || !yes) return;
      setState(() => _leaving = true);
      // Close invalidates capture immediately. Native cleanup keeps its own
      // camera lease and can finish after the screen has been dismissed.
      unawaited(widget.session.close().catchError((Object _) {}));
      Navigator.pop(context);
    } finally {
      _ending = false;
    }
  }

  Widget _cameraHeader(BuildContext context) {
    final c = widget.session;
    final active = c.viewPhase == MeasuredWorkoutPhase.active;
    final voice = c is WorkoutVoiceSession
        ? (c as WorkoutVoiceSession).voiceFeedback
        : null;
    return LayoutBuilder(builder: (context, bounds) {
      final compact = bounds.maxWidth < 350 ||
          MediaQuery.textScalerOf(context).scale(14) > 19;
      final routine = widget.routineContext;
      return Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: Row(children: [
            IconButton(
              tooltip: 'Back',
              color: Colors.white,
              onPressed: c.viewPhase == MeasuredWorkoutPhase.closed
                  ? () => Navigator.pop(context)
                  : _end,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (routine != null && !compact)
                    Text(
                        'Exercise ${routine.exerciseNumber} of ${routine.totalExercises}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  Text(widget.exerciseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.1,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (!compact)
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
                icon: const Icon(Icons.speed_rounded, color: Colors.white),
              ),
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
                      if (_sheetController.isAttached) _sheetController.reset();
                      c.beginRecalibration();
                    }
                  : null,
              icon: const Icon(Icons.center_focus_strong_rounded),
            ),
            if (voice?.availability.value ==
                WorkoutVoiceAvailability.unavailable)
              IconButton(
                tooltip: 'Retry voice feedback',
                color: Colors.white,
                onPressed: active ? voice!.retryVoice : null,
                icon: const Icon(Icons.refresh_rounded),
              ),
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
                      child: Text(mode.label)),
                if (compact) ...[
                  const PopupMenuDivider(),
                  for (final responsive in [true, false])
                    CheckedPopupMenuItem<WorkoutVoiceMode>(
                      checked: c.preview.responsivePreview == responsive,
                      onTap: () => c.preview.setResponsivePreview(responsive),
                      child: Text(responsive
                          ? 'Responsive skeleton'
                          : 'Smooth skeleton'),
                    ),
                ],
              ],
              icon: Icon(
                  c.voiceEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: Colors.white),
            ),
          ]),
        ),
      );
    });
  }

  Widget? _voiceStatus(MeasuredWorkoutSession c) {
    if (c is! WorkoutVoiceSession || !c.voiceEnabled) return null;
    final feedback = (c as WorkoutVoiceSession).voiceFeedback;
    final availability = feedback.availability.value;
    final text = switch (availability) {
      WorkoutVoiceAvailability.preparing =>
        'Voice preparing · visual feedback active',
      WorkoutVoiceAvailability.unavailable =>
        'Voice unavailable · visual feedback active',
      WorkoutVoiceAvailability.ready => 'Voice ready',
      WorkoutVoiceAvailability.muted => null,
    };
    if (text == null) return null;
    return DecoratedBox(
      decoration: BoxDecoration(
          color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  String _cue(MeasuredWorkoutSession c) {
    if (c.viewPhase == MeasuredWorkoutPhase.closed) {
      return 'Session closed · account changed';
    }
    if (c.errorMessage != null) return c.errorMessage!;
    if (c.isManuallyPaused) {
      return 'Workout paused · Resume when ready. No repetitions are counted while paused.';
    }
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
      return 'Rest between sets · counting paused';
    }
    final u = c.analysis;
    if (c is WorkoutReadinessFeedback) {
      return (c as WorkoutReadinessFeedback).readinessMessage;
    }
    if (u == null || !c.analysisAvailable || u.needsCalibration) {
      return c.calibrationCue;
    }
    if (u.health != TrackingStatus.healthy) {
      return 'Move fully into view · counting paused';
    }
    if (u.cues.isNotEmpty) {
      return c is WorkoutVoiceSession
          ? primaryWorkoutCue(u.cues)!.text
          : u.cues.first.text;
    }
    return c.movementCue;
  }

  Widget _cameraPane(BuildContext context, MeasuredWorkoutSession c) {
    final position = WorkoutCameraPosition.forSession(c);
    final voiceStatus = _voiceStatus(c);
    final continuation = _continuation;
    final canPauseRest = continuation != null &&
        c.guidance?.stage == GuidedWorkoutStage.resting &&
        c.viewPhase == MeasuredWorkoutPhase.active &&
        c.preview.phase == PosePreviewPhase.tracking &&
        !c.isManuallyPaused;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _cameraHeader(context),
      const SizedBox(height: 8),
      Expanded(
        child: c.isRecalibrating
            ? WorkoutAlignmentGuide(
                instruction:
                    widget.alignmentInstruction ?? position?.instruction,
                canConfirm: c.canConfirmRecalibration,
                onConfirm: c.finishRecalibration)
            : SingleChildScrollView(
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (position != null)
                      WorkoutCameraFeedback(
                          session: c,
                          position: position,
                          continuation: continuation,
                          inRoutine: widget.routineContext != null)
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(_cue(c),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ),
                      ),
                    if (canPauseRest) ...[
                      const SizedBox(height: 6),
                      FilledButton.tonal(
                          onPressed: () => unawaited(c.pause()),
                          child: const Text('Pause')),
                    ],
                    if (voiceStatus != null) ...[
                      const SizedBox(height: 6),
                      voiceStatus,
                    ],
                  ],
                ),
              ),
      ),
    ]);
  }

  WorkoutSessionSheet _controls(MeasuredWorkoutSession session,
          {bool sidePanel = false}) =>
      WorkoutSessionSheet(
          session: session,
          controller: _sheetController,
          exerciseName: widget.exerciseName,
          targetRepetitions: widget.targetRepetitions,
          routineContext: widget.routineContext,
          uploadNotice: widget.uploadNotice,
          sidePanel: sidePanel,
          onEnd: _end,
          onDiscard: _discard);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([
        widget.session,
        if (widget.session is WorkoutVoiceSession)
          (widget.session as WorkoutVoiceSession).voiceFeedback.availability,
        if (_continuation case final continuation?) continuation,
      ]),
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
              final safe = MediaQuery.paddingOf(context);
              final landscape =
                  bounds.maxWidth > bounds.maxHeight && bounds.maxWidth >= 520;
              final sidePanelWidth = ((bounds.maxWidth - safe.horizontal) * .43)
                  .clamp(236.0, 360.0);
              final collapsedHeight = WorkoutSessionSheet.collapsedHeight(
                  context, bounds.biggest, c);
              return Stack(fit: StackFit.expand, children: [
                // Coaching and sheet updates keep the same preview element
                // and constraints. Landscape reserves space for the controls.
                Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    right: landscape
                        ? sidePanelWidth + 8 + (safe.right < 8 ? 8 : safe.right)
                        : 0,
                    child: RepaintBoundary(child: widget.viewport)),
                if (landscape)
                  Positioned.fill(
                    key: const ValueKey('workout-landscape-layer'),
                    child: SafeArea(
                      minimum: const EdgeInsets.all(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _cameraPane(context, c)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: sidePanelWidth,
                            child: _controls(c, sidePanel: true),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ListenableBuilder(
                    listenable: _sheetController,
                    child: _cameraPane(context, c),
                    builder: (context, child) {
                      final sheetHeight = _sheetController.isAttached
                          ? _sheetController.pixels
                          : collapsedHeight;
                      return Positioned(
                        top: safe.top + 8,
                        left: safe.left + 12,
                        right: safe.right + 12,
                        bottom: sheetHeight + 6,
                        child: child!,
                      );
                    },
                  ),
                  Positioned.fill(
                    key: const ValueKey('workout-session-sheet-layer'),
                    child: _controls(c),
                  ),
                ],
              ]);
            }),
          ),
        );
      });
}
