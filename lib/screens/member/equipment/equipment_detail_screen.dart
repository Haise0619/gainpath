import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../workout_screens.dart' show ExerciseTutorialScreen;

/// Defensive network image loader: a broken/slow link never breaks the
/// layout — the same pattern used across onboarding, profile setup, and
/// the workout module.
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

/// The scan (or browse) result: what a member sees once equipment is
/// identified. The hero is a simulated tutorial video using the same
/// play/pause/scrubber mechanic as `ExerciseTutorialScreen` — tapping
/// play swaps the thumbnail for a dimmed, "now playing" state with a
/// real progress bar, so it reads and behaves like a video without
/// actually streaming one. "Related exercises" queries `MockData.routine`
/// by category rather than storing a manual join, mirroring how the data
/// dictionary itself resolves GymEquipment↔ExerciseVideo — and shows an
/// honest empty state when nothing in the current routine matches.
class EquipmentDetailScreen extends StatefulWidget {
  final GymEquipment equipment;
  const EquipmentDetailScreen({super.key, required this.equipment});

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _demoDuration = Duration(seconds: 6);

  late final AnimationController _progress;
  bool _playing = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
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
    final equipment = widget.equipment;
    final related = MockData.routine.where((e) => e.category == equipment.category).toList();

    return Scaffold(
      appBar: AppBar(title: Text(equipment.name)),
      body: PageBody(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _networkHero(equipment.imageUrl),
                  DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: _playing ? 0.5 : 0.22)),
                  ),
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
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('TUTORIAL VIDEO',
                          style: TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
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
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
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
          Text(equipment.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              statusPill(equipment.category),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.accentTint, borderRadius: BorderRadius.circular(8)),
                child: Text(equipment.muscleGroup,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.warning)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Eyebrow('Introduction'),
          Panel(
            child: Text(equipment.description, style: const TextStyle(fontSize: 14.5, height: 1.5)),
          ),
          const SizedBox(height: 18),
          const Eyebrow('How to use'),
          Panel(
            child: Column(
              children: List.generate(equipment.howToUse.length, (i) {
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 22),
                    _step(context, '${i + 1}', equipment.howToUse[i]),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Safety tips'),
          Panel(
            background: AppColors.dangerTint,
            child: Column(
              children: List.generate(equipment.safetyTips.length, (i) {
                return Padding(
                  padding: EdgeInsets.only(top: i > 0 ? 10 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(equipment.safetyTips[i],
                            style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Related exercises'),
          if (related.isEmpty)
            Panel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nothing in your current routine uses this equipment yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            ...related.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    padding: EdgeInsets.zero,
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ExerciseTutorialScreen(exercise: e))),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                          child: SizedBox(width: 64, height: 64, child: _networkHero(e.imageUrl)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.name, style: Theme.of(context).textTheme.titleMedium),
                              Text('${e.sets} sets × ${e.reps} reps  ·  ${e.muscleGroup}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 26),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, String number, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
          child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(body, style: const TextStyle(fontSize: 14, height: 1.45)),
        ),
      ],
    );
  }
}
