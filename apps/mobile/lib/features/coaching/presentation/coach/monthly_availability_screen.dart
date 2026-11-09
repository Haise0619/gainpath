import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'availability_preview.dart';
import 'coach_roster_editor.dart';

const List<String> _monthNames = [
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

const List<String> _calendarWeekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun'
];

/// Dedicated Monthly Availability view for coaches.
/// Shows full month grid with Working, Off, Custom Hours and Time Off indicators.
class MonthlyAvailabilityScreen extends StatefulWidget {
  const MonthlyAvailabilityScreen({
    super.key,
    required this.repository,
    required this.coachId,
    required this.isCurrent,
    this.roster,
    this.branchNames = const {},
    this.initialDate,
    this.onManageDay,
    this.onDateSelected,
  });

  final CoachAvailabilityRepository repository;
  final String coachId;
  final bool Function() isCurrent;
  final CoachRosterEditor? roster;
  final Map<String, String> branchNames;
  final String? initialDate;
  final Future<void> Function(String date)? onManageDay;
  final void Function(String date)? onDateSelected;

  @override
  State<MonthlyAvailabilityScreen> createState() =>
      _MonthlyAvailabilityScreenState();
}

class _MonthlyAvailabilityScreenState extends State<MonthlyAvailabilityScreen> {
  late DateTime _displayedMonth;
  late String _selectedDate;
  late String _todayLocalDate;
  bool _loading = false;
  String? _errorMessage;
  CoachAvailabilityContext? _context;

  @override
  void initState() {
    super.initState();
    final rosterToday = widget.roster?.baseline?.todayLocalDate;
    if (rosterToday != null && rosterToday.isNotEmpty) {
      _todayLocalDate = rosterToday;
    } else {
      final now = DateTime.now();
      _todayLocalDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    _selectedDate = widget.initialDate ?? _todayLocalDate;
    final initialDt = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    _displayedMonth = DateTime(initialDt.year, initialDt.month, 1);
    _loadMonthData();
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _readableDate(String value) {
    final date = DateTime.tryParse(value) ?? DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
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
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadMonthData() async {
    if (!mounted || !widget.isCurrent()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1. Ensure roster baseline is loaded
      if (widget.roster != null && widget.roster!.baseline == null) {
        await widget.roster!.reload();
      }

      // 2. Query within valid scheduling horizon (dayCount between 1 and 7)
      final today = widget.roster?.baseline?.todayLocalDate ?? _todayLocalDate;
      final through = widget.roster?.baseline?.throughLocalDate;
      String? loadDate = _selectedDate;
      if (loadDate.compareTo(today) < 0) {
        loadDate = today;
      } else if (through != null && loadDate.compareTo(through) > 0) {
        loadDate = null;
      }

      if (loadDate != null) {
        final result = await widget.repository.load(
          coachId: widget.coachId,
          firstLocalDate: loadDate,
          dayCount: 7,
        );
        if (mounted && widget.isCurrent()) {
          _context = result;
          if (result.todayLocalDate.isNotEmpty) {
            _todayLocalDate = result.todayLocalDate;
          }
        }
      }
    } catch (_) {
      // If network load fails, we gracefully rely on widget.roster (weekly schedule & exceptions).
      // Only set error message if even baseline roster is unavailable.
      if (widget.roster?.baseline == null && _context == null) {
        _errorMessage = 'Could not load month schedule. Refresh or retry.';
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _selectDate(String dateStr) {
    setState(() => _selectedDate = dateStr);
    widget.onDateSelected?.call(dateStr);

    final today = widget.roster?.baseline?.todayLocalDate ?? _todayLocalDate;
    final through = widget.roster?.baseline?.throughLocalDate;
    if (dateStr.compareTo(today) >= 0 &&
        (through == null || dateStr.compareTo(through) <= 0)) {
      final alreadyLoaded =
          _context?.days.any((d) => d.localDate == dateStr) ?? false;
      if (!alreadyLoaded) {
        _loadWeekForDate(dateStr);
      }
    }
  }

  Future<void> _loadWeekForDate(String dateStr) async {
    try {
      final result = await widget.repository.load(
        coachId: widget.coachId,
        firstLocalDate: dateStr,
        dayCount: 7,
      );
      if (mounted && widget.isCurrent()) {
        setState(() {
          _context = result;
        });
      }
    } catch (_) {
      // Silently keep current weekly schedule
    }
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
    _loadMonthData();
  }

  void _jumpToToday() {
    final now = DateTime.tryParse(_todayLocalDate) ?? DateTime.now();
    setState(() {
      _displayedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = _todayLocalDate;
    });
    widget.onDateSelected?.call(_selectedDate);
    _loadMonthData();
  }

  List<CoachTimeException> _blocksForDate(String dateStr) {
    if (widget.roster == null) return const [];
    final target = DateTime.tryParse(dateStr);
    if (target == null) return const [];
    final startDay = DateTime.utc(target.year, target.month, target.day)
        .subtract(const Duration(hours: 8))
        .millisecondsSinceEpoch;
    final endDay = startDay + 86400000;
    return widget.roster!.exceptions
        .where((e) => e.startAtMillis < endDay && e.endAtMillis > startDay)
        .toList();
  }

  bool _isDateCustom(String dateStr) {
    final dayObj =
        _context?.days.where((d) => d.localDate == dateStr).firstOrNull;
    return (dayObj?.revision ?? 0) > 0;
  }

  bool _isDateWorking(String dateStr) {
    final dayObj =
        _context?.days.where((d) => d.localDate == dateStr).firstOrNull;
    if (dayObj != null) {
      final base = previewScheduledWindows(
        day: dayObj,
        weeklyDay: widget.roster?.dayFor(DateTime.parse(dateStr).weekday),
        weeklyChanged: widget.roster?.dirty == true,
      );
      if (base.isEmpty) return false;
      final exceptions = _blocksForDate(dateStr);
      final masked = maskWindowsWithExceptions(base, exceptions);
      return masked.isNotEmpty;
    }
    // Fallback based on weekly schedule
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return false;
    final weeklyDay = widget.roster?.dayFor(dt.weekday);
    if (weeklyDay == null || !weeklyDay.isActive) return false;
    final exceptions = _blocksForDate(dateStr);
    if (exceptions.any((e) =>
        e.type == 'offDay' ||
        (e.endAtMillis - e.startAtMillis >= 23.5 * 3600000))) {
      return false;
    }
    return true;
  }

  List<DatedCoachWindow> _windowsForDate(String dateStr) {
    final dayObj =
        _context?.days.where((d) => d.localDate == dateStr).firstOrNull;
    if (dayObj != null) {
      final base = previewScheduledWindows(
        day: dayObj,
        weeklyDay: widget.roster?.dayFor(DateTime.parse(dateStr).weekday),
        weeklyChanged: widget.roster?.dirty == true,
      );
      final exceptions = _blocksForDate(dateStr);
      return maskWindowsWithExceptions(base, exceptions);
    }
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return const [];
    final weeklyDay = widget.roster?.dayFor(dt.weekday);
    if (weeklyDay == null || !weeklyDay.isActive) return const [];
    final midnight = DateTime.utc(dt.year, dt.month, dt.day)
        .subtract(const Duration(hours: 8))
        .millisecondsSinceEpoch;
    return [
      DatedCoachWindow(
        branchId: weeklyDay.branchId,
        startAtMillis: midnight + weeklyDay.startMinute * 60000,
        endAtMillis: midnight + weeklyDay.endMinute * 60000,
      )
    ];
  }

  String _branchLabel(String id) => widget.branchNames[id] ?? id;

  Widget _sourceBadge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final firstOfMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final firstWeekday = firstOfMonth.weekday; // 1 = Mon
    final gridStart = firstOfMonth.subtract(Duration(days: firstWeekday - 1));

    final selectedWindows = _windowsForDate(_selectedDate);
    final selectedBlocks = _blocksForDate(_selectedDate);
    final selectedIsCustom = _isDateCustom(_selectedDate);
    final selectedIsWorking = _isDateWorking(_selectedDate);
    final isDirty = widget.roster?.dirty == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Schedule'),
        actions: [
          TextButton.icon(
            key: const ValueKey('jump-to-today-btn'),
            onPressed: _jumpToToday,
            icon: const Icon(Icons.today_rounded, size: 16),
            label: const Text('Today'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMonthData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Month navigation header
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('prev-month-btn'),
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _loading ? null : _previousMonth,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('next-month-btn'),
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _loading ? null : _nextMonth,
                  ),
                ],
              ),
            ),

            if (_loading) const LinearProgressIndicator(),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  background: AppColors.warning.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Expanded(child: Text(_errorMessage!)),
                      TextButton(
                        onPressed: _loadMonthData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),

            // Weekday Header
            Row(
              children: [
                for (final weekday in _calendarWeekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekday,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // 6-week Calendar Grid
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                children: [
                  for (var row = 0; row < 6; row++) ...[
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++) ...[
                          Builder(builder: (context) {
                            final cellDate = gridStart
                                .add(Duration(days: row * 7 + col));
                            final dateStr = _formatDate(cellDate);
                            final isCurrentMonth =
                                cellDate.month == _displayedMonth.month;
                            final isSelected = dateStr == _selectedDate;
                            final isToday = dateStr == _todayLocalDate;

                            final hasTimeOff =
                                _blocksForDate(dateStr).isNotEmpty;
                            final isCustom = _isDateCustom(dateStr);
                            final isWorking = _isDateWorking(dateStr);

                            Color dotColor;
                            if (hasTimeOff) {
                              dotColor = AppColors.warning;
                            } else if (isCustom) {
                              dotColor = AppColors.primary;
                            } else if (isWorking) {
                              dotColor = AppColors.success;
                            } else {
                              dotColor =
                                  AppColors.inkSoft.withValues(alpha: 0.35);
                            }

                            return Expanded(
                              child: InkWell(
                                key: ValueKey('calendar-cell-$dateStr'),
                                onTap: () => _selectDate(dateStr),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isToday
                                            ? AppColors.primaryTint
                                                .withValues(alpha: 0.5)
                                            : Colors.transparent),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isToday && !isSelected
                                        ? Border.all(
                                            color: AppColors.primary, width: 1.2)
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${cellDate.day}',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isSelected || isToday
                                              ? FontWeight.w700
                                              : (isWorking
                                                  ? FontWeight.w600
                                                  : FontWeight.w400),
                                          color: isSelected
                                              ? Colors.white
                                              : (isCurrentMonth
                                                  ? (isWorking
                                                      ? AppColors.ink
                                                      : AppColors.inkSoft)
                                                  : AppColors.inkSoft
                                                      .withValues(alpha: 0.35)),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white
                                              : dotColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                    if (row < 5) const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _legendItem(AppColors.success, 'Working'),
                  _legendItem(
                      AppColors.inkSoft.withValues(alpha: 0.4), 'Off'),
                  _legendItem(AppColors.primary, 'Custom Hours'),
                  _legendItem(AppColors.warning, 'Time Off'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selected Day Details Card
            Panel(
              key: const ValueKey('monthly-selected-day-panel'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _readableDate(_selectedDate),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _sourceBadge(selectedIsCustom
                          ? 'Custom hours'
                          : 'Weekly template'),
                      if (isDirty) _sourceBadge('Unsaved preview'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: selectedIsWorking
                              ? AppColors.successTint
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          selectedIsWorking ? 'Working' : 'Off',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selectedIsWorking
                                ? AppColors.success
                                : AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.schedule_rounded,
                            size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedWindows.isEmpty
                                  ? 'No working hours scheduled'
                                  : selectedWindows
                                      .map((w) =>
                                          '${_formatMillisTime(w.startAtMillis)} – ${_formatMillisTime(w.endAtMillis)}')
                                      .join('\n'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                height: 1.35,
                                color: AppColors.ink,
                              ),
                            ),
                            for (final branch in selectedWindows
                                .map((w) => w.branchId)
                                .toSet())
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 13, color: AppColors.inkSoft),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _branchLabel(branch),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.inkSoft,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (selectedBlocks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Breaks & time off',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                    ),
                    const SizedBox(height: 4),
                    for (final block in selectedBlocks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.event_busy_outlined,
                                size: 13, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${block.type == "breakTime" ? "Break" : "Leave"} · ${_formatMillisTime(block.startAtMillis)} – ${_formatMillisTime(block.endAtMillis)}',
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Working hours define duty schedule, not remaining bookable slots.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkSoft,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Manage This Day Primary Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('monthly-manage-day-btn'),
                      onPressed: () =>
                          widget.onManageDay?.call(_selectedDate),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text(
                        'Manage This Day',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // View in Weekly Schedule
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('view-in-weekly-btn'),
                      onPressed: () {
                        widget.onDateSelected?.call(_selectedDate);
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.view_week_rounded, size: 16),
                      label: const Text(
                        'View in Weekly Schedule',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
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
  }

  Widget _legendItem(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      );

  String _formatMillisTime(int millis) {
    // Format UTC+8
    final dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        .add(const Duration(hours: 8));
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
