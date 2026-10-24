import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_availability_cubit.dart';
import 'availability_page.dart';
import 'availability_preview.dart';
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
      {super.key, this.liveRepository, this.coachId, this.isCurrent, this.googleIntegration});

  final CoachAvailabilityRepository? liveRepository;
  final GoogleIntegrationRepository? googleIntegration;
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
                          .map(
                              (b) => DropdownMenuItem(value: b, child: Text(b)))
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
                      for (var minute = start + 30;
                          minute <= 1440;
                          minute += 30)
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
        initialContext: availabilityCubit?.state.context,
        onSaved: () {
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
          backgroundColor:
              roster?.uncertain == true ? AppColors.warning : AppColors.danger,
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
      final dateStart = DateTime.parse('${day.localDate}T00:00:00+08:00')
          .millisecondsSinceEpoch;
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
    final start = day.boundaries.isNotEmpty &&
            block.startAtMillis < day.boundaries.first.atMillis
        ? day.boundaries.first.atMillis
        : block.startAtMillis;
    final end = day.boundaries.isNotEmpty &&
            block.endAtMillis > day.boundaries.last.atMillis
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
    final base = previewScheduledWindows(
        day: day,
        weeklyDay: roster?.dayFor(DateTime.parse(day.localDate).weekday),
        weeklyChanged: roster != null &&
            jsonEncode(roster!.schedule.map((d) => d.toJson()).toList()) !=
                jsonEncode(roster!.baseline?.weeklyAvailability?.schedule
                        .map((d) => d.toJson())
                        .toList() ??
                    []));
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

  Widget _weekAtGlance(CoachAvailabilityState state) {
    final data = state.context, selected = state.day;
    if (data == null || selected == null) {
      return Panel(
          child: Text(state.loading
              ? 'Loading your schedule…'
              : state.message ??
                  'Schedule preview is unavailable. Refresh to retry.'));
    }
    final windows = _effectiveWindowsForDate(selected, state);
    final minutes = windows.fold<int>(
        0, (sum, w) => sum + (w.endAtMillis - w.startAtMillis) ~/ 60000);
    final cap = roster?.dailyHours;
    final blocks = _blocksForDate(selected);
    final custom = (selected.revision ?? 0) > 0;
    final limit = roster?.advanceDays;
    final lastDate = limit == null
        ? null
        : DateTime.parse(data.todayLocalDate)
            .add(Duration(days: limit))
            .toIso8601String()
            .substring(0, 10);
    final outside =
        lastDate != null && selected.localDate.compareTo(lastDate) > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
          'Read-only preview · select a day to see how your settings apply.',
          style: TextStyle(color: AppColors.inkSoft, height: 1.5)),
      const SizedBox(height: 12),
      Row(children: [
        for (final day in data.days)
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
                message:
                    '${day.localDate} · ${_formatDayDuration(day, state)} after breaks',
                child: OutlinedButton(
                  onPressed: state.loading
                      ? null
                      : () => availabilityCubit?.openDay(day.localDate),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(0, 76),
                      backgroundColor: selected.localDate == day.localDate
                          ? AppColors.primaryTint
                          : AppColors.surface,
                      side: BorderSide(
                          color: selected.localDate == day.localDate
                              ? AppColors.primary
                              : AppColors.hairline)),
                  child: Column(children: [
                    Text(_weekdayInitials[
                        DateTime.parse(day.localDate).weekday - 1]),
                    const SizedBox(height: 4),
                    Text('${DateTime.parse(day.localDate).day}'),
                    const SizedBox(height: 4),
                    Text(_formatDayDuration(day, state),
                        style: const TextStyle(fontSize: 11)),
                    if (_blocksForDate(day).isNotEmpty)
                      Tooltip(
                          message:
                              '${_blocksForDate(day).length} blocked ${_blocksForDate(day).length == 1 ? 'period' : 'periods'}',
                          child: const Icon(Icons.block, size: 12)),
                  ]),
                )),
          ))
      ]),
      const SizedBox(height: 12),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(selected.localDate,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip(label: Text(custom ? 'Custom date hours' : 'Weekly schedule')),
          if (roster?.dirty == true) const Chip(label: Text('Unsaved preview'))
        ]),
        const SizedBox(height: 10),
        Text(
            'Open hours after breaks: ${minutes == 0 ? 'Off' : '${minutes / 60}h'}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        if (cap != null)
          Text('Daily booking cap: ${cap}h total across all Members.'),
        if (outside)
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                  'Outside your advance-booking window. Members cannot book this date yet.',
                  style: TextStyle(color: AppColors.danger))),
        const SizedBox(height: 10),
        for (final window in windows)
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                  '${selected.labelFor(window.startAtMillis)} – ${selected.labelFor(window.endAtMillis)} · ${window.branchId}',
                  style: const TextStyle(height: 1.5))),
        if (windows.isEmpty)
          const Text('No working windows remain on this date.'),
        if (blocks.isNotEmpty) ...[
          const Divider(height: 24),
          Text('Blocked periods on ${selected.localDate}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final block in blocks)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '${rosterExceptionType(block.type)} · ${_formatBlockInterval(selected, block)}${block.reason.isEmpty ? '' : '\n${block.reason}'}')),
        ],
        const Divider(height: 24),
        Text(
            custom
                ? 'This date has its own hours; weekly changes do not replace them. Manage this under One-off date changes below.'
                : 'Changes to weekly hours and breaks are previewed here immediately. Save changes to apply them to Member booking.',
            style: const TextStyle(color: AppColors.inkSoft, height: 1.5)),
        const SizedBox(height: 8),
        const Text(
            'Open hours are not remaining free slots. Existing bookings, active holds, the daily cap and advance window are checked by the server.',
            style:
                TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.5)),
      ])),
    ]);
  }

  Widget _oneOffSection() => Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('One-off date changes',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
            'Use different hours for one date only, including extra hours. This replaces that date’s schedule; your weekly hours stay unchanged. For a break or day off, use Time off and breaks instead.',
            style: TextStyle(height: 1.5, color: AppColors.inkSoft)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            key: const ValueKey('open-specific-date-btn'),
            onPressed: enabled
                ? () => _openSpecificDateSheet(
                    date: availabilityCubit?.state.day?.localDate)
                : null,
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Change hours for one date')),
        const SizedBox(height: 6),
        const Text('Date changes are saved separately inside their editor.',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
      ]));

  Widget _recurringHours() {
    if (roster?.loading == true && roster?.baseline == null) {
      return const Panel(child: Text('-'));
    }
    if (roster?.baseline == null && roster?.message != null) {
      return const SizedBox.shrink();
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
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
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
                      onChanged:
                          enabled ? (v) => roster!.toggleDay(number, v) : null,
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
    if (roster?.baseline == null && roster?.message != null) return [];
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
    if (roster?.baseline == null) {
      return const Panel(
          child: Text('Load your schedule to configure booking limits.'));
    }
    final daily = roster!.dailyHours, advance = roster!.advanceDays;
    final today = availabilityCubit?.state.context?.todayLocalDate;
    final lastDate = today == null || advance == null
        ? null
        : DateTime.parse(today)
            .add(Duration(days: advance))
            .toIso8601String()
            .substring(0, 10);
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Daily coaching capacity',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text(
          'Limit the total booked coaching time across all Members, not per Member. Confirmed bookings and unexpired payment holds count toward this limit.',
          style: TextStyle(height: 1.5, color: AppColors.inkSoft)),
      const SizedBox(height: 14),
      DropdownButtonFormField<int>(
          key: ValueKey(('daily-capacity', daily)),
          initialValue: daily,
          decoration: const InputDecoration(
              labelText: 'Maximum booked hours per day',
              border: OutlineInputBorder()),
          items: [
            for (var n = 1; n <= 24; n++)
              DropdownMenuItem(value: n, child: Text('$n hours total'))
          ],
          onChanged: enabled ? (v) => roster!.limits(hours: v) : null),
      const SizedBox(height: 12),
      const Text(
          'Example: working 09:00–17:00 with a 6-hour cap allows at most 6 booked hours within those windows. A larger cap never adds working hours.',
          style: TextStyle(fontSize: 13, height: 1.5)),
      const Divider(height: 32),
      Text('Advance-booking window',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text(
          'Choose how many days ahead Members can book. It does not change your weekly hours or the length of a session.',
          style: TextStyle(height: 1.5, color: AppColors.inkSoft)),
      const SizedBox(height: 14),
      DropdownButtonFormField<int>(
          key: ValueKey(('advance-window', advance)),
          initialValue: advance,
          decoration: const InputDecoration(
              labelText: 'Days ahead Members can book',
              border: OutlineInputBorder()),
          items: [
            for (var n = 1; n <= 30; n++)
              DropdownMenuItem(value: n, child: Text('$n days ahead'))
          ],
          onChanged: enabled ? (v) => roster!.limits(days: v) : null),
      if (lastDate != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
                'Last bookable date: $lastDate (inclusive, organization time). Past times are not bookable.',
                style: const TextStyle(fontSize: 13, height: 1.5))),
      const SizedBox(height: 10),
      const Text(
          'Lowering a limit preserves existing reservations; it restricts new bookings.',
          style:
              TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.5)),
    ]));
  }

  List<Widget> _footerSection() {
    return [
      const Text(
          'Save weekly hours, time off and booking limits together. One-off dates are saved separately in their editor.',
          style: TextStyle(color: AppColors.inkSoft, height: 1.5)),
      const SizedBox(height: 12),
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
                  roster?.uncertain == true ? 'Retry save' : 'Save changes',
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
            color:
                roster?.dirty == true ? AppColors.primary : AppColors.inkSoft,
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
                roster == null ? 'Date-specific hours' : 'Weekly working hours',
            limitsTitle: 'Booking limits',
            actions: [
              IconButton(
                tooltip: 'Discard and reload',
                onPressed: busy ? null : _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
            header: [
              if (roster?.baseline == null && roster?.message != null)
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(roster!.message!,
                          style: const TextStyle(color: AppColors.danger)),
                      TextButton.icon(
                          onPressed: () => roster!.reload(discard: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry loading roster')),
                    ])),
              if (busy || cubitState.loading || cubitState.saving)
                const LinearProgressIndicator(),
              if (cubitState.message != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(cubitState.message!)),
            ],
            weekAtGlance: _weekAtGlance(cubitState),
            workingHours: [
              _recurringHours(),
              const SizedBox(height: 16),
              _oneOffSection(),
            ],
            onAddTimeOff: enabled ? _addException : null,
            timeOff: _timeOffSection(),
            limits: [
              _limitsSection(),
            ],
            footer: [..._footerSection(), const SizedBox(height: 16), GoogleIntegrationPanel(repository: widget.googleIntegration ?? const DisconnectedGoogleIntegrationRepository(), coachId: _effectiveCoachId)],
          ),
        );
      },
    );
  }
}
