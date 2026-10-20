import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/workout.dart';
import 'widgets/workout_media.dart';
import '../../domain/workout_contracts.dart' show WorkoutSessionSummary;

class WorkoutResultScreen extends StatefulWidget {
  final int reps;
  final int accuracy;
  final int seconds;
  final WorkoutSessionSummary? measuredSummary;
  final Widget? syncPanel;

  WorkoutResultScreen.measured(
      {super.key, required WorkoutSessionSummary summary, this.syncPanel})
      : measuredSummary = summary,
        reps = summary.repetitions,
        accuracy = summary.formScorePercent?.round() ?? 0,
        seconds = summary.trackedDurationMicros ~/ 1000000;

  const WorkoutResultScreen({
    super.key,
    required this.reps,
    required this.accuracy,
    required this.seconds,
  })  : measuredSummary = null,
        syncPanel = null;

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
    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 560));
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
    if (widget.measuredSummary != null) {
      return _measured(context, widget.measuredSummary!);
    }
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
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 22,
                      offset: const Offset(0, 10)),
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
                    child: const Icon(Icons.check_rounded,
                        size: 34, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text('Session complete',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Nice work. Your form held up well today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13.5)),
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
              children: List.generate(
                  context.read<WorkoutRepository>().routine.length, (i) {
                final e = context.read<WorkoutRepository>().routine[i];
                final pct = (widget.accuracy + (e.name.hashCode % 11 - 5))
                    .clamp(58, 99);
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, indent: 68),
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                            width: 40,
                            height: 40,
                            child: networkHero(e.imageUrl)),
                      ),
                      title: Text(e.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 14)),
                      subtitle: Text('${e.sets} sets  ·  ${e.reps} reps',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontSize: 12)),
                      trailing: Text('$pct%',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: pct >= 80
                                  ? AppColors.success
                                  : AppColors.warning)),
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
                _feedback(
                    context,
                    Icons.warning_amber_rounded,
                    AppColors.warning,
                    'Watch your knees',
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
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: _pointsEarned),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                        '+$value points earned this session',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () =>
                showToast(context, 'Opening your device share sheet.'),
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

  Widget _measured(BuildContext context, WorkoutSessionSummary summary) {
    final metrics = summary.poseMetrics!;
    final score = summary.formScorePercent;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Session summary'),
            automaticallyImplyLeading: false),
        body: PageBody(children: [
          Panel(
              background: AppColors.primaryTint,
              child: Column(children: [
                const Icon(Icons.check_circle_outline,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Text('Saved on this device',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                    widget.syncPanel == null
                        ? 'Local result · not server-accepted. No rewards have been awarded.'
                        : 'Your measured result is saved locally. No rewards have been awarded.',
                    textAlign: TextAlign.center),
              ])),
          if (widget.syncPanel != null) ...[
            const SizedBox(height: 16),
            widget.syncPanel!
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: StatTile('${summary.repetitions}', 'Full reps')),
            const SizedBox(width: 10),
            Expanded(
                child:
                    StatTile('${summary.partialRepetitions}', 'Partial reps'))
          ]),
          const SizedBox(height: 16),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Eyebrow('Measured squat result'),
                const SizedBox(height: 8),
                Text(
                    score == null
                        ? 'Not enough evidence'
                        : '${score.toStringAsFixed(0)}% estimated form',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                    'Tracked: ${(summary.trackedDurationMicros / 1000000).toStringAsFixed(1)} seconds'),
                Text(
                    'Unassessable: ${(summary.rejectedDurationMicros / 1000000).toStringAsFixed(1)} seconds'),
                const SizedBox(height: 8),
                const Text(
                    'Estimates use the side view. Unfinished movements are not counted as full repetitions.'),
              ])),
          const SizedBox(height: 16),
          const Eyebrow('Observed deviations'),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (metrics.deviations.isEmpty)
                  Text(score == null
                      ? 'No completed attempt was available to assess.'
                      : 'No supported deviation was detected in assessed attempts.'),
                for (final entry in metrics.deviations.entries)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                          '${entry.key == 'trunkLean' ? 'Trunk lean' : 'Incomplete depth'}: ${entry.value.count} attempts')),
                const SizedBox(height: 8),
                const Text(
                    'Front-view knee alignment is not assessed. Guidance is provisional.'),
              ])),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Back to home')),
        ]));
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
