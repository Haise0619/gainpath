import 'package:flutter/material.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/features/workout/presentation/member/widgets/workout_media.dart';

class CameraSetupScreen extends StatefulWidget {
  const CameraSetupScreen({super.key});

  @override
  State<CameraSetupScreen> createState() => _CameraSetupScreenState();
}

class _CameraSetupScreenState extends State<CameraSetupScreen> {
  static const _steps = [
    ['Stand back 2 to 3 metres', 'Your whole body needs to fit in the frame.', Icons.social_distance_rounded],
    ['Prop the phone upright', 'Lean it against something stable at hip height.', Icons.stay_current_portrait_rounded],
    ['Face the camera side-on', 'A side view reads squat and hinge depth best.', Icons.switch_camera_rounded],
    ['Avoid backlighting', 'Do not stand directly in front of a bright window.', Icons.wb_sunny_rounded],
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_page + delta).clamp(0, _steps.length - 1);
    _controller.animateToPage(next, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera setup')),
      body: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      networkHero(cameraHeroImage),
                      DecoratedBox(decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.55))),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 70,
                              height: 130,
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.overlay, width: 2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.accessibility_new_rounded,
                                  color: AppColors.overlay, size: 46),
                            ),
                            const SizedBox(height: 12),
                            const Text('Fit inside the outline',
                                style: TextStyle(
                                    color: AppColors.overlay,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _steps.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final s = _steps[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(s[2] as IconData, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 16),
                      Text('Step ${i + 1} of ${_steps.length}',
                          style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 6),
                      Text(s[0] as String, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
                      const SizedBox(height: 8),
                      Text(s[1] as String, style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 22 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.hairline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                if (_page > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _go(-1),
                      child: const Text('Back'),
                    ),
                  ),
                if (_page > 0) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      if (_page < _steps.length - 1) {
                        _go(1);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(_page < _steps.length - 1 ? 'Next' : 'Got it'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AD-M2.1 — Start AI-Guided Workout Session.
/// Simulated live tracking: animated skeleton overlay, rep counter,
/// rolling accuracy, exercise/set progress, and a voice-cue feed.
