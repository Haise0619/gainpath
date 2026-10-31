import 'package:flutter/material.dart';

/// Explicit front-view setup before camera access; targets come from the Routine.
class ShoulderPressSetupScreen extends StatefulWidget {
  const ShoulderPressSetupScreen(
      {super.key,
      required this.exerciseName,
      required this.sets,
      required this.reps,
      required this.restSeconds,
      required this.onStart});
  final String exerciseName;
  final int sets, reps, restSeconds;
  final VoidCallback onStart;
  @override
  State<ShoulderPressSetupScreen> createState() =>
      _ShoulderPressSetupScreenState();
}

class _ShoulderPressSetupScreenState extends State<ShoulderPressSetupScreen> {
  bool _starting = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Shoulder press setup')),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.exerciseName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Text(
                          '${widget.sets} sets · ${widget.reps} reps per set · both arms together'),
                      Text('${widget.restSeconds}s rest between sets'),
                      const SizedBox(height: 24),
                      const Text(
                          'Face the camera with an upright, steady torso. Show both shoulders, elbows, wrists and hips. Leave enough space above your hands throughout the press.'),
                      const SizedBox(height: 12),
                      const Text(
                          'Hold both hands above bent elbows at shoulder height to calibrate. Press both arms overhead together, then lower with control to the starting position. Both arms moving together count as one rep.'),
                      const SizedBox(height: 12),
                      const Text(
                          'Counts are provisional. The camera does not assess dumbbell weight, spinal alignment or three-dimensional shoulder mechanics. No form score is produced.'),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                          key: const ValueKey('shoulder-press-start-camera'),
                          onPressed: _starting
                              ? null
                              : () {
                                  setState(() => _starting = true);
                                  widget.onStart();
                                },
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Start camera')),
                    ]))),
      );
}
