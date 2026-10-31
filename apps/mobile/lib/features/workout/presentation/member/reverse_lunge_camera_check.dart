import 'package:flutter/material.dart';
import 'package:gainpath_pose/gainpath_pose.dart' show LungeSide;
import '../../application/reverse_lunge_workout_session.dart';

/// Explicit camera-facing working-leg confirmation before any counted movement.
class ReverseLungeCameraCheck extends StatelessWidget {
  const ReverseLungeCameraCheck(
      {super.key, required this.session, required this.viewport});
  final ReverseLungeWorkoutSession session;
  final Widget viewport;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: session,
      builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Automatic workout setup')),
            body: SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                              key: const ValueKey('lunge-camera-framing'),
                              aspectRatio: 9 / 16,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(fit: StackFit.expand, children: [
                                    viewport,
                                    Positioned(
                                        top: 8,
                                        left: 8,
                                        right: 8,
                                        child: Semantics(
                                            liveRegion: true,
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: .82),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Text(
                                                  '${session.selectedLegLabel}\n${session.errorMessage ?? (session.startCountdownSeconds != null ? 'Starting in ${session.startCountdownSeconds} · hold still' : session.calibrationCue)}',
                                                  key: const ValueKey(
                                                      'lunge-live-status'),
                                                  maxLines: 4,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16)),
                                            ))),
                                  ]))),
                          const SizedBox(height: 12),
                          if (session.errorMessage != null) ...[
                            Text(session.errorMessage!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                            if (session.canRetryCameraCheck)
                              OutlinedButton(
                                  onPressed: session.retryCameraCheck,
                                  child: const Text('Retry camera'))
                            else
                              const Text(
                                  'Leave this screen and start again if the camera cannot resume.'),
                            const SizedBox(height: 12),
                          ],
                          Text('${session.selectedLegLabel} stays planted',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text(
                              'Choose your own leg nearest the camera. It will stay planted for every set. Keep its knee, ankle, heel and toes visible, plus both hips and the other ankle. Stand with a small comfortable gap between your feet and turn slightly toward the camera so the ankles do not overlap. The far knee bend is not measured.'),
                          const SizedBox(height: 8),
                          Wrap(spacing: 12, runSpacing: 8, children: [
                            for (final s in LungeSide.values)
                              ChoiceChip(
                                  label: Text(s == LungeSide.left
                                      ? 'Left front leg'
                                      : 'Right front leg'),
                                  selected: session.side == s,
                                  onSelected: (_) =>
                                      session.selectCameraCheckSide(s))
                          ]),
                          const SizedBox(height: 12),
                          const SizedBox(height: 8),
                          const Text(
                              'Step away from the phone and stand tall. Keep both ankles visible with a small gap; do not take a split stance. Once setup is verified, a 3-second countdown starts the workout automatically. You do not need to touch the phone. Movement or lost tracking resets the countdown. Change the selection only if you intend to train the other front leg. Movement during setup does not count.'),
                          const SizedBox(height: 16),
                          const Text(
                              'Starts automatically after a verified hold and countdown.',
                              key: ValueKey('lunge-auto-start')),
                        ]))),
          ));
}
