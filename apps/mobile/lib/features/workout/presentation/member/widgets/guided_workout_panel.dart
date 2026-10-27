import 'package:flutter/material.dart';
import '../../../application/guided_workout_progress.dart';
import '../../../application/real_squat_session_controller.dart';

class GuidedWorkoutPanel extends StatelessWidget {
  const GuidedWorkoutPanel({super.key, required this.session});
  final RealSquatSessionController session;

  @override
  Widget build(BuildContext context) {
    final flow = session.guidance!;
    final working = flow.stage == GuidedWorkoutStage.working;
    final resting = flow.stage == GuidedWorkoutStage.resting;
    final enabled = session.phase == RealSquatSessionPhase.active &&
        !session.isManuallyPaused &&
        !session.isRecalibrating;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
          working
              ? 'Set ${flow.currentSet} of ${flow.sets} · ${flow.setRepetitions}/${flow.repetitions} full reps'
              : resting
                  ? 'Set ${flow.completedSets} complete · rest ${flow.remainingRestSeconds}s'
                  : 'All ${flow.sets} sets complete',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      LinearProgressIndicator(
          value: flow.stage == GuidedWorkoutStage.complete
              ? 1
              : (flow.completedSets +
                      (working ? flow.setRepetitions / flow.repetitions : 0)) /
                  flow.sets),
      if (working)
        Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Text('Rest between sets'),
              DropdownButton<int>(
                  value: flow.restSeconds,
                  items: [
                    for (final seconds in [0, 30, 60, 90, 120, 180, 300])
                      DropdownMenuItem(
                          value: seconds,
                          child: Text(
                              seconds == 0 ? 'No timed rest' : '${seconds}s'))
                  ],
                  onChanged: enabled
                      ? (seconds) => session.setRestSeconds(seconds!)
                      : null),
            ]),
      if (resting) ...[
        const SizedBox(height: 8),
        const Text('Counting is paused. Start the next set when you are ready.',
            textAlign: TextAlign.center),
        TextButton(
            onPressed: enabled
                ? () => session.startNextSet(
                    skipRest: flow.remainingRestSeconds > 0)
                : null,
            child: Text(flow.remainingRestSeconds > 0
                ? 'Skip rest & start set ${flow.completedSets + 1}'
                : 'Start set ${flow.completedSets + 1}')),
      ],
      if (flow.stage == GuidedWorkoutStage.complete)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
                'Counting has stopped. Save your measured result below.',
                textAlign: TextAlign.center)),
      const SizedBox(height: 8),
    ]);
  }
}
