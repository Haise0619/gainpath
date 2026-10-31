import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart' show RowSide;

/// A selected anatomical arm is required before the route opens the camera.
class RowSetupScreen extends StatefulWidget {
  const RowSetupScreen(
      {super.key,
      required this.exerciseName,
      required this.sets,
      required this.reps,
      required this.restSeconds,
      required this.onStart});
  final String exerciseName;
  final int sets, reps, restSeconds;
  final void Function(RowSide) onStart;
  @override
  State<RowSetupScreen> createState() => _RowSetupScreenState();
}

class _RowSetupScreenState extends State<RowSetupScreen> {
  RowSide? _side;
  bool _starting = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Row setup')),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.exerciseName,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
                '${widget.sets} sets · ${widget.reps} reps per selected arm per set'),
            Text('${widget.restSeconds}s rest between sets'),
            const SizedBox(height: 24),
            const Text('Which arm will you train in this session?'),
            Wrap(spacing: 12, children: [
              for (final side in RowSide.values)
                ChoiceChip(
                    label:
                        Text(side == RowSide.left ? 'Left arm' : 'Right arm'),
                    selected: _side == side,
                    onSelected:
                        _starting ? null : (_) => setState(() => _side = side)),
            ]),
            const SizedBox(height: 16),
            const Text(
                'Left and right mean your own arms. Place the camera side-on with the selected arm closest to it. Keep that shoulder, elbow, wrist and hip visible.'),
            const SizedBox(height: 12),
            const Text(
                'Support your other hand and knee on a stable bench. Hold your torso nearly horizontal and let the selected arm hang straight down to calibrate. Pull the elbow toward your hip, then lower with control.'),
            const SizedBox(height: 12),
            const Text(
                'This session measures the selected arm only. Train the other arm in a separate session. The camera cannot verify the weight, bench contact, spinal shape or three-dimensional rotation. No form score is produced.'),
            const SizedBox(height: 24),
            FilledButton.icon(
                key: const ValueKey('row-start-camera'),
                onPressed: _side == null || _starting
                    ? null
                    : () {
                        setState(() => _starting = true);
                        widget.onStart(_side!);
                      },
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Start camera')),
          ]),
        )),
      );
}
