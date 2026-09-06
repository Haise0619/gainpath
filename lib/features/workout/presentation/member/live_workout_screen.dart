import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/shared/shared.dart';
import 'package:gainpath/features/workout/domain/entities/exercise.dart';
import 'package:gainpath/features/workout/domain/repositories/workout_repository.dart';
import 'package:gainpath/features/workout/presentation/member/widgets/recalibration_overlay.dart';
import 'package:gainpath/features/workout/presentation/member/widgets/skeleton_painter.dart';
import 'package:gainpath/features/workout/presentation/member/workout_result_screen.dart';

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

  Exercise get _currentExercise => context.read<WorkoutRepository>().routine[_exerciseIndex];

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
            _cue = context.read<WorkoutRepository>().voiceCues[_rng.nextInt(context.read<WorkoutRepository>().voiceCues.length)];
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
    } else if (_exerciseIndex < context.read<WorkoutRepository>().routine.length - 1) {
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
                        painter: SkeletonPainter(_controller.value),
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
                                  'Exercise ${_exerciseIndex + 1} of ${context.read<WorkoutRepository>().routine.length} · '
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
                    Positioned.fill(child: RecalibrationOverlay(confidence: _confidence)),
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
