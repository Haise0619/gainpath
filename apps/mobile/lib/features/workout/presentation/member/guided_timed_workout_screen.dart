import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/guided_timed_workout_controller.dart';
import '../../domain/guided_timed_progress.dart';
import '../workout_presentation.dart';

/// Display only; time credit and durable state remain controller-owned.
class GuidedTimedWorkoutScreen extends StatefulWidget {
  const GuidedTimedWorkoutScreen(
      {super.key,
      required this.controller,
      required this.exerciseName,
      required this.onBack,
      required this.onSkip,
      required this.onCompleted});
  final GuidedTimedWorkoutController controller;
  final String exerciseName;
  final Future<void> Function() onBack, onSkip;
  final VoidCallback onCompleted;
  @override
  State<GuidedTimedWorkoutScreen> createState() =>
      _GuidedTimedWorkoutScreenState();
}

class _GuidedTimedWorkoutScreenState extends State<GuidedTimedWorkoutScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Progress could not be saved. Retry before leaving.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _time(int micros) {
    final seconds = (micros / 1000000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller, p = c.progress, phase = p.phase;
        final complete = phase == GuidedTimedPhase.completed;
        final paused = phase == GuidedTimedPhase.paused ||
            phase == GuidedTimedPhase.interrupted;
        final resting = phase == GuidedTimedPhase.resting;
        final retrySave = c.interruptionReason == 'save failed';
        final retryVideo = !c.player.ready ||
            c.player.error != null ||
            c.interruptionReason == 'playback failed';
        final showRest =
            resting || paused && p.phaseBeforePause == GuidedTimedPhase.resting;
        final phaseLabel = switch (phase) {
          GuidedTimedPhase.loading => 'Loading video',
          GuidedTimedPhase.ready => 'Ready when you are',
          GuidedTimedPhase.working => 'Working',
          GuidedTimedPhase.resting => 'Rest',
          GuidedTimedPhase.interrupted when retrySave => 'Save failed',
          GuidedTimedPhase.interrupted when retryVideo => 'Video unavailable',
          GuidedTimedPhase.interrupted when c.player.buffering => 'Buffering',
          GuidedTimedPhase.paused || GuidedTimedPhase.interrupted => 'Paused',
          GuidedTimedPhase.saving => 'Saving progress',
          GuidedTimedPhase.completed => 'Timer completed',
        };
        String? primaryLabel;
        Future<void> Function()? primary;
        if (phase == GuidedTimedPhase.ready) {
          primaryLabel = 'Start Timed Workout';
          primary = c.start;
        } else if (phase == GuidedTimedPhase.working) {
          primaryLabel = 'Pause';
          primary = c.pause;
        } else if (resting) {
          if (p.restKind == GuidedTimedRestKind.midSet) {
            primaryLabel = 'Resume set ${p.completedSets + 1}';
            primary = c.resumeCurrentSet;
          } else {
            primaryLabel = p.remainingRestMicroseconds > 0
                ? 'Skip rest & start next set'
                : 'Start next set';
            primary =
                () => c.startNextSet(skipRest: p.remainingRestMicroseconds > 0);
          }
        } else if (paused) {
          primaryLabel = retrySave
              ? 'Retry save'
              : retryVideo
              ? 'Retry video'
              : p.completed
                  ? 'Retry save'
                  : 'Resume';
          primary = retrySave
              ? c.retryProgressSave
              : retryVideo
                  ? c.initialize
                  : c.resume;
        } else if (complete) {
          primaryLabel = 'Return to routine';
          primary = () async => widget.onCompleted();
        }
        return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _run(widget.onBack);
            },
            child: Scaffold(
              appBar: AppBar(
                  title: Text(widget.exerciseName),
                  leading: IconButton(
                      tooltip: 'Back to routine',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _busy ? null : () => _run(widget.onBack))),
              bottomNavigationBar: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (primaryLabel != null)
                          FilledButton(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14)),
                              onPressed: _busy || primary == null
                                  ? null
                                  : () => _run(primary!),
                              child: Text(primaryLabel,
                                  textAlign: TextAlign.center)),
                        if (phase == GuidedTimedPhase.working || resting)
                          OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(resting ? c.pause : c.rest),
                              child: Text(resting ? 'Pause' : 'Rest')),
                        if (!complete)
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _run(widget.onSkip),
                              child: const Text('Skip exercise')),
                      ])),
              body: SafeArea(
                  bottom: false,
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Chip(
                                  avatar: Icon(Icons.timer_outlined, size: 18),
                                  label: Text('Video Timed')),
                              Text(
                                  'Set ${(p.completedSets + 1).clamp(1, p.prescription.sets)} of ${p.prescription.sets}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ]),
                        const Text('Not AI verified'),
                        const SizedBox(height: 12),
                        Panel(
                            background: AppColors.primaryTint,
                            child: Column(children: [
                              Semantics(
                                  liveRegion: true,
                                  child: Text(phaseLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge)),
                              if (!complete)
                                Semantics(
                                    liveRegion: false,
                                    label: showRest
                                        ? 'Rest remaining'
                                        : 'Set time remaining',
                                    child: Text(
                                        _time(showRest
                                            ? p.remainingRestMicroseconds
                                            : p.targetMicroseconds -
                                                p.currentSetActiveMicroseconds),
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary))),
                              if (complete)
                                const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.check_circle_rounded,
                                        color: AppColors.primary, size: 48)),
                              Text(
                                  '${p.completedSets}/${p.prescription.sets} sets recorded · ${workoutDurationLabel(p.totalActiveMicroseconds)} active',
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                  value: p.totalActiveMicroseconds /
                                      (p.targetMicroseconds *
                                          p.prescription.sets),
                                  semanticsLabel: 'Timed workout progress'),
                              const SizedBox(height: 8),
                              Text(
                                  complete
                                      ? 'Saved on this device · Timer recorded'
                                      : '${p.prescription.durationSeconds} sec per set · ${p.prescription.restSeconds} sec rest between sets',
                                  textAlign: TextAlign.center),
                            ])),
                        if (showRest)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(p.restKind ==
                                      GuidedTimedRestKind.midSet
                                  ? 'This set is unfinished. Resume when you are ready.'
                                  : 'Start the next set when you are ready.')),
                        if (c.interruptionReason != null || _error != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                      _error ??
                                          (c.interruptionReason == 'buffering'
                                              ? 'Video buffering. Your timer is paused.'
                                              : c.interruptionReason ==
                                                      'save failed'
                                                  ? 'Save failed. Retry to retain this progress.'
                                                  : c.player.error != null ||
                                                          !c.player.ready
                                                      ? 'Video playback is unavailable. Retry video before continuing; inactive time is not recorded.'
                                                      : 'Your workout is paused. Resume when you are ready; inactive time is not recorded.'),
                                      style: TextStyle(
                                          color: _error != null
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .error
                                              : AppColors.inkSoft)))),
                        if (phase == GuidedTimedPhase.loading ||
                            phase == GuidedTimedPhase.saving)
                          const Padding(
                              padding: EdgeInsets.all(16),
                              child:
                                  Center(child: CircularProgressIndicator())),
                        const SizedBox(height: 16),
                        if (c.player.ready)
                          ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                  aspectRatio: c.player.aspectRatio.isFinite &&
                                          c.player.aspectRatio > 0
                                      ? c.player.aspectRatio
                                      : 16 / 9,
                                  child: c.player.buildVideo())),
                        const SizedBox(height: 12),
                        const Text(
                            'The video repeats while you train. Only active workout time is recorded; repetitions and form are not measured.',
                            style: TextStyle(color: AppColors.inkSoft)),
                      ])),
            ));
      });
}
