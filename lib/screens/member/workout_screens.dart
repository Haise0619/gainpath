import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M2.2 — Pre-Workout Preparation.
/// Routine review, tutorial, and camera setup guidance all live here.
class WorkoutPrepScreen extends StatelessWidget {
  const WorkoutPrepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lower Body Strength',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Assigned routine  ·  about 45 min',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Exercises'),
          ...MockData.routine.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ExerciseTutorialScreen(exercise: e))),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.play_circle_outline_rounded,
                            size: 22, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text('${e.sets} sets  ·  ${e.reps} reps',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CameraSetupScreen())),
            icon: const Icon(Icons.videocam_outlined, size: 19),
            label: const Text('Review camera setup'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _startSession(context),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start guided session'),
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

/// UC-2.2 — Watch Exercise Tutorial.
class ExerciseTutorialScreen extends StatelessWidget {
  final Exercise exercise;
  const ExerciseTutorialScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: PageBody(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.play_circle_fill_rounded,
                    size: 60, color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(exercise.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(exercise.category,
              style: Theme.of(context).textTheme.bodyMedium),
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
                  child: Text(exercise.cue,
                      style: const TextStyle(fontSize: 15, height: 1.45)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Target'),
          Panel(
            child: Column(
              children: [
                DetailRow('Sets', '${exercise.sets}'),
                const Divider(height: 18),
                DetailRow('Reps per set', '${exercise.reps}'),
                const Divider(height: 18),
                DetailRow('Rest', '90 seconds'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// UC-2.4 — Review Camera Setup Guidance.
class CameraSetupScreen extends StatelessWidget {
  const CameraSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = [
      ['Stand back 2 to 3 metres', 'Your whole body needs to fit in the frame.'],
      ['Prop the phone upright', 'Lean it against something stable at hip height.'],
      ['Face the camera side-on', 'A side view reads squat and hinge depth best.'],
      ['Avoid backlighting', 'Do not stand directly in front of a bright window.'],
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Camera setup')),
      body: PageBody(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
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
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i][0],
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(steps[i][1],
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// AD-M2.1 — Start AI-Guided Workout Session.
/// Simulated live tracking: animated skeleton overlay, rep counter,
/// rolling accuracy, and a voice-cue feed.
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

  // SD-M2.3 — confidence-driven recalibration. Below 70% the interface
  // hands off to an alignment overlay; if it stays below 50% for 5+ ticks
  // while recalibrating, the session escalates automatically into pause
  // without the member tapping anything themselves.
  double _confidence = 88;
  bool _recalibrating = false;
  int _lowStreak = 0;
  String? _pauseReason;

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
          if (_voiceOn) {
            _cue = MockData.voiceCues[_rng.nextInt(MockData.voiceCues.length)];
          }
        }
      });
    });
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
                    child: Row(
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
                      label: Text(_paused ? 'Resume' : 'Pause'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger),
                      onPressed: _end,
                      child: const Text('End session'),
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
/// BlazePose landmark overlay.
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
class WorkoutResultScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final minutes = (seconds / 60).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session summary'),
        automaticallyImplyLeading: false,
      ),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.primaryTint,
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 44, color: AppColors.primary),
                const SizedBox(height: 12),
                Text('Session complete',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Nice work. Your form held up well today.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatTile('$reps', 'Reps')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile('$accuracy%', 'Avg form',
                      valueColor: accuracy >= 80
                          ? AppColors.success
                          : AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(child: StatTile('$minutes', 'Minutes')),
            ],
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
                const Icon(Icons.emoji_events_rounded,
                    color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('+120 points earned this session',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
