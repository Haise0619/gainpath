import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_availability_cubit.dart';
import 'availability_page.dart';
import 'coach_roster_editor.dart';
import 'coach_time_exception_sheet.dart';
import 'coach_specific_date_sheet.dart';
import 'mock_availability_repository_adapter.dart';

String rosterMinute(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

String rosterExceptionType(String type) => switch (type) {
      'breakTime' => 'Break',
      'offDay' => 'Off-day',
      _ => 'Leave'
    };

Color _blockColor(String type) => switch (type) {
      'breakTime' => AppColors.info,
      'offDay' => AppColors.warning,
      _ => AppColors.danger,
    };

IconData _blockIcon(String type) => switch (type) {
      'breakTime' => Icons.coffee_outlined,
      'offDay' => Icons.event_busy_outlined,
      _ => Icons.flight_takeoff_outlined,
    };

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Canonical unified Coach Availability screen for mobile.
/// Feeds both real Firebase and mock/test adapters through the same production widgets.
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen(
      {super.key, this.liveRepository, this.coachId, this.isCurrent});

  final CoachAvailabilityRepository? liveRepository;
  final String? coachId;
  final bool Function()? isCurrent;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  CoachRosterEditor? roster;
  CoachAvailabilityCubit? availabilityCubit;
  CoachAvailabilityRepository? _effectiveRepo;
  late String _effectiveCoachId;
  late bool Function() _effectiveIsCurrent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (roster != null) return;

    final repo = widget.liveRepository;
    if (repo != null) {
      _effectiveRepo = repo;
      _effectiveCoachId = widget.coachId ?? 'coach';
      _effectiveIsCurrent = widget.isCurrent ?? () => true;
    } else {
      final legacy = context.read<AvailabilityRepository>();
      final adapter = MockAvailabilityRepositoryAdapter(legacy);
      _effectiveRepo = adapter;
      _effectiveCoachId = widget.coachId ?? 'coach';
      _effectiveIsCurrent = widget.isCurrent ?? () => true;
    }

    if (_effectiveRepo is CoachRosterRepository) {
      roster = CoachRosterEditor(
        repository: _effectiveRepo as CoachRosterRepository,
        coachId: _effectiveCoachId,
        isCurrent: _effectiveIsCurrent,
        onSaved: () {
          availabilityCubit?.discardAndReload();
          if (mounted) setState(() {});
        },
      )
        ..addListener(_onRosterChanged)
        ..reload();
    }

    availabilityCubit = CoachAvailabilityCubit(
      repository: _effectiveRepo!,
      coachId: _effectiveCoachId,
      isCurrent: _effectiveIsCurrent,
    )..loadWeek();
  }

  void _onRosterChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    roster?.removeListener(_onRosterChanged);
    roster?.dispose();
    availabilityCubit?.close();
    super.dispose();
  }

  bool get enabled =>
      (roster == null ||
          (roster!.enabled && !roster!.busy && !roster!.conflict)) &&
      _effectiveIsCurrent();

  Future<void> _reload() async {
    if (roster?.dirty == true) {
      final discard = await confirmSheet(
        context,
        title: 'Discard unsaved changes?',
        message: 'Your schedule changes have not been saved.',
        confirmLabel: 'Discard changes',
      );
      if (!discard || !mounted) return;
    }
    roster?.reload(discard: true);
    availabilityCubit?.discardAndReload();
  }

  Future<void> _editDayHours(int dayOfWeek) async {
    if (!enabled || roster?.baseline == null) return;
    final baseline = roster!.baseline!;
    final old = roster!.dayFor(dayOfWeek);
    var active = old?.isActive ?? false;
    var start = old?.startMinute ?? 540;
    var end = old?.endMinute ?? 1020;
    var branch = old?.branchId ??
        (baseline.assignedBranchIds.isNotEmpty
            ? baseline.assignedBranchIds.first
            : 'main');
    var dirty = false;

    final result = await showModalBottomSheet<CoachWeeklyDay>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, update) => PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final discard = await confirmSheet(
              sheetContext,
              title: 'Discard unsaved changes?',
              message: 'Your working hours have not been applied.',
              confirmLabel: 'Discard changes',
            );
            if (discard && sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekdayNames[dayOfWeek - 1],
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Working day'),
                    value: active,
                    onChanged: (v) => update(() {
                      active = v;
                      dirty = true;
                    }),
                  ),
                  if (baseline.assignedBranchIds.length > 1)
                    DropdownButtonFormField<String>(
                      initialValue: branch,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      items: baseline.assignedBranchIds
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => update(() {
                        branch = v!;
                        dirty = true;
                      }),
                    ),
                  DropdownButtonFormField<int>(
                    initialValue: start,
                    decoration: const InputDecoration(labelText: 'Start time'),
                    items: List.generate(
                      48,
                      (i) => DropdownMenuItem(
                        value: i * 30,
                        child: Text(rosterMinute(i * 30)),
                      ),
                    ),
                    onChanged: !active
                        ? null
                        : (v) => update(() {
                              start = v!;
                              if (end <= start) end = start + 30;
                              dirty = true;
                            }),
                  ),
                  DropdownButtonFormField<int>(
                    key: ValueKey((start, end)),
                    initialValue: end,
                    decoration: const InputDecoration(labelText: 'End time'),
                    items: [
                      for (var minute = start + 30; minute <= 1440; minute += 30)
                        DropdownMenuItem(
                          value: minute,
                          child: Text(rosterMinute(minute)),
                        ),
                    ],
                    onChanged: !active
                        ? null
                        : (v) => update(() {
                              end = v!;
                              dirty = true;
                            }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          if (!dirty ||
                              await confirmSheet(
                                sheetContext,
                                title: 'Discard unsaved changes?',
                                message:
                                    'Your working hours have not been applied.',
                                confirmLabel: 'Discard changes',
                              )) {
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          }
                        },
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          CoachWeeklyDay(
                            dayOfWeek: dayOfWeek,
                            isActive: active,
                            startMinute: start,
                            endMinute: end,
                            branchId: branch,
                          ),
                        ),
                        child: const Text('Apply day'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result != null && mounted && enabled) {
      roster!.day(result);
    }
  }

  Future<void> _addException() async {
    if (!enabled || roster?.baseline == null) {
      if (roster?.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(roster!.message!),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => roster!.reload(discard: true),
            ),
          ),
        );
      }
      return;
    }
    final result = await showModalBottomSheet<CoachTimeException>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CoachTimeExceptionSheet(
        repository: _effectiveRepo!,
        roster: roster!.baseline!,
        isCurrent: _effectiveIsCurrent,
      ),
    );
    if (result != null && mounted && enabled) {
      roster!.exception(result);
    }
  }

  Future<void> _editException(CoachTimeException exception) async {
    if (!enabled || roster?.baseline == null) return;
    final result = await showModalBottomSheet<CoachTimeException>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CoachTimeExceptionSheet(
        repository: _effectiveRepo!,
        roster: roster!.baseline!,
        isCurrent: _effectiveIsCurrent,
        initial: exception,
      ),
    );
    if (result != null && mounted && enabled) {
      roster!.exception(result);
    }
  }

  Future<void> _removeException(CoachTimeException exception) async {
    if (!enabled) return;
    final ok = await confirmSheet(
      context,
      title: 'Remove this block?',
      message: 'That time reopens for members to book.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (ok && mounted && enabled) {
      roster!.remove(exception.id);
    }
  }

  bool get canSave =>
      roster != null &&
      !roster!.busy &&
      !roster!.conflict &&
      _effectiveIsCurrent() &&
      (roster!.dirty || roster!.uncertain);

  Future<void> _openSpecificDateSheet({String? date}) async {
    if (_effectiveRepo == null) return;
    if (roster?.dirty == true) {
      final proceed = await confirmSheet(
        context,
        title: 'Unsaved weekly changes',
        message:
            'You have unsaved changes to your weekly schedule. Discard them or save before editing specific dates?',
        confirmLabel: 'Discard & proceed',
      );
      if (!proceed || !mounted) return;
      await roster?.reload(discard: true);
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => CoachSpecificDateSheet(
        repository: _effectiveRepo!,
        coachId: _effectiveCoachId,
        isCurrent: _effectiveIsCurrent,
        initialDate: date,
        onSaved: () {
          roster?.reload();
          availabilityCubit?.discardAndReload();
        },
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!canSave) return;
    await roster!.save();
    if (!mounted) return;
    if (roster?.dirty == false && roster?.message != null) {
      showToast(context, 'Availability changes saved.');
      await availabilityCubit?.discardAndReload();
    } else if (roster?.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(roster!.message!),
          backgroundColor: roster?.uncertain == true
              ? AppColors.warning
              : AppColors.danger,
          action: roster?.uncertain == true
              ? SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: _saveChanges,
                )
              : null,
        ),
      );
    }
  }

  String _formatExceptionTime(CoachTimeException exception) {
    if (exception.startLabel != null && exception.endLabel != null) {
      return '${exception.startLabel} – ${exception.endLabel}';
    }
    final dt = _toKualaLumpur(exception.startAtMillis);
    return '${_weekdayNames[dt.weekday - 1].substring(0, 3)}, ${dt.day} · ${rosterMinute(dt.hour * 60 + dt.minute)}';
  }

  static DateTime _toKualaLumpur(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
          .add(const Duration(hours: 8));

  static String _formatKualaLumpurTime(int millis) {
    final dt = _toKualaLumpur(millis);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static List<DatedCoachWindow> maskWindowsWithExceptions(
      List<DatedCoachWindow> windows, List<CoachTimeException> exceptions) {
    final result = <DatedCoachWindow>[];
    for (final window in windows) {
      var pieces = [window];
      for (final e in exceptions) {
        pieces = pieces.expand((w) {
          if (e.endAtMillis <= w.startAtMillis ||
              e.startAtMillis >= w.endAtMillis) {
            return [w];
          }
          return [
            if (e.startAtMillis > w.startAtMillis)
              DatedCoachWindow(
                branchId: w.branchId,
                startAtMillis: w.startAtMillis,
                endAtMillis: e.startAtMillis,
              ),
            if (e.endAtMillis < w.endAtMillis)
              DatedCoachWindow(
                branchId: w.branchId,
                startAtMillis: e.endAtMillis,
                endAtMillis: w.endAtMillis,
              ),
          ];
        }).toList();
      }
      result.addAll(pieces);
    }
    return result;
  }

  List<CoachTimeException> _blocksForDate(CoachAvailabilityDay day) {
    if (day.boundaries.isEmpty) {
      final dateStart =
          DateTime.parse('${day.localDate}T00:00:00+08:00').millisecondsSinceEpoch;
      final dateEnd = dateStart + 86400000;
      return roster?.exceptions
              .where((block) =>
                  block.startAtMillis < dateEnd &&
                  block.endAtMillis > dateStart)
              .toList() ??
          const [];
    }
    return roster?.exceptions
            .where((block) =>
                block.startAtMillis < day.boundaries.last.atMillis &&
                block.endAtMillis > day.boundaries.first.atMillis)
            .toList() ??
        const [];
  }

  String _formatBlockInterval(
      CoachAvailabilityDay day, CoachTimeException block) {
    final start =
        day.boundaries.isNotEmpty && block.startAtMillis < day.boundaries.first.atMillis
            ? day.boundaries.first.atMillis
            : block.startAtMillis;
    final end =
        day.boundaries.isNotEmpty && block.endAtMillis > day.boundaries.last.atMillis
            ? day.boundaries.last.atMillis
            : block.endAtMillis;

    final startDt = _toKualaLumpur(start);
    final endDt = _toKualaLumpur(end);
    if (end - start >= 86400000 ||
        (startDt.hour == 0 &&
            startDt.minute == 0 &&
            endDt.hour == 0 &&
            endDt.minute == 0 &&
            end > start)) {
      return 'Full day';
    }

    final startLabel = day.labelFor(start);
    final endLabel = day.labelFor(end);
    if (startLabel != endLabel) {
      return '$startLabel – $endLabel';
    }

    final durationHours = (end - start) / 3600000;
    if (durationHours >= 23.5) {
      return 'Full day';
    }
    return '${_formatKualaLumpurTime(start)} – ${_formatKualaLumpurTime(end)} GMT+8';
  }

  List<DatedCoachWindow> _effectiveWindowsForDate(
      CoachAvailabilityDay day, CoachAvailabilityState cubitState) {
    final base = (cubitState.day?.localDate == day.localDate
        ? cubitState.windows
        : day.windows);
    if (base.isEmpty) return const [];
    final exceptions = _blocksForDate(day);
    return maskWindowsWithExceptions(base, exceptions);
  }

  String _formatDayDuration(
      CoachAvailabilityDay day, CoachAvailabilityState cubitState) {
    final effective = _effectiveWindowsForDate(day, cubitState);
    if (effective.isEmpty) return 'Off';
    final minutes = effective.fold<int>(
        0, (sum, w) => sum + (w.endAtMillis - w.startAtMillis) ~/ 60000);
    if (minutes == 0) return 'Off';
    final hours = minutes / 60;
    return '${hours % 1 == 0 ? hours.toInt() : hours.toStringAsFixed(1)}h';
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  Widget _weekAtGlance(CoachAvailabilityState cubitState) {
    final data = cubitState.context;
    final selected = cubitState.day;

    if (data != null && selected != null) {
      final selectedBlocks = _blocksForDate(selected);
      final selectedEffective =
          _effectiveWindowsForDate(selected, cubitState);
      final selectedMinutes = selectedEffective.fold<int>(
          0, (sum, w) => sum + (w.endAtMillis - w.startAtMillis) ~/ 60000);
      final selectedHours = selectedMinutes / 60;
      final selectedDt = DateTime.parse(selected.localDate);
      final weekday = selectedDt.weekday;
      final weeklyDay = roster?.dayFor(weekday);
      final weeklyHoursStr = weeklyDay != null && weeklyDay.isActive
          ? '${rosterMinute(weeklyDay.startMinute)} – ${rosterMinute(weeklyDay.endMinute)}'
          : 'Off';

      final selectedScheduledMinutes =
          (cubitState.day?.localDate == selected.localDate
                  ? cubitState.windows
                  : selected.windows)
              .fold<int>(0,
                  (sum, w) => sum + (w.endAtMillis - w.startAtMillis) ~/ 60000);
      final selectedScheduledHours = selectedScheduledMinutes / 60;
      final selectedScheduledHoursStr = selectedScheduledMinutes == 0
          ? 'Off'
          : '${selectedScheduledHours % 1 == 0 ? selectedScheduledHours.toInt() : selectedScheduledHours.toStringAsFixed(1)}h';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final date in data.days)
                Expanded(
                  child: GestureDetector(
                    onTap: () => availabilityCubit?.openDay(date.localDate),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected.localDate == date.localDate
                            ? AppColors.primaryTint
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected.localDate == date.localDate
                              ? AppColors.primary
                              : AppColors.hairline,
                          width: selected.localDate == date.localDate ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _weekdayInitials[DateTime.parse(date.localDate).weekday - 1],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected.localDate == date.localDate
                                  ? AppColors.primary
                                  : AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateTime.parse(date.localDate).day.toString(),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDayDuration(date, cubitState),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _formatDayDuration(date, cubitState) == 'Off'
                                  ? AppColors.inkSoft
                                  : AppColors.ink,
                            ),
                          ),
                          if (_blocksForDate(date).isNotEmpty)
                            Tooltip(
                              message:
                                  '${_blocksForDate(date).length} blocked ${_blocksForDate(date).length == 1 ? 'period' : 'periods'}',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.block,
                                      size: 11, color: AppColors.danger),
                                  Text(
                                    '${_blocksForDate(date).length}',
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.danger),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_weekdayNames[weekday - 1]}, ${selectedDt.day} ${_monthNames[selectedDt.month - 1]}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: selectedMinutes > 0
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.hairline,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            selectedMinutes > 0
                                ? '${selectedHours % 1 == 0 ? selectedHours.toInt() : selectedHours.toStringAsFixed(1)}h bookable'
                                : 'Off',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selectedMinutes > 0
                                  ? AppColors.success
                                  : AppColors.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          key: const ValueKey('edit-selected-date-btn'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: enabled
                              ? () => _openSpecificDateSheet(
                                  date: selected.localDate)
                              : null,
                          child: const Text('Edit date',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('Scheduled: ',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.inkSoft)),
                    Text(
                      selectedScheduledHoursStr,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 10),
                    const Text('•  Bookable: ',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.inkSoft)),
                    Text(
                      selectedMinutes == 0
                          ? 'Off'
                          : '${selectedHours % 1 == 0 ? selectedHours.toInt() : selectedHours.toStringAsFixed(1)}h',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: selectedMinutes == 0
                            ? AppColors.inkSoft
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (selectedEffective.isNotEmpty) ...[
                  Text(
                    'Effective bookable windows:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 2),
                  for (final w in selectedEffective)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        '• ${_formatKualaLumpurTime(w.startAtMillis)} – ${_formatKualaLumpurTime(w.endAtMillis)} · ${w.branchId}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ] else ...[
                  const Text(
                    'No bookable hours for this date.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                  ),
                ],
                const SizedBox(height: 6),
                if (selectedBlocks.isNotEmpty) ...[
                  const Divider(height: 14),
                  Text(
                    'Blocked periods on ${selected.localDate}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  for (final block in selectedBlocks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Icon(_blockIcon(block.type),
                              size: 14, color: _blockColor(block.type)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  _formatBlockInterval(selected, block),
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                                if (block.reason.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${block.reason})',
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.inkSoft),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const Divider(height: 14),
                Text(
                  selectedBlocks.isNotEmpty
                      ? 'Note: Weekly schedule ($weeklyHoursStr) adjusted by ${selectedBlocks.length} blocked period(s).'
                      : (selected.windows.length !=
                              (weeklyDay?.isActive == true ? 1 : 0)
                          ? 'Note: Specific date override replaces weekly baseline ($weeklyHoursStr).'
                          : 'Note: Matches recurring weekly schedule ($weeklyHoursStr).'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final schedule = roster?.schedule ?? [];
    return Row(
      children: List.generate(7, (i) {
        final dayOfWeek = i + 1;
        final day = schedule.where((d) => d.dayOfWeek == dayOfWeek).firstOrNull;
        final active = day?.isActive ?? false;
        final durationMinutes =
            day != null && active ? (day.endMinute - day.startMinute) : 0;
        final hours = (durationMinutes / 60)
            .toStringAsFixed(durationMinutes % 60 == 0 ? 0 : 1);

        return Expanded(
          child: GestureDetector(
            onTap: () => _editDayHours(dayOfWeek),
            child: Container(
              margin: EdgeInsets.only(right: i == 6 ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  Text(
                    _weekdayInitials[i],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? AppColors.success : AppColors.hairline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    day == null ? '-' : active ? '${hours}h' : 'Off',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.ink : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _recurringHours() {
    if (roster?.loading == true && roster?.baseline == null) {
      return const Panel(child: Text('-'));
    }
    if (roster?.baseline == null && roster?.message != null) {
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    roster!.message!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => roster!.reload(discard: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry loading roster'),
            ),
          ],
        ),
      );
    }
    if (roster?.baseline == null) {
      return const Panel(child: Text('-'));
    }

    final days = List.generate(7, (i) => i + 1);
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(days.length, (i) {
          final number = days[i];
          final day = roster!.dayFor(number);
          final active = day?.isActive ?? false;

          return Column(
            children: [
              if (i > 0)
                const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                title: Text(
                  _weekdayNames[number - 1],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  day == null
                      ? '-'
                      : active
                          ? '${rosterMinute(day.startMinute)} – ${rosterMinute(day.endMinute)} · ${day.branchId}'
                          : 'Off',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: active,
                      onChanged: enabled
                          ? (v) => roster!.toggleDay(number, v)
                          : null,
                    ),
                    IconButton(
                      key: ValueKey('weekly-day-$number'),
                      tooltip: 'Edit ${_weekdayNames[number - 1]}',
                      onPressed: enabled ? () => _editDayHours(number) : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  List<Widget> _timeOffSection() {
    if (roster?.baseline == null && roster?.message != null) {
      return [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.danger, size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Time off and breaks could not be loaded.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => roster!.reload(discard: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry loading roster'),
              ),
            ],
          ),
        ),
      ];
    }
    if (roster?.baseline == null) {
      return const [Panel(child: Text('-'))];
    }
    if (roster!.exceptions.isEmpty) {
      return [
        Panel(
          child: Text(
            'No time off or breaks scheduled.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ];
    }

    return roster!.exceptions.map((b) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _blockColor(b.type).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_blockIcon(b.type),
                    size: 19, color: _blockColor(b.type)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.reason.isNotEmpty
                          ? b.reason
                          : rosterExceptionType(b.type),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rosterExceptionType(b.type)}  ·  ${_formatExceptionTime(b)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('edit-exception-${b.id}'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit blocked time',
                onPressed: enabled ? () => _editException(b) : null,
              ),
              IconButton(
                key: ValueKey('remove-exception-${b.id}'),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                tooltip: 'Remove blocked time',
                onPressed: enabled ? () => _removeException(b) : null,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _limitsSection() {
    if (roster?.baseline == null && roster?.message != null) {
      return Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.danger, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Scheduling limits could not be loaded.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => roster!.reload(discard: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry loading roster'),
            ),
          ],
        ),
      );
    }
    if (roster?.baseline == null) {
      return const Panel(
        child: Column(
          children: [
            DetailRow('Maximum booking hours per day', '-'),
            Divider(height: 20),
            DetailRow('How far ahead members can book', '-'),
          ],
        ),
      );
    }

    final daily = roster!.dailyHours;
    final advance = roster!.advanceDays;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Maximum booking hours per day',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                daily == null ? '-' : '${daily}h',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            value: (daily ?? 8).clamp(1, 24).toDouble(),
            min: 1,
            max: 24,
            divisions: 23,
            label: '${daily ?? 8} hours',
            onChanged: enabled ? (v) => roster!.limits(hours: v.round()) : null,
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'How far ahead members can book',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                advance == null ? '-' : '${advance}d',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            value: (advance ?? 14).clamp(1, 30).toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '${advance ?? 14} days',
            onChanged: enabled ? (v) => roster!.limits(days: v.round()) : null,
          ),
        ],
      ),
    );
  }

  List<Widget> _footerSection() {
    return [
      const Eyebrow('Dated overrides'),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Specific date overrides',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextButton.icon(
                  key: const ValueKey('open-specific-date-btn'),
                  onPressed: enabled ? () => _openSpecificDateSheet() : null,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('Edit specific date'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Organization time: ${roster?.baseline?.timeZone ?? availabilityCubit?.state.context?.timeZone ?? 'Asia/Kuala_Lumpur'} · Advanced overrides replace recurring weekly hours for a specific date.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (roster?.message != null && roster!.message!.isNotEmpty) ...[
        Panel(
          background: roster!.conflict
              ? AppColors.danger.withValues(alpha: 0.1)
              : roster!.uncertain
                  ? AppColors.warning.withValues(alpha: 0.1)
                  : (roster!.message!.contains('saved')
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.08)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                roster!.conflict
                    ? Icons.error_outline_rounded
                    : roster!.uncertain
                        ? Icons.warning_amber_rounded
                        : (roster!.message!.contains('saved')
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded),
                color: roster!.conflict
                    ? AppColors.danger
                    : roster!.uncertain
                        ? AppColors.warning
                        : (roster!.message!.contains('saved')
                            ? AppColors.success
                            : AppColors.primary),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roster!.message!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: roster!.conflict
                            ? AppColors.danger
                            : roster!.uncertain
                                ? AppColors.ink
                                : (roster!.message!.contains('saved')
                                    ? AppColors.success
                                    : AppColors.ink),
                      ),
                    ),
                    if (roster!.conflict) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Discard and reload'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('save-roster'),
          onPressed: canSave ? _saveChanges : null,
          child: roster?.saving == true
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Saving changes…'),
                  ],
                )
              : Text(
                  roster?.uncertain == true
                      ? 'Retry save'
                      : 'Save changes',
                ),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          roster?.saving == true
              ? 'Saving changes to Firebase…'
              : roster?.uncertain == true
                  ? 'Save could not be confirmed. Tap Retry save.'
                  : (roster?.dirty == true
                      ? 'You have unsaved changes'
                      : 'No unsaved changes'),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight:
                roster?.dirty == true ? FontWeight.w600 : FontWeight.w500,
            color: roster?.dirty == true
                ? AppColors.primary
                : AppColors.inkSoft,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final busy = roster?.busy == true;
    final dirty = roster?.dirty == true;

    return BlocBuilder<CoachAvailabilityCubit, CoachAvailabilityState>(
      bloc: availabilityCubit,
      builder: (context, cubitState) {
        return UnsavedChangesGuard(
          dirty: dirty,
          busy: busy,
          child: AvailabilityPage(
            workingHoursTitle:
                roster == null ? 'Dated overrides' : 'Recurring working hours',
            limitsTitle: 'Booking limits',
            actions: [
              IconButton(
                tooltip: 'Discard and reload',
                onPressed: busy ? null : _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
            header: [
              if (busy || cubitState.loading || cubitState.saving)
                const LinearProgressIndicator(),
            ],
            weekAtGlance: _weekAtGlance(cubitState),
            workingHours: [
              _recurringHours(),
            ],
            onAddTimeOff: enabled ? _addException : null,
            timeOff: _timeOffSection(),
            limits: [
              _limitsSection(),
            ],
            footer: _footerSection(),
          ),
        );
      },
    );
  }
}
