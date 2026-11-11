import 'package:flutter/material.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

const List<String> kProgramWeekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> kProgramMonthNames = [
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
  'Dec',
];

String formatFriendlyDate(DateTime date) =>
    '${date.day} ${kProgramMonthNames[date.month - 1]} ${date.year}';

String formatPreviewDate(DateTime date) =>
    '${kProgramWeekdayNames[date.weekday - 1]}, ${date.day} ${kProgramMonthNames[date.month - 1]}';

String? validateProgramSchedule({
  required WorkoutProgram? program,
  required DateTime? startDate,
  required DateTime today,
  required Set<int> weekdays,
}) {
  if (program == null) return 'Please choose a program.';
  final requiredCount =
      program.days.where((d) => d.week == 1 && d.kind == 'workout').length;
  if (startDate == null) return 'Please select a valid start date.';
  if (startDate.isBefore(today)) {
    return 'Start date cannot be in the past.';
  }
  if (weekdays.length < requiredCount) {
    final remaining = requiredCount - weekdays.length;
    return 'Select $remaining more training ${remaining == 1 ? "day" : "days"} (${weekdays.length}/$requiredCount selected).';
  }
  if (weekdays.length > requiredCount) {
    final extra = weekdays.length - requiredCount;
    return 'Remove $extra training ${extra == 1 ? "day" : "days"} (${weekdays.length}/$requiredCount selected).';
  }
  try {
    ProgramSchedule.create(program, startDate, weekdays);
  } on FormatException catch (e) {
    return e.message;
  } catch (_) {
    return 'Invalid schedule configuration. Adjust your selected weekdays.';
  }
  return null;
}

class SchedulePreviewData {
  const SchedulePreviewData({
    required this.firstWorkout,
    required this.firstWeekDays,
    required this.fullSchedule,
  });
  final ScheduledProgramDay firstWorkout;
  final List<ScheduledProgramDay> firstWeekDays;
  final List<ScheduledProgramDay> fullSchedule;
}

SchedulePreviewData? computeSchedulePreview({
  required WorkoutProgram? program,
  required DateTime? startDate,
  required Set<int> weekdays,
}) {
  if (program == null || startDate == null) return null;
  final requiredCount =
      program.days.where((d) => d.week == 1 && d.kind == 'workout').length;
  if (weekdays.length != requiredCount) return null;
  try {
    final schedule = ProgramSchedule.create(program, startDate, weekdays);
    final workouts = schedule
        .where((d) => d.definition.kind == 'workout')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (workouts.isEmpty) return null;
    final firstWorkout = workouts.first;
    final week1Days = schedule
        .where((d) => d.definition.week == 1)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return SchedulePreviewData(
      firstWorkout: firstWorkout,
      firstWeekDays: week1Days,
      fullSchedule: schedule,
    );
  } catch (_) {
    return null;
  }
}

/// Reusable rounded white card container with GainPath design tokens.
class ProgramSectionCard extends StatelessWidget {
  const ProgramSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Card 1: Choose Your Program Card.
class ChooseProgramCard extends StatelessWidget {
  const ChooseProgramCard({
    super.key,
    required this.selectedProgram,
    required this.availablePrograms,
    required this.onSelectProgram,
    required this.disabled,
  });

  final WorkoutProgram selectedProgram;
  final List<WorkoutProgram> availablePrograms;
  final ValueChanged<WorkoutProgram> onSelectProgram;
  final bool disabled;

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose your program',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: availablePrograms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final p = availablePrograms[index];
                    final isSelected = p.id == selectedProgram.id;
                    return InkWell(
                      onTap: () {
                        onSelectProgram(p);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryTint
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.hairline,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.fitness_center_rounded,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 15,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${p.level} level · ${p.weeks} weeks',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProgramSectionCard(
      title: 'Choose your program',
      child: Semantics(
        button: true,
        label: 'Selected program: ${selectedProgram.title}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('program-selector'),
            onTap: disabled ? null : () => _openSheet(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedProgram.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${selectedProgram.level} level · ${selectedProgram.weeks} weeks',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (availablePrograms.length > 1) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.inkSoft,
                      size: 24,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card 2: Program Overview Card.
class ProgramOverviewCard extends StatelessWidget {
  const ProgramOverviewCard({
    super.key,
    required this.program,
  });

  final WorkoutProgram program;

  @override
  Widget build(BuildContext context) {
    final workoutDays = program.days
        .where((d) => d.week == 1 && d.kind == 'workout')
        .toList();
    final count = workoutDays.length;

    return ProgramSectionCard(
      title: 'Program overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip(
                icon: Icons.fitness_center_rounded,
                label: '$count workouts/week',
              ),
              _buildMetricChip(
                icon: Icons.calendar_today_rounded,
                label: '${program.weeks} weeks',
              ),
              _buildMetricChip(
                icon: Icons.shield_outlined,
                label: '${program.level} level',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Workout routines',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          for (final day in workoutDays) ...[
            _buildRoutineRow(day),
            if (day != workoutDays.last) const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.spa_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recovery days separate training sessions.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineRow(ProgramDay day) {
    final routineTitle =
        day.routineSnapshot?['title'] as String? ?? day.category;
    final estMinutes = day.routineSnapshot?['estimatedMinutes'] as int?;
    final subtitle =
        '${day.category}${estMinutes == null ? '' : ' · Estimated $estMinutes min'}';

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.fitness_center_outlined,
              color: AppColors.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  routineTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card 3: Schedule Setup Card.
class ScheduleSetupCard extends StatelessWidget {
  const ScheduleSetupCard({
    super.key,
    required this.program,
    required this.startDate,
    required this.weekdays,
    required this.onPickStartDate,
    required this.onToggleWeekday,
    required this.validationError,
    required this.disabled,
  });

  final WorkoutProgram program;
  final DateTime? startDate;
  final Set<int> weekdays;
  final VoidCallback onPickStartDate;
  final ValueChanged<int> onToggleWeekday;
  final String? validationError;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final count =
        program.days.where((d) => d.week == 1 && d.kind == 'workout').length;

    return ProgramSectionCard(
      title: 'Schedule setup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Start date row
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : onPickStartDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start date',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            startDate != null
                                ? 'Start date — ${formatFriendlyDate(startDate!)}'
                                : 'Select start date',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.inkSoft,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choose $count training days each week',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Recovery days separate training sessions.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          // 7 Weekday buttons
          Row(
            children: [
              for (var i = 1; i <= 7; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                _WeekdayButton(
                  weekday: i,
                  label: kProgramWeekdayNames[i - 1],
                  selected: weekdays.contains(i),
                  disabled: disabled,
                  onTap: () => onToggleWeekday(i),
                ),
              ],
            ],
          ),
          if (validationError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x4DDC2626)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      validationError!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekdayButton extends StatelessWidget {
  const _WeekdayButton({
    required this.weekday,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final int weekday;
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = disabled
        ? const Color(0xFFF1F0F5)
        : selected
            ? AppColors.primary
            : Colors.white;
    final border = disabled
        ? const BorderSide(color: Color(0xFFE5E3EB))
        : selected
            ? const BorderSide(color: AppColors.primaryDark, width: 1.5)
            : const BorderSide(color: AppColors.hairline);
    final textColor = disabled
        ? const Color(0xFF9E9AA8)
        : selected
            ? Colors.white
            : AppColors.ink;

    return Expanded(
      child: Semantics(
        button: true,
        enabled: !disabled,
        selected: selected,
        label: '$label, ${selected ? "selected" : "not selected"}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.fromBorderSide(border),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0x406D28D9),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    else
                      const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card 4: Schedule Preview Card.
class SchedulePreviewCard extends StatelessWidget {
  const SchedulePreviewCard({
    super.key,
    required this.previewData,
    required this.validationError,
  });

  final SchedulePreviewData? previewData;
  final String? validationError;

  @override
  Widget build(BuildContext context) {
    return ProgramSectionCard(
      title: 'Your schedule preview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (previewData != null) ...[
            Builder(builder: (context) {
              final firstWorkout = previewData!.firstWorkout;
              final dateStr = formatPreviewDate(firstWorkout.date);
              final routineTitle =
                  firstWorkout.definition.routineSnapshot?['title'] as String? ??
                      firstWorkout.definition.category;
              final estMinutes = firstWorkout
                  .definition.routineSnapshot?['estimatedMinutes'] as int?;
              final durationStr =
                  estMinutes != null ? ' · Estimated $estMinutes min' : '';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0x4D8B5CF6)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.play_circle_filled_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'First workout: $dateStr',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$routineTitle$durationStr',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
            const Text(
              'First week schedule',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  for (final d in previewData!.firstWeekDays)
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              kProgramWeekdayNames[d.date.weekday - 1],
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${d.date.day}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: d.definition.kind == 'workout'
                                    ? AppColors.primary
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: d.definition.kind == 'workout'
                                    ? null
                                    : Border.all(color: AppColors.hairline),
                              ),
                              child: Icon(
                                d.definition.kind == 'workout'
                                    ? Icons.fitness_center_rounded
                                    : Icons.spa_outlined,
                                size: 13,
                                color: d.definition.kind == 'workout'
                                    ? Colors.white
                                    : AppColors.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  Icon(
                    validationError != null
                        ? Icons.info_outline_rounded
                        : Icons.calendar_month_outlined,
                    color: AppColors.inkSoft,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      validationError ??
                          'Select your program and training days above to preview your schedule.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sticky Bottom Enrollment Action.
class ProgramEnrollmentStickyFooter extends StatelessWidget {
  const ProgramEnrollmentStickyFooter({
    super.key,
    required this.selectedCount,
    required this.requiredCount,
    required this.canSubmit,
    required this.acting,
    required this.onStartProgram,
  });

  final int selectedCount;
  final int requiredCount;
  final bool canSubmit;
  final bool acting;
  final VoidCallback onStartProgram;

  @override
  Widget build(BuildContext context) {
    final isCompleteCount = selectedCount == requiredCount;
    final dayCountText = isCompleteCount
        ? '$requiredCount training days selected'
        : '$selectedCount of $requiredCount training days selected';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.hairline)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isCompleteCount
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: isCompleteCount
                        ? AppColors.success
                        : AppColors.inkSoft,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dayCountText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isCompleteCount
                            ? AppColors.success
                            : AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.hairline,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: canSubmit && !acting ? onStartProgram : null,
                child: acting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start program',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Previous enrollments and workout history are kept.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
