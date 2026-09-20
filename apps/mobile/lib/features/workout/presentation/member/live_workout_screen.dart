import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/live_session/workout_session_bloc.dart';
import 'package:gainpath_domain/workout.dart';
import 'widgets/recalibration_overlay.dart';
import 'widgets/skeleton_painter.dart';
import 'workout_result_screen.dart';

/// SD-M2.1 — AI-guided workout session. Provides a [WorkoutSessionBloc]
/// scoped to this screen; the view below only drives the clock and the
/// skeleton animation and renders whatever the Bloc says.
class LiveWorkoutScreen extends StatelessWidget {
  const LiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WorkoutSessionBloc(context.read<WorkoutRepository>()),
      child: const _LiveWorkoutView(),
    );
  }
}

class _LiveWorkoutView extends StatefulWidget {
  const _LiveWorkoutView();

  @override
  State<_LiveWorkoutView> createState() => _LiveWorkoutViewState();
}

class _LiveWorkoutViewState extends State<_LiveWorkoutView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    // In a real build the pose pipeline would dispatch ticks with measured
    // confidence; the prototype ticks once a second and lets the Bloc simulate.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) context.read<WorkoutSessionBloc>().add(const SessionTicked());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _end() async {
    final bloc = context.read<WorkoutSessionBloc>();
    final wasPaused = bloc.state.paused;
    if (!wasPaused) bloc.add(const SessionPaused());
    final ok = await confirmSheet(
      context,
      title: 'End this session?',
      message: 'Your ${bloc.state.reps} reps and form scores so far will be saved to your history.',
      confirmLabel: 'End and save',
    );
    if (!mounted) return;
    if (ok) {
      final s = bloc.state;
      bloc.add(const SessionEnded());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutResultScreen(reps: s.reps, accuracy: s.accuracy, seconds: s.elapsedSec),
        ),
      );
    } else if (!wasPaused) {
      bloc.add(const SessionResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
      builder: (context, s) {
        final bloc = context.read<WorkoutSessionBloc>();
        final exercise = s.currentExercise;
        return Scaffold(
          backgroundColor: AppColors.ink,
          body: SafeArea(
            child: Column(
              children: [
                // Camera viewport with skeleton overlay
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: Container(color: const Color(0xFF20302B))),
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (_, __) => CustomPaint(painter: SkeletonPainter(_controller.value)),
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
                                _pill(Icons.timer_outlined, s.clock),
                                const SizedBox(width: 8),
                                _pill(Icons.check_circle_outline_rounded, '${s.accuracy}%'),
                                const Spacer(),
                                IconButton(
                                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                                  tooltip: 'Simulate tracking loss (demo)',
                                  icon: const Icon(Icons.sensors_off_rounded, color: Colors.white, size: 20),
                                  onPressed: s.paused ? null : () => bloc.add(const TrackingIssueSimulated()),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                                  icon: Icon(
                                    s.voiceOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () => bloc.add(const VoiceToggled()),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (exercise != null)
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
                                        'Exercise ${s.exerciseIndex + 1} of ${s.routine.length} · '
                                        '${exercise.name} · Set ${s.setNumber}/${exercise.sets}',
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
                            Text('${s.reps}',
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
                            key: ValueKey(s.cue),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.graphic_eq_rounded, size: 18, color: AppColors.overlay),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(s.cue,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (s.recalibrating) Positioned.fill(child: RecalibrationOverlay(confidence: s.confidence)),
                      if (s.paused) Positioned.fill(child: _PauseMask(reason: s.pauseReason)),
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
                          onPressed: () =>
                              bloc.add(s.paused ? const SessionResumed() : const SessionPaused()),
                          icon: Icon(s.paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(s.paused ? 'Resume' : 'Pause', maxLines: 1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
      },
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
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// SD-M2.4 — blur mask shown while paused; explains a system-initiated pause.
class _PauseMask extends StatelessWidget {
  const _PauseMask({this.reason});
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reason != null) ...[
              const Icon(Icons.sensors_off_rounded, color: AppColors.warning, size: 30),
              const SizedBox(height: 10),
            ],
            Text(reason != null ? 'Session paused' : 'Paused',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
            if (reason != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(reason!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
