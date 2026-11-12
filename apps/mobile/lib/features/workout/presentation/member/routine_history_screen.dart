import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/routine_attempt.dart';
import '../workout_presentation.dart';
import '../../domain/workout_contracts.dart';
import 'widgets/workout_result_content.dart';
import '../../../analytics/domain/member_workout_report.dart';
import '../../../analytics/domain/workout_activity_overview.dart';

DateTime _toLocalTime(int micros) =>
    DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true)
        .add(const Duration(hours: 8));

String _monthName(int month) {
  const months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return (month >= 1 && month <= 12) ? months[month] : '';
}

String _shortMonthName(int month) {
  const months = [
    '',
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
  return (month >= 1 && month <= 12) ? months[month] : '';
}

String _dateGroupKey(int micros, DateTime asOf) {
  final d = _toLocalTime(micros);
  final now = asOf.toUtc().add(const Duration(hours: 8));
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diffDays = today.difference(target).inDays;

  if (diffDays == 0 &&
      d.year == now.year &&
      d.month == now.month &&
      d.day == now.day) {
    return 'Today';
  } else if (diffDays == 1 ||
      (today.subtract(const Duration(days: 1)).year == d.year &&
          today.subtract(const Duration(days: 1)).month == d.month &&
          today.subtract(const Duration(days: 1)).day == d.day)) {
    return 'Yesterday';
  } else if (d.year == now.year && d.month == now.month) {
    return '${d.day} ${_monthName(d.month)}';
  } else if (d.year == now.year) {
    return '${d.day} ${_shortMonthName(d.month)}';
  } else {
    return '${d.day} ${_shortMonthName(d.month)} ${d.year}';
  }
}

String _friendlyTime(int micros) {
  final d = _toLocalTime(micros);
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  final minStr = d.minute.toString().padLeft(2, '0');
  return '$hour12:$minStr $ampm';
}

enum _HistoryFilter { all, completed, unfinished }

class RoutineHistoryScreen extends StatefulWidget {
  const RoutineHistoryScreen(
      {super.key,
      required this.attempts,
      required this.onOpenAttempt,
      this.onRefresh,
      this.onOpenBackup,
      this.asOf,
      this.saveStatusBuilder,
      this.embedded = false,
      this.available = true});
  final List<RoutineAttempt> attempts;
  final void Function(RoutineAttempt) onOpenAttempt;
  final Future<void> Function()? onRefresh;
  final bool available;
  final bool embedded;
  final VoidCallback? onOpenBackup;
  final DateTime? asOf;
  final Widget Function(RoutineAttempt)? saveStatusBuilder;

  @override
  State<RoutineHistoryScreen> createState() => _RoutineHistoryScreenState();
}

class _RoutineHistoryScreenState extends State<RoutineHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;
  int? _days = 30;

  @override
  Widget build(BuildContext context) {
    final now = widget.asOf ?? DateTime.now();
    final dates = _days == null
        ? WorkoutReportFilter.all()
        : WorkoutReportFilter.lastDays(now, _days!);
    final attempts = widget.attempts
        .where((a) => dates.includes(DateTime.fromMicrosecondsSinceEpoch(
            a.finishedAtMicros ?? a.updatedAtMicros,
            isUtc: true)))
        .where((attempt) => switch (_filter) {
              _HistoryFilter.all => true,
              _HistoryFilter.completed => attempt.isComplete,
              _HistoryFilter.unfinished => !attempt.isComplete,
            })
        .toList()
      ..sort((a, b) => (b.finishedAtMicros ?? b.updatedAtMicros)
          .compareTo(a.finishedAtMicros ?? a.updatedAtMicros));

    // Group attempts by date
    final grouped = <String, List<RoutineAttempt>>{};
    for (final a in (widget.available ? attempts : <RoutineAttempt>[])) {
      final key = _dateGroupKey(a.finishedAtMicros ?? a.updatedAtMicros, now);
      (grouped[key] ??= []).add(a);
    }

    final hasCustomFilters = _days != 30 || _filter != _HistoryFilter.all;

    return Scaffold(
        appBar: widget.embedded
            ? null
            : AppBar(title: const Text('Workout history'), actions: [
                if (widget.onOpenBackup != null)
                  IconButton(
                      tooltip: 'Workout backup',
                      onPressed: widget.onOpenBackup,
                      icon: const Icon(Icons.cloud_upload_outlined)),
                if (widget.onRefresh != null)
                  IconButton(
                      tooltip: 'Refresh',
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh_rounded))
              ]),
        body: RefreshIndicator(
            onRefresh: widget.onRefresh ?? () async {},
            child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Compact unified filter bar
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final days in <int?>[7, 30, null])
                        ChoiceChip(
                          label: Text(
                            days == null ? 'All time' : 'Last $days days',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _days == days
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _days == days
                                  ? Colors.white
                                  : AppColors.ink,
                            ),
                          ),
                          selected: _days == days,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceAlt,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                            color: _days == days
                                ? AppColors.primary
                                : AppColors.hairline,
                          ),
                          onSelected: (_) => setState(() => _days = days),
                        ),
                      Container(
                        height: 18,
                        width: 1,
                        color: AppColors.hairline,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                      ),
                      for (final filter in _HistoryFilter.values)
                        ChoiceChip(
                          label: Text(
                            switch (filter) {
                              _HistoryFilter.all => 'All',
                              _HistoryFilter.completed => 'Completed',
                              _HistoryFilter.unfinished => 'Unfinished',
                            },
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _filter == filter
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _filter == filter
                                  ? Colors.white
                                  : AppColors.ink,
                            ),
                          ),
                          selected: _filter == filter,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceAlt,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(
                            color: _filter == filter
                                ? AppColors.primary
                                : AppColors.hairline,
                          ),
                          onSelected: (_) =>
                              setState(() => _filter = filter),
                        ),
                      if (hasCustomFilters)
                        ActionChip(
                          avatar: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Reset',
                              style: TextStyle(fontSize: 12)),
                          backgroundColor: AppColors.surfaceAlt,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: AppColors.hairline),
                          onPressed: () => setState(() {
                            _days = 30;
                            _filter = _HistoryFilter.all;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!widget.available)
                    const Panel(
                        child: Text(
                            'Routine history is unavailable. Refresh to retry.'))
                  else if (widget.attempts.isEmpty)
                    const Panel(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fitness_center_outlined,
                              size: 44, color: AppColors.inkSoft),
                          SizedBox(height: 12),
                          Text(
                            'No workouts yet',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Start a workout from your home or routine hub to record your progress.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    )
                  else if (attempts.isEmpty)
                    Panel(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list_off_rounded,
                              size: 40, color: AppColors.inkSoft),
                          const SizedBox(height: 12),
                          const Text('No workouts match this filter.',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() {
                              _days = null;
                              _filter = _HistoryFilter.all;
                            }),
                            child: const Text('Show all workouts'),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4),
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      for (final a in entry.value)
                        _RoutineHistoryCard(
                          attempt: a,
                          asOf: now,
                          saveStatus: widget.saveStatusBuilder?.call(a),
                          onTap: () => widget.onOpenAttempt(a),
                        ),
                    ],
                ])));
  }
}

class _RoutineHistoryCard extends StatelessWidget {
  const _RoutineHistoryCard({
    required this.attempt,
    required this.asOf,
    required this.onTap,
    this.saveStatus,
  });

  final RoutineAttempt attempt;
  final DateTime asOf;
  final Widget? saveStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = attempt;
    final activity = routineActivitySummary(a);
    final timeStr = _friendlyTime(a.finishedAtMicros ?? a.updatedAtMicros);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title + Status Badge
              LayoutBuilder(builder: (context, constraints) {
                final badge = Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: a.isComplete
                        ? const Color(0xFFEAF7EF)
                        : const Color(0xFFFFF0DF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        a.isComplete
                            ? Icons.check_circle_rounded
                            : Icons.timelapse_rounded,
                        size: 13,
                        color: a.isComplete
                            ? const Color(0xFF237A4B)
                            : const Color(0xFF92400E),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          workoutAttemptLabel(a),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: a.isComplete
                                ? const Color(0xFF237A4B)
                                : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                final isLargeText =
                    MediaQuery.textScalerOf(context).scale(14) > 19;

                return isLargeText
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routineDayTitle(a.routine, a.day),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          badge,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              routineDayTitle(a.routine, a.day),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          badge,
                        ],
                      );
              }),
              const SizedBox(height: 8),
              // Exercises and mode summary
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 2,
                children: [
                  const Icon(
                    Icons.fitness_center_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  Text(
                    '${a.completedExercises}/${a.entries.length} exercises',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  if (activity.isNotEmpty) ...[
                    const Text(
                      '·',
                      style: TextStyle(
                          color: Color(0x99626778),
                          fontSize: 12),
                    ),
                    Text(
                      activity,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Footer: Time + Cloud Save Status + Chevron
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 13, color: AppColors.inkSoft),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  if (saveStatus != null) saveStatus!,
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutineAttemptDetailScreen extends StatelessWidget {
  const RoutineAttemptDetailScreen(
      {super.key,
      required this.attempt,
      this.trainingSource,
      this.saveStatus,
      this.onResume,
      this.onRepeat,
      this.onNextDay,
      this.availableSessionIds = const {},
      this.onOpenSession,
      this.summaries = const []});
  final RoutineAttempt attempt;
  final String? trainingSource;
  final Widget? saveStatus;
  final VoidCallback? onResume, onRepeat, onNextDay;
  final Set<String> availableSessionIds;
  final ValueChanged<String>? onOpenSession;
  final List<WorkoutSessionSummary> summaries;
  @override
  Widget build(BuildContext context) {
    final a = attempt;
    final action = !a.isComplete ? onResume : onNextDay ?? onRepeat;
    return Scaffold(
        appBar: AppBar(title: const Text('Workout summary')),
        bottomNavigationBar: action == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                        onPressed: action,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(!a.isComplete
                            ? 'Resume unfinished exercises'
                            : onNextDay != null
                                ? 'Next routine day'
                                : 'Repeat this workout')))),
        body: ListView(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              if (trainingSource != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(trainingSource!,
                        style: const TextStyle(color: AppColors.inkSoft))),
              RoutineCompletionContent(
                  attempt: a,
                  summaries: summaries,
                  saveStatus: saveStatus,
                  availableSessionIds: availableSessionIds,
                  onOpenSession: onOpenSession == null
                      ? null
                      : (id) {
                          if (availableSessionIds.contains(id)) {
                            onOpenSession!(id);
                          }
                        }),
              if (onRepeat != null && (!a.isComplete || onNextDay != null))
                OutlinedButton(
                    onPressed: onRepeat,
                    child: const Text('Repeat this workout')),
            ]));
  }
}
