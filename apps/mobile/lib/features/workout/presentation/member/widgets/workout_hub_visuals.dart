import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class WorkoutHubTone {
  const WorkoutHubTone(this.ink, this.fill);
  final Color ink, fill;
}

class WorkoutHubPalette {
  const WorkoutHubPalette(
      this.primary, this.info, this.success, this.caution, this.neutral);
  final WorkoutHubTone primary, info, success, caution, neutral;
  static const light = WorkoutHubPalette(
      WorkoutHubTone(AppColors.primary, AppColors.primaryTint),
      WorkoutHubTone(Color(0xFF626778), Color(0xFFF1F2F5)),
      WorkoutHubTone(Color(0xFF237A4B), Color(0xFFEAF7EF)),
      WorkoutHubTone(Color(0xFF92400E), Color(0xFFFFF0DF)),
      WorkoutHubTone(AppColors.inkSoft, AppColors.surfaceAlt));
  static const dark = WorkoutHubPalette(
      WorkoutHubTone(Color(0xFFD8C5FF), Color(0xFF302046)),
      WorkoutHubTone(Color(0xFFA8C7FA), Color(0xFF142C51)),
      WorkoutHubTone(Color(0xFF86EFAC), Color(0xFF123526)),
      WorkoutHubTone(Color(0xFFFCD34D), Color(0xFF3A2B14)),
      WorkoutHubTone(Color(0xFFD4CDE0), Color(0xFF30283E)));
  static WorkoutHubPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
  List<WorkoutHubTone> get tones => [primary, info, success, caution, neutral];
}

Duration workoutHubMotion(BuildContext context, [int milliseconds = 240]) =>
    MediaQuery.disableAnimationsOf(context) ||
            MediaQuery.accessibleNavigationOf(context)
        ? Duration.zero
        : Duration(milliseconds: milliseconds);

class WorkoutHubBadge extends StatelessWidget {
  const WorkoutHubBadge(
      {super.key, required this.icon, required this.label, required this.tone});
  final IconData icon;
  final String label;
  final WorkoutHubTone tone;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: tone.fill, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: Icon(icon, size: 14, color: tone.ink)),
        const SizedBox(width: 5),
        Flexible(
            child: Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: tone.ink,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600))),
      ]));
}

/// Owns interaction feedback only. Domain state and persistence stay upstream.
class WorkoutHubOverview extends StatefulWidget {
  const WorkoutHubOverview(
      {super.key,
      required this.title,
      required this.eyebrow,
      required this.exerciseCount,
      required this.totalSets,
      required this.minutes,
      required this.completed,
      required this.total,
      required this.status,
      required this.action,
      required this.actionIcon,
      required this.onStart,
      this.switcher,
      this.scheduleStatus,
      this.support,
      this.supportSemantics,
      this.started = false});
  final String title, eyebrow, status, action;
  final String? scheduleStatus, support, supportSemantics;
  final int exerciseCount, totalSets, completed, total;
  final int? minutes;
  final Widget? switcher;
  final bool started;
  final IconData actionIcon;
  final FutureOr<void> Function() onStart;
  @override
  State<WorkoutHubOverview> createState() => _WorkoutHubOverviewState();
}

class _WorkoutHubOverviewState extends State<WorkoutHubOverview> {
  bool _pressed = false;
  bool _launching = false;
  Future<void> _start() async {
    if (_launching || ModalRoute.of(context)?.isCurrent == false) return;
    setState(() => _launching = true);
    try {
      await Future<void>.sync(widget.onStart);
      await WidgetsBinding.instance.endOfFrame;
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), p = WorkoutHubPalette.of(context);
    final done = widget.total > 0 && widget.completed >= widget.total;
    final value = widget.total <= 0
        ? 0.0
        : (widget.completed / widget.total).clamp(0.0, 1.0);
    final progress = widget.started || widget.completed > 0;
    return Material(
        key: const ValueKey('current-workout-hero'),
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: p.primary.fill)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                        color: p.primary.ink,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(widget.eyebrow,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: p.primary.ink,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1))),
              ]),
              const SizedBox(height: 10),
              Text(widget.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: theme.textTheme.titleLarge?.fontFamily,
                      fontSize: 26,
                      height: 1.1,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 6, children: [
                _Fact(
                    icon: Icons.fitness_center_rounded,
                    label:
                        '${widget.exerciseCount} ${widget.exerciseCount == 1 ? 'exercise' : 'exercises'}'),
                _Fact(
                    icon: Icons.layers_outlined,
                    label:
                        '${widget.totalSets} ${widget.totalSets == 1 ? 'set' : 'sets'}'),
                if (widget.minutes != null)
                  _Fact(
                      icon: Icons.schedule_rounded,
                      label: '~${widget.minutes} min'),
              ]),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                  duration: workoutHubMotion(context, 180),
                  child: Row(key: ValueKey(widget.status), children: [
                    Icon(
                        done
                            ? Icons.check_circle_outline
                            : progress
                                ? Icons.timelapse_rounded
                                : Icons.circle,
                        size: progress || done ? 16 : 6,
                        color: done
                            ? p.caution.ink
                            : progress
                                ? p.primary.ink
                                : const Color(0xFFFF9A3C)),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Text(widget.status,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant))),
                    if (progress)
                      Text('${widget.completed} / ${widget.total}',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: p.primary.ink)),
                  ])),
              if (progress) ...[
                const SizedBox(height: 8),
                Semantics(
                    label:
                        '${widget.completed} of ${widget.total} exercises completed',
                    child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: value, end: value),
                        duration: workoutHubMotion(context, 280),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                                key: const ValueKey('workout-progress'),
                                value: v,
                                minHeight: 4,
                                color: p.primary.ink,
                                backgroundColor: p.primary.fill)))),
              ],
              const SizedBox(height: 16),
              Listener(
                  onPointerDown: (_) {
                    if (!_launching) setState(() => _pressed = true);
                  },
                  onPointerUp: (_) => setState(() => _pressed = false),
                  onPointerCancel: (_) => setState(() => _pressed = false),
                  child: AnimatedScale(
                      scale: _pressed ? .985 : 1,
                      duration: workoutHubMotion(context, 100),
                      child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                              onPressed: _launching ? null : _start,
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 52),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14))),
                              icon: Icon(widget.actionIcon, size: 20),
                              label: Text(widget.action,
                                  textAlign: TextAlign.center))))),
              if (widget.switcher != null || widget.support != null) ...[
                const SizedBox(height: 6),
                LayoutBuilder(builder: (context, c) {
                  final support = widget.support == null
                      ? null
                      : Semantics(
                          label: widget.supportSemantics ?? widget.support,
                          excludeSemantics: true,
                          child: Text(widget.support!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              )));
                  if (c.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) > 21) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (support != null) support,
                          if (widget.switcher != null) widget.switcher!
                        ]);
                  }
                  return Row(children: [
                    if (support != null)
                      Expanded(child: support)
                    else
                      const Spacer(),
                    if (widget.switcher != null) widget.switcher!
                  ]);
                }),
              ],
              if (widget.scheduleStatus != null) ...[
                const SizedBox(height: 6),
                Text(widget.scheduleStatus!,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ])));
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 12))),
      ]);
}

/// Retains elapsed entrance time across parent rebuilds and tab returns.
class WorkoutHubEntrance extends StatelessWidget {
  const WorkoutHubEntrance(
      {super.key,
      required this.animation,
      required this.index,
      required this.child});
  final Animation<double> animation;
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (workoutHubMotion(context) == Duration.zero) return child;
    final curved = CurveTween(
            curve: Interval(index * .1, .6 + index * .1,
                curve: Curves.easeOutCubic))
        .animate(animation);
    return FadeTransition(
        opacity: curved,
        child: SlideTransition(
            position: Tween(begin: const Offset(0, .018), end: Offset.zero)
                .animate(curved),
            child: child));
  }
}
