import 'package:flutter/material.dart';

/// Floor contact is user-confirmed, never inferred from the pose projection.
class CalfRaiseSetupScreen extends StatefulWidget {
  const CalfRaiseSetupScreen(
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
  State<CalfRaiseSetupScreen> createState() => _CalfRaiseSetupScreenState();
}

class _CalfRaiseSetupScreenState extends State<CalfRaiseSetupScreen> {
  bool _heelsDown = false, _starting = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Calf raise setup')),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.exerciseName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Text('${widget.sets} sets · ${widget.reps} reps per set'),
                      Text('${widget.restSeconds}s rest between sets'),
                      const SizedBox(height: 24),
                      const Text(
                          'Place the phone securely at your side. Frame your hips to the floor, with the camera-facing knee, ankle, heel and toes fully visible. Keep the entire foot outline in view and leave space for your heels to rise. Use even lighting.'),
                      const SizedBox(height: 12),
                      const Text(
                          'Start on level ground with both heels down and knees straight. Hold still until Ready. Raise both heels with control, hold briefly at the top, then lower fully and hold briefly. Keep toes and the phone stationary; do not jump.'),
                      const SizedBox(height: 12),
                      const Text(
                          'After a brief tracking interruption, lower your heels and hold to restart. The interrupted movement is discarded. Longer interruptions require a new setup hold.'),
                      const SizedBox(height: 12),
                      const Text(
                          'Only the visible leg is measured. Counts and form guidance are provisional; equal work by both legs, balance and load are not assessed. Results stay on this device; verified workout acceptance and rewards remain unavailable.'),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _heelsDown,
                          onChanged: _starting
                              ? null
                              : (value) =>
                                  setState(() => _heelsDown = value ?? false),
                          title: const Text(
                              'I am side-on on level ground, with both heels down and the whole visible foot in view.')),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                          key: const ValueKey('calf-start-camera'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(44, 48)),
                          onPressed: !_heelsDown || _starting
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
