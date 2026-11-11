import 'package:flutter/material.dart';
import 'workout_hub_visuals.dart';

class WorkoutHubLayout extends StatefulWidget {
  const WorkoutHubLayout(
      {super.key,
      required this.identity,
      required this.hero,
      required this.plan,
      required this.exercises,
      required this.activity,
      required this.help,
      this.onSettings,
      this.exerciseAction});
  final String identity;
  final Widget hero, plan, activity, help;
  final List<Widget> exercises;
  final VoidCallback? onSettings;
  final Widget? exerciseAction;
  @override
  State<WorkoutHubLayout> createState() => _WorkoutHubLayoutState();
}

class _WorkoutHubLayoutState extends State<WorkoutHubLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300))
    ..forward();
  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (workoutHubMotion(context) == Duration.zero) _entrance.value = 1;
  }

  Widget section(int index, Widget child) => WorkoutHubEntrance(
      animation: _entrance,
      index: index,
      child: Padding(padding: const EdgeInsets.only(bottom: 24), child: child));
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
          key: const PageStorageKey('workout-hub-scroll'),
          slivers: [
            SliverAppBar(
                pinned: true,
                titleSpacing: 20,
                title: const Text('Workout'),
                actions: [
                  if (widget.onSettings != null)
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                            tooltip: 'Workout settings',
                            onPressed: widget.onSettings,
                            icon: const Icon(Icons.settings_outlined)))
                ]),
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                sliver: SliverToBoxAdapter(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      section(
                          0,
                          WorkoutHubResize(
                              child: AnimatedSwitcher(
                                  duration: workoutHubMotion(context, 180),
                                  // Only the current identity is interactive or exposed to semantics.
                                  layoutBuilder: (current, previous) =>
                                      current ?? const SizedBox.shrink(),
                                  child: KeyedSubtree(
                                      key: ValueKey(widget.identity),
                                      child: widget.hero)))),
                      section(1, widget.plan),
                      if (widget.exercises.isNotEmpty)
                        section(
                            2,
                            WorkoutHubExercises(
                                key: ValueKey(widget.identity),
                                rows: widget.exercises,
                                action: widget.exerciseAction)),
                      section(3, widget.activity),
                      section(4, widget.help),
                    ]))),
          ]));
}

class WorkoutHubExercises extends StatefulWidget {
  const WorkoutHubExercises({super.key, required this.rows, this.action});
  final List<Widget> rows;
  final Widget? action;
  @override
  State<WorkoutHubExercises> createState() => _WorkoutHubExercisesState();
}

class _WorkoutHubExercisesState extends State<WorkoutHubExercises> {
  final _anchor = GlobalKey();
  bool _expanded = false, _changing = false;
  Future<void> _toggle() async {
    if (_changing) return;
    _changing = true;
    if (_expanded) {
      // Scroll before shortening the content, preserving the exercise section.
      await Scrollable.ensureVisible(_anchor.currentContext!,
          alignment: .08,
          duration: workoutHubMotion(context),
          curve: Curves.easeInOutCubic);
    }
    if (mounted) setState(() => _expanded = !_expanded);
    _changing = false;
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            key: _anchor,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text('Your exercises',
                  style: Theme.of(context).textTheme.titleLarge),
              Text(
                  '${widget.rows.length} ${widget.rows.length == 1 ? 'exercise' : 'exercises'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 12)),
              if (widget.action != null) widget.action!,
            ]),
        const SizedBox(height: 12),
        WorkoutHubResize(
            child: Column(children: [
          for (final row
              in widget.rows.take(_expanded ? widget.rows.length : 3))
            row,
        ])),
        if (widget.rows.length > 3)
          TextButton.icon(
              onPressed: _toggle,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(_expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded),
              label: Text(_expanded
                  ? 'Show fewer exercises'
                  : 'View all ${widget.rows.length} exercises')),
      ]);
}

class WorkoutHubResize extends StatelessWidget {
  const WorkoutHubResize({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      workoutHubMotion(context) == Duration.zero
          ? child
          : AnimatedSize(
              duration: workoutHubMotion(context, 260),
              alignment: Alignment.topCenter,
              curve: Curves.easeInOutCubic,
              child: child);
}

class WorkoutHubDestination extends StatelessWidget {
  const WorkoutHubDestination(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      this.onTap,
      this.action});
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? action;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), p = WorkoutHubPalette.of(context);
    return Semantics(
        button: true,
        enabled: onTap != null,
        onTap: onTap,
        excludeSemantics: true,
        label: [title, subtitle, if (action != null) action!].join('. '),
        child: Material(
            color: t.colorScheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                  color: p.primary.fill,
                                  borderRadius: BorderRadius.circular(12)),
                              child:
                                  Icon(icon, size: 20, color: p.primary.ink)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(title,
                                    style: t.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(subtitle,
                                    style: t.textTheme.bodyMedium?.copyWith(
                                        fontSize: 12,
                                        color: t.colorScheme.onSurfaceVariant)),
                                if (action != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(action!,
                                          style: t.textTheme.labelLarge
                                              ?.copyWith(
                                                  color: p.primary.ink))),
                              ])),
                          if (onTap != null)
                            Padding(
                                padding: const EdgeInsets.only(left: 6, top: 8),
                                child: Icon(Icons.chevron_right_rounded,
                                    size: 18,
                                    color: t.colorScheme.onSurfaceVariant)),
                        ])))));
  }
}

class WorkoutHubSection extends StatelessWidget {
  const WorkoutHubSection(
      {super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        child
      ]);
}
