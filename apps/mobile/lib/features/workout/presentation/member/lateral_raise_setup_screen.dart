import 'package:flutter/material.dart';

/// Explicit front-view setup before camera access; targets come from the Routine.
class LateralRaiseSetupScreen extends StatefulWidget {
  const LateralRaiseSetupScreen(
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
  State<LateralRaiseSetupScreen> createState() =>
      _LateralRaiseSetupScreenState();
}

class _LateralRaiseSetupScreenState extends State<LateralRaiseSetupScreen> {
  bool _starting = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Lateral raise setup')),
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
                          'Face the camera with an upright, steady torso. Show both shoulders, elbows, wrists and hips. Leave enough space on both sides for your arms throughout the raise.'),
                      const SizedBox(height: 12),
                      const Text(
                          'Hold your arms by your sides to calibrate automatically. Raise both arms out to shoulder height with a slight elbow bend, then lower fully to your sides. One complete bilateral cycle counts as one rep. No touch confirmation is needed after you stand ready.'),
                      const SizedBox(height: 12),
                      const Text(
                          'Counts are provisional. The camera does not assess dumbbell weight, spinal alignment or three-dimensional shoulder mechanics. No form score is produced.'),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                          key: const ValueKey('lateral-raise-start-camera'),
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
