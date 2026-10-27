import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart' show CurlSide;
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/curl_arm_metrics.dart';

/// Capture is created by the route only after these choices are confirmed.
class CurlArmSetupScreen extends StatefulWidget {
  const CurlArmSetupScreen(
      {super.key,
      required this.exerciseName,
      required this.sets,
      required this.reps,
      required this.onStart});
  final String exerciseName;
  final int sets, reps;
  final void Function(CurlArmMode, CurlSide) onStart;
  @override
  State<CurlArmSetupScreen> createState() => _CurlArmSetupScreenState();
}

class _CurlArmSetupScreenState extends State<CurlArmSetupScreen> {
  CurlArmMode _mode = CurlArmMode.both;
  CurlSide _first = CurlSide.left;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Curl setup')),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.fitness_center_rounded,
                          size: 42, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(widget.exerciseName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text('${widget.sets} sets',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('${widget.reps} reps per arm per set'),
                      const SizedBox(height: 24),
                      const Text('Which arms are you training?'),
                      Wrap(spacing: 8, children: [
                        for (final mode in CurlArmMode.values)
                          ChoiceChip(
                              label: Text(mode.label),
                              selected: _mode == mode,
                              onSelected: (_) => setState(() => _mode = mode))
                      ]),
                      if (_mode == CurlArmMode.both) ...[
                        const SizedBox(height: 20),
                        const Text('Start with'),
                        Wrap(spacing: 8, children: [
                          for (final side in CurlSide.values)
                            ChoiceChip(
                                label: Text(side == CurlSide.left
                                    ? 'Left arm'
                                    : 'Right arm'),
                                selected: _first == side,
                                onSelected: (_) =>
                                    setState(() => _first = side))
                        ]),
                      ],
                      const SizedBox(height: 20),
                      Text(_mode == CurlArmMode.both
                          ? 'Finish ${widget.reps} reps on the first arm, then switch when prompted. Both arms complete one set.'
                          : 'Each set counts ${widget.reps} reps on the selected arm only.'),
                      const SizedBox(height: 12),
                      const Text(
                          'Left and right mean your own arms. Stand side-on with the selected arm closest to the camera. Lower it and hold still to calibrate.',
                          style: TextStyle(color: AppColors.inkSoft)),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                          onPressed: () => widget.onStart(
                              _mode,
                              _mode == CurlArmMode.leftOnly
                                  ? CurlSide.left
                                  : _mode == CurlArmMode.rightOnly
                                      ? CurlSide.right
                                      : _first),
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('Start camera')),
                    ]))),
      );
}
