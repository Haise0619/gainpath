import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart' show LungeSide;

/// The selected side is the planted front leg, not the foot stepping back.
class ReverseLungeSetupScreen extends StatefulWidget {
  const ReverseLungeSetupScreen(
      {super.key,
      required this.exerciseName,
      required this.sets,
      required this.reps,
      required this.restSeconds,
      required this.onStart});
  final String exerciseName;
  final int sets, reps, restSeconds;
  final void Function(LungeSide) onStart;
  @override
  State<ReverseLungeSetupScreen> createState() =>
      _ReverseLungeSetupScreenState();
}

class _ReverseLungeSetupScreenState extends State<ReverseLungeSetupScreen> {
  LungeSide? _side;
  bool _starting = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reverse lunge setup')),
        body: SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.exerciseName,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
                '${widget.sets} sets · ${widget.reps} reps per selected front leg per set'),
            Text('${widget.restSeconds}s rest between sets'),
            const SizedBox(height: 24),
            const Text('Which front leg will stay planted?'),
            Wrap(spacing: 12, runSpacing: 8, children: [
              for (final side in LungeSide.values)
                ChoiceChip(
                    label: Text(side == LungeSide.left
                        ? 'Left front leg'
                        : 'Right front leg'),
                    selected: _side == side,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected:
                        _starting ? null : (_) => setState(() => _side = side)),
            ]),
            const SizedBox(height: 16),
            const Text(
                'Left and right mean your own legs. The selected front leg stays planted; the other foot steps backward. Use only this front leg for every set in this session. Train the other leg in a separate session.'),
            const SizedBox(height: 12),
            const Text(
                'Place the camera on the side of the selected front leg, upright and stationary. Keep that leg nearest the camera with its knee and heel-to-toe outline visible. Show your torso, both hips and both ankles throughout the movement. The far knee bend is not measured. Keep both ankles separate in view by turning slightly toward the camera. The live camera check starts automatically after a verified hold and 3-second countdown; no touch is needed. Leave enough clear space behind you.'),
            const SizedBox(height: 12),
            const Text(
                'Stand tall with a small comfortable gap between your feet to keep both ankles visible. Step the other foot backward, lower with control, then return both feet to the same standing start between reps. Do not alternate legs within a set.'),
            const SizedBox(height: 12),
            const Text(
                'Counts use projected movement and remain provisional. Balance, load, floor contact and three-dimensional alignment are not assessed. No form score is produced. Results stay on this device; verified upload and workout rewards are unavailable.'),
            const SizedBox(height: 24),
            FilledButton.icon(
                key: const ValueKey('reverse-lunge-start-camera'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
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
