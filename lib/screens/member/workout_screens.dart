import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

const _routineHeroImage =
    'https://images.unsplash.com/photo-1584863231364-2edc166de576?auto=format&fit=crop&w=1200&q=80';
const _cameraHeroImage =
    'https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?auto=format&fit=crop&w=1200&q=80';

/// Full-bleed network image with a graceful gradient fallback so a dead
/// link never breaks the layout — the same defensive pattern used across
/// the onboarding and profile-setup flows.
Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.ink),
    errorBuilder: (context, error, stack) =>
        const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M2.2 — Pre-Workout Preparation. A Staging Menu hub: three optional
/// detours (Watch Tutorial, View Routine, Review Camera Setup) that each
/// loop back here, plus the one action that actually leaves the screen
/// forward — Proceed to Workout.
class WorkoutPrepScreen extends StatelessWidget {
  const WorkoutPrepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const routine = MockData.routine;
    final totalSets = routine.fold<int>(0, (sum, e) => sum + e.sets);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            titleTextStyle:
                Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 18),
            title: const Text('Workout'),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _networkHero(_routineHeroImage),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.ink.withValues(alpha: 0.15),
                          AppColors.ink.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('TODAY\'S ROUTINE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1)),
                          ),
                          const SizedBox(height: 10),
                          Text('Lower Body Strength',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(color: Colors.white, fontSize: 24)),
                          const SizedBox(height: 6),
                          Text(
                            '${routine.length} exercises  ·  $totalSets sets  ·  about 45 min',
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList.list(
              children: [
                _DetourCard(
                  icon: Icons.play_circle_fill_rounded,
                  iconColor: AppColors.primary,
                  title: 'Watch tutorial',
                  subtitle: 'See proper form for ${routine.first.name}',
                  image: routine.first.imageUrl,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ExerciseTutorialScreen(exercise: routine.first))),
                ),
                const SizedBox(height: 12),
                _DetourCard(
                  icon: Icons.list_alt_rounded,
                  iconColor: AppColors.info,
                  title: 'View routine',
                  subtitle: 'Full exercise list, sets, and rest intervals',
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineScreen())),
                ),
                const SizedBox(height: 12),
                _DetourCard(
                  icon: Icons.videocam_rounded,
                  iconColor: AppColors.accentDark,
                  title: 'Review camera setup',
                  subtitle: 'Get the right distance and angle before you start',
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const CameraSetupScreen())),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
                    onPressed: () => _startSession(context),
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('Start guided session'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSession(BuildContext context) async {
    // UC-2.5 — biometric consent gate on first camera use.
    final consented = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ConsentSheet(),
    );
    if (consented == true && context.mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LiveWorkoutScreen()));
    }
  }
}

/// A rich, image-or-icon tappable card for the staging menu's three
/// detours — deliberately heavier than a plain ListTile so the hub reads
/// as a set of deliberate choices rather than a settings list.
class _DetourCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? image;
  final VoidCallback onTap;

  const _DetourCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Row(
        children: [
          if (image != null)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _networkHero(image!),
                    DecoratedBox(decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.28))),
                    Center(child: Icon(icon, color: Colors.white, size: 26)),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 23),
              ),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet();

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(999)),
            ),
          ),
          Text('Before we turn on the camera',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'GainPath reads your body position from the camera to check your form '
            'and count your reps.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 14),
          Panel(
            background: AppColors.primaryTint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _point(context, 'Everything is processed on this device.'),
                _point(context, 'No video is recorded, stored, or uploaded.'),
                _point(context, 'Only your movement scores are saved.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _checked = !_checked),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: _checked,
                    onChanged: (v) => setState(() => _checked = v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      'I agree to camera-based movement tracking as described above.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _checked ? () => Navigator.pop(context, true) : null,
            child: const Text('Accept and start'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }

  Widget _point(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 17, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 14, height: 1.4))),
          ],
        ),
      );
}

/// AD-M2.2 detour — View Routine. The full exercise list with thumbnails,
/// set/rep targets, and rest intervals; tapping an exercise hands off into
/// its tutorial. Reviewing and returning is the whole point of this screen
/// living outside the main staging menu.
class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const routine = MockData.routine;
    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s routine')),
      body: PageBody(
        children: [
          Text('${routine.length} exercises in order. Tap one to review its form cues.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          ...routine.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: EdgeInsets.zero,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ExerciseTutorialScreen(exercise: e))),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _networkHero(e.imageUrl),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text('${e.sets} sets  ·  ${e.reps} reps  ·  90s rest',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 14),
                      child: Icon(Icons.play_circle_outline_rounded, color: AppColors.primary, size: 22),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// UC-2.2 — Watch Exercise Tutorial. A simulated video player: tapping
/// play swaps the thumbnail for the same animated pose-demo used on the
/// live tracking screen, with a real scrubber and replay so it reads and
/// behaves like a video even though nothing is actually streamed.
class ExerciseTutorialScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseTutorialScreen({super.key, required this.exercise});

  @override
  State<ExerciseTutorialScreen> createState() => _ExerciseTutorialScreenState();
}

class _ExerciseTutorialScreenState extends State<ExerciseTutorialScreen>
    with TickerProviderStateMixin {
  static const _demoDuration = Duration(seconds: 8);

  late final AnimationController _loop;
  late final AnimationController _progress;
  bool _playing = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _progress = AnimationController(vsync: this, duration: _demoDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _playing = false;
            _finished = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _loop.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_finished) {
        _finished = false;
        _progress.value = 0;
      }
      _playing = !_playing;
      if (_playing) {
        _progress.forward();
      } else {
        _progress.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    return Scaffold(
      appBar: AppBar(title: Text(e.name)),
      body: PageBody(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!_playing) _networkHero(e.imageUrl) else Container(color: AppColors.ink),
                  if (_playing)
                    AnimatedBuilder(
                      animation: _loop,
                      builder: (_, __) => CustomPaint(painter: _SkeletonPainter(_loop.value)),
                    )
                  else
                    DecoratedBox(decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: 0.32))),
                  Center(
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.92),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14)],
                        ),
                        child: Icon(
                          _finished
                              ? Icons.replay_rounded
                              : _playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                          color: AppColors.primary,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, child) {
                        final elapsed = _progress.value * _demoDuration.inSeconds;
                        return Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: _progress.value,
                                  minHeight: 4,
                                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                                  valueColor: const AlwaysStoppedAnimation(AppColors.overlay),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '0:${elapsed.round().toString().padLeft(2, '0')} / 0:${_demoDuration.inSeconds}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(e.name, style: Theme.of(context).textTheme.titleLarge),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              statusPill(e.category),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accentTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(e.muscleGroup,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.warning)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Eyebrow('Key cue'),
          Panel(
            background: AppColors.primaryTint,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.record_voice_over_rounded,
                    size: 19, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.cue,
                      style: const TextStyle(fontSize: 15, height: 1.45)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Form breakdown'),
          Panel(
            child: Column(
              children: [
                _formStep(context, '1', 'Setup',
                    'Set your feet shoulder-width apart, brace your core, and find a neutral spine.'),
                const Divider(height: 22),
                _formStep(context, '2', 'Movement', e.cue),
                const Divider(height: 22),
                _formStep(context, '3', 'Finish',
                    'Return under control and reset your position before the next rep.'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Target'),
          Panel(
            child: Column(
              children: [
                DetailRow('Sets', '${e.sets}'),
                const Divider(height: 18),
                DetailRow('Reps per set', '${e.reps}'),
                const Divider(height: 18),
                const DetailRow('Rest', '90 seconds'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formStep(BuildContext context, String number, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
          child: Text(number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

/// UC-2.4 — Review Camera Setup Guidance. Steps as a swipeable carousel
/// (with a visible dot indicator and prev/next controls, not swipe-only)
/// rather than a static vertical list.
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
                      _networkHero(_cameraHeroImage),
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
class LiveWorkoutScreen extends StatefulWidget {
  const LiveWorkoutScreen({super.key});

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  int _reps = 0;
  int _seconds = 0;
  int _accuracy = 82;
  bool _paused = false;
  bool _voiceOn = true;
  String _cue = 'Get into position.';
  final _rng = math.Random();

  // Which exercise and set of the assigned routine is currently active,
  // derived from accumulated reps rather than tracked separately, so it
  // can never drift out of sync with the rep counter.
  int _exerciseIndex = 0;
  int _setNumber = 1;
  int _repsInSet = 0;

  // SD-M2.3 — confidence-driven recalibration. Below 70% the interface
  // hands off to an alignment overlay; if it stays below 50% for 5+ ticks
  // while recalibrating, the session escalates automatically into pause
  // without the member tapping anything themselves.
  double _confidence = 88;
  bool _recalibrating = false;
  int _lowStreak = 0;
  String? _pauseReason;

  Exercise get _currentExercise => MockData.routine[_exerciseIndex];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused || !mounted) return;
      setState(() {
        _seconds++;
        _confidence = (_confidence + (_rng.nextDouble() * 14 - 7)).clamp(28, 98);
        _evaluateConfidence();
        if (_recalibrating) return;

        _accuracy = _confidence.round();
        if (_seconds % 3 == 0) {
          _reps++;
          _advanceRoutineProgress();
          if (_voiceOn) {
            _cue = MockData.voiceCues[_rng.nextInt(MockData.voiceCues.length)];
          }
        }
      });
    });
  }

  /// Steps the exercise/set pointer forward as reps accumulate, so the
  /// on-screen "Exercise 2 of 4 · Set 3/4" label always matches what the
  /// member has actually counted through.
  void _advanceRoutineProgress() {
    _repsInSet++;
    if (_repsInSet < _currentExercise.reps) return;
    _repsInSet = 0;
    if (_setNumber < _currentExercise.sets) {
      _setNumber++;
    } else if (_exerciseIndex < MockData.routine.length - 1) {
      _exerciseIndex++;
      _setNumber = 1;
    }
  }

  /// Runs the confidence state machine. Must be called from inside
  /// setState. Returns nothing — it mutates _recalibrating/_lowStreak and,
  /// on sustained tracking loss, flips into the pause state directly.
  void _evaluateConfidence() {
    if (_confidence < 50) {
      _lowStreak++;
    } else {
      _lowStreak = 0;
    }

    if (!_recalibrating && _confidence < 70) {
      _recalibrating = true;
      return;
    }
    if (!_recalibrating) return;

    if (_confidence >= 70) {
      _recalibrating = false;
      _lowStreak = 0;
    } else if (_lowStreak >= 5) {
      _recalibrating = false;
      _paused = true;
      _pauseReason = 'Tracking lost for a few seconds, so we paused for you.';
    }
  }

  /// Demo affordance: a real build reacts to the on-device pose pipeline;
  /// this lets the flow be exercised deliberately. Tap once to trigger
  /// recalibration, tap again while it is up to force the escalation path.
  void _simulateTrackingIssue() {
    setState(() {
      if (_recalibrating) {
        _confidence = 32;
        _lowStreak = 5;
        _evaluateConfidence();
      } else {
        _confidence = 58;
        _evaluateConfidence();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _clock {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _end() async {
    setState(() => _paused = true);
    final ok = await confirmSheet(
      context,
      title: 'End this session?',
      message:
          'Your $_reps reps and form scores so far will be saved to your history.',
      confirmLabel: 'End and save',
    );
    if (ok && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutResultScreen(
              reps: _reps, accuracy: _accuracy, seconds: _seconds),
        ),
      );
    } else {
      setState(() {
        _paused = false;
        _pauseReason = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            // Camera viewport with skeleton overlay
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: const Color(0xFF20302B)),
                  ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) => CustomPaint(
                        painter: _SkeletonPainter(_controller.value),
                      ),
                    ),
                  ),
                  // Top bar
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _pill(Icons.timer_outlined, _clock),
                            const SizedBox(width: 8),
                            _pill(Icons.check_circle_outline_rounded, '$_accuracy%'),
                            const Spacer(),
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: Colors.black38),
                              tooltip: 'Simulate tracking loss (demo)',
                              icon: const Icon(Icons.sensors_off_rounded, color: Colors.white, size: 20),
                              onPressed: _paused ? null : _simulateTrackingIssue,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.black38),
                              icon: Icon(
                                  _voiceOn
                                      ? Icons.volume_up_rounded
                                      : Icons.volume_off_rounded,
                                  color: Colors.white,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _voiceOn = !_voiceOn),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fitness_center_rounded, size: 14, color: AppColors.overlay),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Exercise ${_exerciseIndex + 1} of ${MockData.routine.length} · '
                                  '${_currentExercise.name} · Set $_setNumber/${_currentExercise.sets}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Rep counter
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 92,
                    child: Column(
                      children: [
                        Text('$_reps',
                            style: const TextStyle(
                                fontSize: 76,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -3)),
                        const Text('REPS',
                            style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w700,
                                color: Colors.white54)),
                      ],
                    ),
                  ),
                  // Voice cue
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Container(
                        key: ValueKey(_cue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.graphic_eq_rounded,
                                size: 18, color: AppColors.overlay),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(_cue,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_recalibrating)
                    Positioned.fill(child: _RecalibrationOverlay(confidence: _confidence)),
                  if (_paused)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_pauseReason != null) ...[
                                const Icon(Icons.sensors_off_rounded, color: AppColors.warning, size: 30),
                                const SizedBox(height: 10),
                              ],
                              Text(_pauseReason != null ? 'Session paused' : 'Paused',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700)),
                              if (_pauseReason != null) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: Text(_pauseReason!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Controls
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              color: AppColors.ink,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () => setState(() => _paused = !_paused),
                      icon: Icon(
                          _paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 20),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(_paused ? 'Resume' : 'Pause', maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger),
                      onPressed: _end,
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('End session', maxLines: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// SD-M2.3 — Recalibrate Camera Position. Replaces the live tracking
/// display while confidence is below 70%: repetition counting suspends and
/// a pulsing alignment guide prompts the member to adjust, re-evaluating
/// every tick until it clears (auto-resume) or degrades further (auto-pause
/// escalation, handled by the parent screen).
class _RecalibrationOverlay extends StatefulWidget {
  final double confidence;
  const _RecalibrationOverlay({required this.confidence});

  @override
  State<_RecalibrationOverlay> createState() => _RecalibrationOverlayState();
}

class _RecalibrationOverlayState extends State<_RecalibrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final critical = widget.confidence < 50;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final scale = 1.0 + (_pulse.value * 0.05);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 96,
                height: 176,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: critical ? AppColors.danger : AppColors.overlay,
                    width: 2.4,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.accessibility_new_rounded,
                    color: critical ? AppColors.danger : AppColors.overlay, size: 56),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              critical ? 'Tracking lost' : 'Realigning…',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              critical
                  ? 'Step back into frame and hold still.'
                  : 'Step back so your whole body is in view.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${widget.confidence.round()}% confidence',
                  style: TextStyle(
                    color: critical ? AppColors.danger : AppColors.overlay,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a simplified animated stick figure to stand in for the real
/// BlazePose landmark overlay. Reused as both the live tracking overlay
/// and the "playing" state of the simulated tutorial video, since both
/// are meant to depict the same generic squat-pattern motion.
class _SkeletonPainter extends CustomPainter {
  final double t;
  _SkeletonPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final baseY = size.height * 0.30;
    final squat = math.sin(t * math.pi) * size.height * 0.10;

    final line = Paint()
      ..color = AppColors.overlay
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final joint = Paint()..color = AppColors.overlay;

    final head = Offset(cx, baseY + squat);
    final neck = Offset(cx, baseY + 42 + squat);
    final hip = Offset(cx, baseY + 145 + squat);
    final kneeL = Offset(cx - 30, baseY + 215 + squat * 0.4);
    final kneeR = Offset(cx + 30, baseY + 215 + squat * 0.4);
    final ankleL = Offset(cx - 34, baseY + 290);
    final ankleR = Offset(cx + 34, baseY + 290);
    final shoulderL = Offset(cx - 38, baseY + 52 + squat);
    final shoulderR = Offset(cx + 38, baseY + 52 + squat);
    final elbowL = Offset(cx - 58, baseY + 108 + squat);
    final elbowR = Offset(cx + 58, baseY + 108 + squat);
    final handL = Offset(cx - 50, baseY + 158 + squat);
    final handR = Offset(cx + 50, baseY + 158 + squat);

    canvas.drawCircle(head, 20, Paint()
      ..color = AppColors.overlay
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke);

    for (final seg in [
      [neck, hip],
      [shoulderL, shoulderR],
      [shoulderL, elbowL],
      [elbowL, handL],
      [shoulderR, elbowR],
      [elbowR, handR],
      [hip, kneeL],
      [kneeL, ankleL],
      [hip, kneeR],
      [kneeR, ankleR],
    ]) {
      canvas.drawLine(seg[0], seg[1], line);
    }

    for (final p in [
      neck, hip, kneeL, kneeR, ankleL, ankleR,
      shoulderL, shoulderR, elbowL, elbowR, handL, handR,
    ]) {
      canvas.drawCircle(p, 5, joint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter old) => old.t != t;
}

/// AD-M2.5 — View Workout Result Summary.
class WorkoutResultScreen extends StatefulWidget {
  final int reps;
  final int accuracy;
  final int seconds;

  const WorkoutResultScreen({
    super.key,
    required this.reps,
    required this.accuracy,
    required this.seconds,
  });

  @override
  State<WorkoutResultScreen> createState() => _WorkoutResultScreenState();
}

class _WorkoutResultScreenState extends State<WorkoutResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _scale;
  static const _pointsEarned = 120;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.06), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOut));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (widget.seconds / 60).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session summary'),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 34, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text('Session complete',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Nice work. Your form held up well today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatTile('${widget.reps}', 'Reps')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile('${widget.accuracy}%', 'Avg form',
                      valueColor: widget.accuracy >= 80
                          ? AppColors.success
                          : AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(child: StatTile('$minutes', 'Minutes')),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('By exercise'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(MockData.routine.length, (i) {
                final e = MockData.routine[i];
                final pct = (widget.accuracy + (e.name.hashCode % 11 - 5)).clamp(58, 99);
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, indent: 68),
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 40, height: 40, child: _networkHero(e.imageUrl)),
                      ),
                      title: Text(e.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                      subtitle: Text('${e.sets} sets  ·  ${e.reps} reps',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                      trailing: Text('$pct%',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: pct >= 80 ? AppColors.success : AppColors.warning)),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('What to work on'),
          Panel(
            child: Column(
              children: [
                _feedback(context, Icons.trending_up_rounded, AppColors.success,
                    'Depth improved', 'You hit full depth on 8 of 10 reps.'),
                const Divider(height: 22),
                _feedback(context, Icons.warning_amber_rounded,
                    AppColors.warning, 'Watch your knees',
                    'Slight inward collapse on the last 3 reps. Push the knees out.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Panel(
            background: AppColors.accentTint,
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: _pointsEarned),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) =>
                        Text('+$value points earned this session', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => showToast(context, 'Opening your device share sheet.'),
            icon: const Icon(Icons.ios_share_rounded, size: 19),
            label: const Text('Share result'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  Widget _feedback(BuildContext context, IconData icon, Color color,
      String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
