import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/workout_activity_summary.dart';
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
      child: Padding(padding: const EdgeInsets.only(bottom: 26), child: child));
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
                      if (widget.exercises.isNotEmpty)
                        section(
                            1,
                            WorkoutHubExercises(
                                key: ValueKey(widget.identity),
                                rows: widget.exercises,
                                action: widget.exerciseAction)),
                      section(widget.exercises.isNotEmpty ? 2 : 1, widget.plan),
                      section(widget.exercises.isNotEmpty ? 3 : 2, widget.activity),
                      section(widget.exercises.isNotEmpty ? 4 : 3, widget.help),
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
        MemberSectionHeader(
          key: _anchor,
          title: "Today's exercises",
          padded: false,
          trailing: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${widget.rows.length} ${widget.rows.length == 1 ? 'exercise' : 'exercises'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.action != null) widget.action!,
            ],
          ),
        ),
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
      {super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MemberSectionHeader(
          title: title,
          trailing: trailing,
          padded: false,
        ),
        const SizedBox(height: 12),
        child
      ]);
}

class WorkoutHubTrainingPlanCard extends StatelessWidget {
  const WorkoutHubTrainingPlanCard({
    super.key,
    required this.hasPlan,
    this.planTitle,
    this.planSubtitle,
    this.onOpenPrograms,
    this.onReturnToPlanned,
  });

  final bool hasPlan;
  final String? planTitle;
  final String? planSubtitle;
  final VoidCallback? onOpenPrograms;
  final VoidCallback? onReturnToPlanned;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkoutHubSection(
          title: 'Training Plan',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EDFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasPlan ? 'Active plan' : 'No active plan',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7E3AF2),
              ),
            ),
          ),
          child: Semantics(
            button: true,
            enabled: onOpenPrograms != null,
            onTap: onOpenPrograms,
            label: !hasPlan
                ? 'Make room for your next goal. Explore tailored training programs and find a routine that fits your goals. Explore programs'
                : [
                    planTitle ?? 'Your Training Plan',
                    planSubtitle ?? '',
                    'View Plan'
                  ].join('. '),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF6EFFC),
                    Color(0xFFE8D5F9),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A6A26B8),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Image.asset(
                      'assets/images/lavender_fitness_planning_essentials.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: [0.0, 0.45, 0.82],
                          colors: [
                            Color(0x35F6EFFC),
                            Color(0x15F6EFFC),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 340;
                        final textScale =
                            MediaQuery.textScalerOf(context).scale(14) / 14;
                        final maxTextWidth = (textScale > 1.3 || isNarrow)
                            ? constraints.maxWidth * 0.54
                            : constraints.maxWidth * 0.52;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxTextWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasPlan
                                      ? (planTitle ?? 'Your Training Plan')
                                      : 'Build your strength\nwith a structured plan',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                    color: Color(0xFF1E1430),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  planSubtitle ??
                                      'Explore tailored training programs and find a routine that fits your goals.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton(
                            onPressed: onOpenPrograms,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6A26B8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    hasPlan ? 'View Plan' : 'Explore programs',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ],
                            ),
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
      ),
        if (onReturnToPlanned != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onReturnToPlanned,
              child: const Text('Back to planned workout'),
            ),
          ),
      ],
    );
  }
}

class WorkoutHubActivityCard extends StatelessWidget {
  const WorkoutHubActivityCard({
    super.key,
    this.onOpenRoutineHistory,
    this.onOpenProgress,
    this.summary,
    this.workoutsCount,
    this.minutesCount,
    this.activeDaysText,
  });

  final VoidCallback? onOpenRoutineHistory;
  final VoidCallback? onOpenProgress;
  final WorkoutActivitySummary? summary;
  final int? workoutsCount;
  final int? minutesCount;
  final String? activeDaysText;

  @override
  Widget build(BuildContext context) {
    final effectiveSummary = summary ?? WorkoutActivitySummary.empty();
    final effectiveWorkouts = workoutsCount ?? effectiveSummary.workoutsCount;
    final effectiveMinutes = minutesCount ?? effectiveSummary.minutesCount;
    final effectiveActiveDays =
        activeDaysText ?? effectiveSummary.activeDaysText;
    final effectiveDays = effectiveSummary.days;

    return WorkoutHubSection(
      title: 'Your Activity',
      trailing: InkWell(
        onTap: onOpenProgress,
        borderRadius: BorderRadius.circular(8),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This Week',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6A26B8),
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Color(0xFF6A26B8),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 320;
                final chart = _buildChart(effectiveDays);
                final stats = _buildStats(
                    effectiveWorkouts, effectiveMinutes, effectiveActiveDays);

                if (isNarrow) {
                  return Column(
                    children: [
                      chart,
                      const SizedBox(height: 16),
                      stats,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 11, child: chart),
                    const SizedBox(width: 14),
                    Expanded(flex: 9, child: stats),
                  ],
                );
              },
            ),
            const Divider(
              height: 28,
              thickness: 1,
              color: Color(0xFFF3F4F6),
            ),
            InkWell(
              onTap: onOpenRoutineHistory,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: Color(0xFF1E1430),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Workout ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1430),
                            ),
                          ),
                          Text(
                            'History',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1430),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: onOpenProgress,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights_outlined,
                      size: 20,
                      color: Color(0xFF1E1430),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1430),
                            ),
                          ),
                          Text(
                            ' & Insights',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E1430),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<WorkoutActivityDay> days) {
    final maxMinutes =
        days.fold<int>(0, (max, d) => d.minutes > max ? d.minutes : max);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: maxMinutes == 0
                      ? 6.0
                      : (day.minutes / maxMinutes * 38.0 + 6.0).clamp(6.0, 44.0),
                  decoration: BoxDecoration(
                    color: day.hasWorkout
                        ? const Color(0xFF6A26B8)
                        : const Color(0xFFEDE4F8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  day.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
                    color: day.isToday
                        ? const Color(0xFF6A26B8)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStats(int workouts, int minutes, String activeDays) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.fitness_center_rounded,
              size: 17,
              color: Color(0xFF6A26B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '$workouts ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1430),
                  ),
                  children: const [
                    TextSpan(
                      text: 'Workouts',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 17,
              color: Color(0xFF6A26B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '$minutes ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1430),
                  ),
                  children: const [
                    TextSpan(
                      text: 'Minutes',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 17,
              color: Color(0xFFFF6D00),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '$activeDays ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1430),
                  ),
                  children: const [
                    TextSpan(
                      text: 'Active days',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WorkoutHubEquipmentGuidanceCard extends StatelessWidget {
  const WorkoutHubEquipmentGuidanceCard({
    super.key,
    this.onBrowseEquipment,
    this.onCameraSetup,
    this.onTryPosePreview,
  });

  final VoidCallback? onBrowseEquipment;
  final VoidCallback? onCameraSetup;
  final VoidCallback? onTryPosePreview;

  @override
  Widget build(BuildContext context) {
    return WorkoutHubSection(
      title: 'Equipment & Guidance',
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                InkWell(
                  onTap: onBrowseEquipment,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5EEFB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/gainpath_equipment_guide.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.fitness_center_outlined,
                              color: Color(0xFF6A26B8),
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Equipment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E1430),
                                    ),
                                  ),
                                  Text(
                                    ' Guide',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E1430),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Browse equipment, setup & usage tips',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                  indent: 82,
                  endIndent: 16,
                  color: Color(0xFFF3F4F6),
                ),
                InkWell(
                  onTap: onCameraSetup,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5EEFB),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/gainpath_ai_camera_setup.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.videocam_outlined,
                              color: Color(0xFF6A26B8),
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Camera Setup',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E1430),
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Camera position & tracking tips for better AI feedback',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onTryPosePreview != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: onTryPosePreview,
                child: const Text('Try live camera preview'),
              ),
            ),
        ],
      ),
    );
  }
}
