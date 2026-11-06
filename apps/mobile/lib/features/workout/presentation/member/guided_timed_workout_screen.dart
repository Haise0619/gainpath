import 'package:flutter/material.dart';
import '../../application/guided_timed_workout_controller.dart';
import '../../domain/guided_timed_progress.dart';

/// Presentation only: this player never opens camera/model dependencies.
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

  String _time(int microseconds) {
    final seconds = (microseconds / 1000000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller, p = c.progress;
        final phase = p.phase;
        final isRest = phase == GuidedTimedPhase.resting;
        final complete = phase == GuidedTimedPhase.completed;
        Widget button(String label, Future<void> Function() action) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: _busy ? null : () => _run(action),
                    child: Text(label))));
        return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _run(widget.onBack);
            },
            child: Scaffold(
                appBar: AppBar(
                    title: Text(widget.exerciseName),
                    leading: IconButton(
                        tooltip: 'Back to routine',
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _busy ? null : () => _run(widget.onBack))),
                body: SafeArea(
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                  Text(complete ? 'Timer completed' : 'Video guided',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Not AI verified'),
                  const SizedBox(height: 16),
                  if (c.player.ready)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                            height: 200,
                            child: Center(
                                child: AspectRatio(
                                    aspectRatio:
                                        c.player.aspectRatio.isFinite &&
                                                c.player.aspectRatio > 0
                                            ? c.player.aspectRatio
                                            : 16 / 9,
                                    child: c.player.buildVideo())))),
                  const SizedBox(height: 20),
                  Text(
                      '${p.completedSets}/${p.prescription.sets} sets · ${_time(p.totalActiveMicroseconds)} active',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (!complete)
                    Semantics(
                        liveRegion: false,
                        label: isRest ? 'Rest remaining' : 'Set time remaining',
                        child: Text(
                            _time(isRest
                                ? p.remainingRestMicroseconds
                                : p.targetMicroseconds -
                                    p.currentSetActiveMicroseconds),
                            style: Theme.of(context).textTheme.displayMedium)),
                  if (isRest)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(p.restKind == GuidedTimedRestKind.midSet
                            ? 'Rest · set ${p.completedSets + 1} is unfinished'
                            : 'Rest before set ${p.completedSets + 1}')),
                  if (c.interruptionReason != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(c.interruptionReason == 'buffering'
                            ? 'Video buffering. Resume when ready.'
                            : c.interruptionReason == 'save failed'
                                ? 'Save failed. Retry to retain this progress.'
                                : 'Workout paused. Check the video and resume.')),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  const SizedBox(height: 16),
                  if (phase == GuidedTimedPhase.loading)
                    const Center(child: CircularProgressIndicator()),
                  if (phase == GuidedTimedPhase.ready)
                    button('Start workout', c.start),
                  if (phase == GuidedTimedPhase.working) ...[
                    button('Pause', c.pause),
                    button('Rest', c.rest)
                  ],
                  if (isRest) ...[
                    if (p.restKind == GuidedTimedRestKind.midSet)
                      button('Resume set ${p.completedSets + 1}',
                          c.resumeCurrentSet)
                    else
                      button(
                          p.remainingRestMicroseconds > 0
                              ? 'Skip rest & start next set'
                              : 'Start next set',
                          () => c.startNextSet(
                              skipRest: p.remainingRestMicroseconds > 0)),
                    button('Pause', c.pause)
                  ],
                  if (phase == GuidedTimedPhase.paused ||
                      phase == GuidedTimedPhase.interrupted) ...[
                    if (!c.player.ready || c.player.error != null)
                      button('Retry video', c.initialize)
                    else
                      button(p.completed ? 'Retry save' : 'Resume', c.resume)
                  ],
                  if (phase == GuidedTimedPhase.saving)
                    const Center(child: CircularProgressIndicator()),
                  if (complete)
                    button(
                        'Return to routine', () async => widget.onCompleted()),
                  if (!complete)
                    TextButton(
                        onPressed: _busy ? null : () => _run(widget.onSkip),
                        child: const Text('Skip exercise')),
                ]))));
      });
}
