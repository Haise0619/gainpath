import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/workout.dart';
import 'widgets/skeleton_painter.dart';
import 'widgets/workout_media.dart';

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
                  if (!_playing) networkHero(e.imageUrl) else Container(color: AppColors.ink),
                  if (_playing)
                    AnimatedBuilder(
                      animation: _loop,
                      builder: (_, __) => CustomPaint(painter: SkeletonPainter(_loop.value)),
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
