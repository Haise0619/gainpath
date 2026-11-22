import 'package:flutter/material.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../features/workout/data/published_routine.dart';
import '../../features/workout/domain/routine_attempt.dart';
import '../../features/workout/presentation/member/widgets/workout_exercise_image.dart';
import 'member_home_data.dart';

Duration _motion(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: milliseconds);

class HomeWeeklyActivity extends StatelessWidget {
  const HomeWeeklyActivity({super.key, this.progress, this.routines});

  final MemberLocalProgress? progress;
  final RoutineProgress? routines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasActivity = routines != null || progress != null;
    final records = progress?.weeklySessions;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? scheme.outlineVariant
              : AppColors.hairline,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WeeklyAchievement(completed: routines?.weeklyCompleted),
              if (hasActivity)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly activity',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      _WeeklyDayTrack(
                          days: homeWeekActivity(routines, progress)),
                      if (records != null) ...[
                        const SizedBox(height: 8),
                        _WeeklyExerciseRecords(count: records),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyAchievement extends StatelessWidget {
  const _WeeklyAchievement({required this.completed});

  final int? completed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = completed;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF491986), Color(0xFF7027DC), Color(0xFF914BF2)],
          stops: [0, .7, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 9, 15, 9),
        child: LayoutBuilder(builder: (context, bounds) {
          final showArt = count != null &&
              bounds.maxWidth >= 230 &&
              MediaQuery.textScalerOf(context).scale(16) <= 22;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('THIS WEEK',
                        style: text.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        )),
                    const SizedBox(height: 3),
                    if (count == null)
                      Text('Workout progress is loading.',
                          style:
                              text.titleMedium?.copyWith(color: Colors.white))
                    else
                      Wrap(
                        spacing: 9,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: reducedMotion ? count.toDouble() : 0,
                              end: count.toDouble(),
                            ),
                            duration: _motion(context, 280),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Semantics(
                              container: true,
                              label: '$count completed workouts',
                              excludeSemantics: true,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  (reducedMotion ? count : value.round())
                                      .toString(),
                                  key: const ValueKey(
                                      'home-weekly-completion-count'),
                                  style: text.displaySmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 42,
                                    height: 1.04,
                                    letterSpacing: -1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Text('Workouts completed',
                              style: text.titleMedium?.copyWith(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.15,
                              )),
                        ],
                      ),
                  ],
                ),
              ),
              if (showArt) ...[
                const SizedBox(width: 8),
                const _AchievementDumbbell(),
              ],
            ],
          );
        }),
      ),
    );
  }
}

/// Decorative illustration, isolated from the card's activity semantics.
class _AchievementDumbbell extends StatelessWidget {
  const _AchievementDumbbell();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 70,
        height: 66,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final diameter in [62.0, 48.0])
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: .25)),
                ),
              ),
            Transform.rotate(
              angle: -.35,
              child: Icon(Icons.fitness_center_rounded,
                  size: 34, color: Colors.white.withValues(alpha: .88)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyDayTrack extends StatelessWidget {
  const _WeeklyDayTrack({required this.days});

  final List<HomeDayActivity> days;
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, bounds) {
          final dayWidth = bounds.maxWidth / _weekdays.length;
          final scaler = MediaQuery.textScalerOf(context);
          final letters = dayWidth - 2 >= scaler.scale(25) ? 3 : 2;
          return Row(children: [
            for (var index = 0; index < days.length; index++)
              Expanded(
                child: _DayMarker(
                  day: _weekdays[index],
                  short: _weekdays[index].substring(0, letters),
                  state: days[index],
                ),
              ),
          ]);
        }),
        const SizedBox(height: 7),
        Wrap(spacing: 10, runSpacing: 4, children: [
          const _DayLegend(HomeDayActivity.completed),
          const _DayLegend(HomeDayActivity.inProgress),
          if (days.contains(HomeDayActivity.exerciseRecord))
            const _DayLegend(HomeDayActivity.exerciseRecord),
          const _DayLegend(HomeDayActivity.none),
        ]),
      ],
    );
  }
}

class _WeeklyExerciseRecords extends StatelessWidget {
  const _WeeklyExerciseRecords({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.assignment_outlined, color: scheme.primary, size: 16),
            const SizedBox(width: 7),
            Expanded(
              child: Text('Exercise records saved this week',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 7),
            Text('$count',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                )),
          ],
        ),
      ),
    );
  }
}

extension on HomeDayActivity {
  String get label => switch (this) {
        HomeDayActivity.completed => 'Completed',
        HomeDayActivity.inProgress => 'In progress',
        HomeDayActivity.exerciseRecord => 'Exercise record',
        HomeDayActivity.none => 'No activity',
      };

  IconData get icon => switch (this) {
        HomeDayActivity.completed => Icons.check_rounded,
        HomeDayActivity.inProgress => Icons.schedule_rounded,
        HomeDayActivity.exerciseRecord => Icons.assignment_outlined,
        HomeDayActivity.none => Icons.remove_rounded,
      };

  (Color, Color) colors(ColorScheme scheme) => switch (this) {
        HomeDayActivity.completed => (scheme.primary, scheme.onPrimary),
        HomeDayActivity.inProgress => (
            const Color(0xFFFFE9D3),
            const Color(0xFF8B410A)
          ),
        HomeDayActivity.exerciseRecord => (
            scheme.brightness == Brightness.dark
                ? scheme.secondaryContainer
                : const Color(0xFFEBEAFF),
            scheme.brightness == Brightness.dark
                ? scheme.onSecondaryContainer
                : const Color(0xFF4D3E92),
          ),
        HomeDayActivity.none => (
            scheme.brightness == Brightness.dark
                ? scheme.surfaceContainerHigh
                : const Color(0xFFF3F0F8),
            scheme.onSurfaceVariant,
          ),
      };
}

class _DayMarker extends StatelessWidget {
  const _DayMarker({
    required this.day,
    required this.short,
    required this.state,
  });

  final String day, short;
  final HomeDayActivity state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = state.colors(theme.colorScheme);
    final tile = DecoratedBox(
      key: ValueKey(state),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 34,
        child: Icon(state.icon, size: 17, color: foreground),
      ),
    );
    return Semantics(
      container: true,
      label: '$day, ${state.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(short,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ),
            const SizedBox(height: 5),
            if (MediaQuery.disableAnimationsOf(context))
              tile
            else
              AnimatedSwitcher(
                duration: _motion(context, 240),
                child: tile,
              ),
          ],
        ),
      ),
    );
  }
}

class _DayLegend extends StatelessWidget {
  const _DayLegend(this.state);
  final HomeDayActivity state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = state.colors(theme.colorScheme);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      DecoratedBox(
          decoration: BoxDecoration(
              color: background, borderRadius: BorderRadius.circular(4)),
          child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(state.icon, size: 10, color: foreground))),
      const SizedBox(width: 4),
      Flexible(
          child: Text(state.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ))),
    ]);
  }
}

class HomeRecentActivity extends StatelessWidget {
  const HomeRecentActivity(
      {super.key,
      required this.live,
      this.localProgress,
      this.routines,
      this.selected,
      this.scope,
      this.onOpenHistory,
      this.onOpenWorkout,
      this.onOpenRoutine});

  final bool live;
  final MemberLocalProgress? localProgress;
  final RoutineProgress? routines;
  final PublishedRoutine? selected;
  final SessionScope? scope;
  final VoidCallback? onOpenHistory;
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;
  final void Function(RoutineAttempt)? onOpenRoutine;

  @override
  Widget build(BuildContext context) {
    final account = scope;
    final items = account == null
        ? <HomeActivity>[]
        : homeRecentActivities(account, localProgress, routines, selected);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(
            child:
                MemberSectionHeader(title: 'Recent activity', padded: false)),
        if (onOpenHistory != null)
          TextButton(
            onPressed: onOpenHistory,
            style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsetsDirectional.only(start: 8, end: 4)),
            child: const Text('View all'),
          ),
      ]),
      const SizedBox(height: 4),
      Panel(
        padding: items.isEmpty ? const EdgeInsets.all(14) : EdgeInsets.zero,
        child: items.isEmpty
            ? Text(
                live && localProgress == null && routines == null
                    ? 'Loading saved activity…'
                    : 'No saved workouts yet.',
                style: Theme.of(context).textTheme.bodyMedium)
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(children: [
                  for (final (index, item) in items.indexed)
                    _ActivityRow(
                      key: ValueKey((item.attempt?.id, item.record?.sessionId)),
                      item: item,
                      hasDivider: index > 0,
                      date: _date(item.at),
                      onTap: _open(item),
                    ),
                ]),
              ),
      ),
    ]);
  }

  VoidCallback? _open(HomeActivity item) {
    final attempt = item.attempt;
    final record = item.record;
    if (attempt != null && onOpenRoutine != null) {
      return () => onOpenRoutine!(attempt);
    }
    if (record != null && onOpenWorkout != null) {
      return () => onOpenWorkout!(record);
    }
    return null;
  }

  String _date(DateTime at) {
    final d =
        at.toUtc().add(localProgress?.utcOffset ?? const Duration(hours: 8));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final current = routines?.asOf ?? localProgress?.asOf;
    final year = current
        ?.toUtc()
        .add(localProgress?.utcOffset ?? const Duration(hours: 8))
        .year;
    return '${d.day} ${months[d.month - 1]}${d.year == year ? '' : ' ${d.year}'}';
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(
      {super.key,
      required this.item,
      required this.date,
      required this.hasDivider,
      this.onTap});

  final HomeActivity item;
  final String date;
  final bool hasDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final attempt = item.attempt;
    final inProgress = attempt != null && !attempt.finished;
    final completed = attempt?.isComplete == true;
    final label = attempt?.statusLabel ?? 'Exercise record';
    final total = attempt?.entries.length ?? 0;
    final count = attempt?.completedExercises ?? 0;
    final (background, foreground) = completed
        ? (AppColors.successTint, const Color(0xFF166534))
        : inProgress
            ? HomeDayActivity.inProgress.colors(scheme)
            : (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);
    final metaStyle =
        theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _motion(context, 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, (1 - value) * 6), child: child)),
      child: Column(children: [
        if (hasDivider) const Divider(height: 1, indent: 12, endIndent: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.square(
                      dimension: 44,
                      child: WorkoutExerciseImage(
                          url: item.imageUrl, fit: BoxFit.cover)),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            attempt == null
                                ? '$date · ${item.result}'
                                : '$date · $count/$total exercises',
                            semanticsLabel: attempt == null
                                ? null
                                : '$date, $count of $total exercises completed',
                            style: metaStyle,
                          ),
                          AnimatedSwitcher(
                            layoutBuilder: (current, previous) => Stack(
                                alignment: AlignmentDirectional.centerStart,
                                children: [
                                  ...previous,
                                  if (current != null) current
                                ]),
                            duration: _motion(context, 240),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                        scale: Tween(begin: .88, end: 1.0)
                                            .animate(animation),
                                        alignment: Alignment.centerLeft,
                                        child: child)),
                            child: DecoratedBox(
                              key: ValueKey(label),
                              decoration: BoxDecoration(
                                  color: background,
                                  borderRadius: BorderRadius.circular(7)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                child: Text(label,
                                    style: metaStyle?.copyWith(
                                        color: foreground,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (inProgress && total > 0) ...[
                        const SizedBox(height: 7),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: count / total),
                          duration: _motion(context, 350),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                            value: value,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(4),
                            color: AppColors.warning,
                            backgroundColor: background,
                            semanticsLabel: 'Exercise completion',
                            semanticsValue: '$count of $total',
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(item.backupLabel, style: metaStyle),
                    ])),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right,
                      size: 18, color: scheme.onSurfaceVariant),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
