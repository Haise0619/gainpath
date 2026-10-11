import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/pose_preview_controller.dart';
import '../../application/real_squat_session_controller.dart';
import 'workout_result_screen.dart';
import '../../domain/workout_contracts.dart';

class RealWorkoutView extends StatefulWidget {
  const RealWorkoutView(
      {super.key,
      required this.session,
      required this.viewport,
      required this.exerciseName,
      required this.targetRepetitions,
      this.resultBuilder});
  final Widget Function(WorkoutSessionSummary)? resultBuilder;
  final RealSquatSessionController session;
  final Widget viewport;
  final String exerciseName;
  final int targetRepetitions;
  @override
  State<RealWorkoutView> createState() => _RealWorkoutViewState();
}

class _RealWorkoutViewState extends State<RealWorkoutView> {
  bool _ending = false, _leaving = false;
  Future<void> _end() async {
    if (_ending || _leaving) return;
    _ending = true;
    try {
      final c = widget.session;
      final wasPaused = c.isPaused;
      if (c.phase != RealSquatSessionPhase.saveFailed) {
        await c.pause();
        if (!mounted) return;
        final yes = await confirmSheet(context,
            title: 'End this squat session?',
            message:
                'Save the measured result on this device. Upload and rewards are not available yet.',
            confirmLabel: 'Save result');
        if (!mounted) return;
        if (!yes) {
          if (!wasPaused) await c.resume();
          return;
        }
      }
      final result = await c.endAndSave();
      if (!mounted ||
          result == null ||
          c.phase != RealSquatSessionPhase.saved) {
        return;
      }
      _leaving = true;
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final c = widget.session, u = c.latest;
        final saving = c.phase == RealSquatSessionPhase.saving;
        final active = c.phase == RealSquatSessionPhase.active;
        final closed = c.phase == RealSquatSessionPhase.closed;
        final status = c.isPaused
            ? 'Paused'
            : u == null || c.processing.update == null || u.needsCalibration
                ? 'Stand upright, fully in view, to calibrate'
                : u.health != TrackingStatus.healthy
                    ? 'Tracking interrupted · counting paused'
                    : switch (u.phase) {
                        SquatPhase.ready => 'Ready',
                        SquatPhase.eccentric => 'Lowering',
                        SquatPhase.inflection => 'Bottom position',
                        SquatPhase.concentric => 'Rising'
                      };
        return PopScope(
            canPop: _leaving || closed,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) unawaited(_end());
            },
            child: Scaffold(
                backgroundColor: AppColors.ink,
                appBar: AppBar(title: Text(widget.exerciseName), actions: [
                  IconButton(
                      tooltip:
                          c.voiceEnabled ? 'Turn voice off' : 'Turn voice on',
                      onPressed: active
                          ? () => c.setVoiceEnabled(!c.voiceEnabled)
                          : null,
                      icon: Icon(
                          c.voiceEnabled ? Icons.volume_up : Icons.volume_off))
                ]),
                body: SafeArea(
                    child: Column(children: [
                  Expanded(
                      child: Stack(fit: StackFit.expand, children: [
                    widget.viewport,
                    Positioned(
                        left: 16,
                        right: 16,
                        top: 12,
                        child: Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.black87,
                            child: Text(
                                closed
                                    ? 'Session closed · account changed'
                                    : status,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16)))),
                    if (c.preview.phase == PosePreviewPhase.opening)
                      const Center(child: CircularProgressIndicator()),
                  ])),
                  Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Wrap(
                            spacing: 20,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              Text(
                                  '${u?.repetitions ?? 0} full reps · target ${widget.targetRepetitions}'),
                              Text(
                                  '${u?.partialRepetitions ?? 0} partial reps'),
                              Text(
                                  '${((u?.trackedDurationMicros ?? 0) / 1000000).floor()}s tracked'),
                              Text(u?.formScorePercent == null
                                  ? 'Form: not enough evidence'
                                  : 'Estimated form: ${u!.formScorePercent!.round()}%'),
                            ]),
                        const SizedBox(height: 8),
                        const Text('Side-view squat · provisional guidance',
                            style: TextStyle(fontSize: 12)),
                        if (c.errorMessage != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(c.errorMessage!,
                                  style: const TextStyle(
                                      color: AppColors.warning))),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: active
                                      ? () => unawaited(c.isPaused ||
                                              c.preview.phase ==
                                                  PosePreviewPhase.failure
                                          ? c.resume()
                                          : c.pause())
                                      : null,
                                  child: Text(c.isPaused ||
                                          c.preview.phase ==
                                              PosePreviewPhase.failure
                                      ? 'Resume / retry camera'
                                      : 'Pause'))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: FilledButton(
                                  onPressed: saving || closed ? null : _end,
                                  child: Text(saving
                                      ? 'Saving…'
                                      : c.phase ==
                                              RealSquatSessionPhase.saveFailed
                                          ? 'Retry save'
                                          : 'End session'))),
                        ]),
                        TextButton(
                            onPressed: saving
                                ? null
                                : closed
                                    ? () => Navigator.pop(context)
                                    : _discard,
                            child: Text(closed ? 'Back' : 'Discard session')),
                      ])),
                ]))));
      });
}
