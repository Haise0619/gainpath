import 'weekly_hours_sheet.dart';
import 'availability_navigation_scope.dart';
import '../../../../navigation/google_integration.dart';
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

/// Canonical unified Coach Availability screen for mobile.
/// Feeds both real Firebase and mock/test adapters through the same production widgets.
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen(
      {super.key,
      this.liveRepository,
      this.coachId,
      this.isCurrent,
      this.googleIntegration,
      this.loadBranchNames});

  final CoachAvailabilityRepository? liveRepository;
  final GoogleIntegrationRepository? googleIntegration;
  final String? coachId;
  final Future<Map<String, String>> Function()? loadBranchNames;
  final bool Function()? isCurrent;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  AvailabilityNavigationController? _navigation;
  Map<String, String> _branchNames = const {};
  CoachRosterEditor? roster;
  CoachAvailabilityCubit? availabilityCubit;
  CoachAvailabilityRepository? _effectiveRepo;
  late String _effectiveCoachId;
  late bool Function() _effectiveIsCurrent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigation = AvailabilityNavigationScope.of(context);
    if (_navigation != null) _navigation!.beforeLeave = _beforeLeave;
    if (availabilityCubit != null) return;

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

    _loadBranchNames();
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
    if (_navigation?.beforeLeave == _beforeLeave) {
      _navigation!.beforeLeave = null;
    }
    roster?.removeListener(_onRosterChanged);
    roster?.dispose();
    availabilityCubit?.close();
    super.dispose();
  }

  bool get enabled =>
      (roster == null || roster!.enabled) && _effectiveIsCurrent();
  String _branchLabel(String id) => _branchNames[id] ?? id;
  Future<void> _loadBranchNames() async {
    if (widget.loadBranchNames == null) return;
    try {
      final names =
          await widget.loadBranchNames!().timeout(const Duration(seconds: 20));
      if (mounted && _effectiveIsCurrent()) {
        setState(() => _branchNames = Map.unmodifiable(names));
      }
    } catch (_) {/* IDs remain explicit if trusted names are unavailable. */}
  }

  Future<bool> _beforeLeave() async {
    if (!_effectiveIsCurrent()) return false;
    if (roster?.busy == true) {
      showToast(context, 'Please wait for the current save or refresh.');
      return false;
    }
    if (roster?.dirty != true && roster?.uncertain != true) return true;
    final discard = await confirmSheet(context,
        title: 'Unsaved Changes',
        message: roster?.uncertain == true
            ? 'The last save could not be confirmed. Reload the server version before leaving?'
            : 'Save your changes first, or discard this draft to leave.',
        confirmLabel: 'Discard & reload');
    if (!discard || !mounted || !_effectiveIsCurrent()) return false;
    await roster?.reload(discard: true);
    return mounted &&
        _effectiveIsCurrent() &&
        roster?.dirty != true &&
        roster?.uncertain != true;
  }

  Future<void> _reload() async {
    if (roster?.busy == true || availabilityCubit?.state.saving == true) return;
    if (roster?.dirty == true) {
      final discard = await confirmSheet(
        context,
        title: 'Discard unsaved changes?',
        message: 'Your schedule changes have not been saved.',
        confirmLabel: 'Discard changes',
      );
      if (!discard || !mounted) return;
    }
    await Future.wait<void>([
      if (roster != null) roster!.reload(discard: true),
      if (availabilityCubit != null) availabilityCubit!.discardAndReload()
    ]);
  }

  Future<void> _editDayHours(int dayOfWeek) async {
    if (!enabled || roster?.baseline == null) return;
    final old = roster!.dayFor(dayOfWeek);
    if (old == null) {
      showToast(context, 'Set up weekly hours first.');
      return;
    }
    final result = await showModalBottomSheet<WeeklyHoursEdit>(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        builder: (_) => WeeklyHoursSheet(
            day: old,
            branches: roster!.baseline!.assignedBranchIds,
            branchNames: _branchNames));
    if (result == null || !mounted || !enabled) return;
    roster!.day(result.day);
    roster!.copyDay(result.day.dayOfWeek, result.copyTo);
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
        initialDate: availabilityCubit?.state.day?.localDate,
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
      message:
          'Removing this block may reopen time within your working hours after you save.',
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
        branchNames: _branchNames,
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
      await availabilityCubit?.discardAndReload();
      if (mounted && _effectiveIsCurrent()) {
        showToast(
            context,
            availabilityCubit?.state.message == null
                ? 'Saved'
                : 'Changes saved. Schedule preview could not refresh.');
      }
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

  String _readableDate(String value) {
    final date = DateTime.parse(value);
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
    return '${_weekdayNames[date.weekday - 1].substring(0, 3)}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _weekAtGlance(CoachAvailabilityState state) {
    final data = state.context, selected = state.day;
    if (data == null || selected == null) {
      return Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(state.loading
            ? 'Loading schedule…'
            : state.message ?? 'Schedule unavailable.'),
        if (!state.loading)
          TextButton(onPressed: _reload, child: const Text('Retry'))
      ]));
    }
    final windows = _effectiveWindowsForDate(selected, state),
        blocks = _blocksForDate(selected);
    final custom = (selected.revision ?? 0) > 0;
    final loadingWeekly = roster != null && roster!.baseline == null;
    final weeklyConfigured = roster == null || roster!.schedule.isNotEmpty;
    final outside = roster?.advanceDays != null &&
        DateTime.parse(selected.localDate).isAfter(
            DateTime.parse(data.todayLocalDate)
                .add(Duration(days: roster!.advanceDays!)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
                '${_readableDate(data.days.first.localDate)} – ${_readableDate(data.days.last.localDate)}',
                style: Theme.of(context).textTheme.titleMedium),
            Text(data.timeZone,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft))
          ]),
      const SizedBox(height: 12),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final day in data.days)
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                      selected: selected.localDate == day.localDate,
                      child: OutlinedButton(
                          key: ValueKey('availability-date-${day.localDate}'),
                          onPressed: state.loading
                              ? null
                              : () => availabilityCubit?.openDay(day.localDate),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(68, 78),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              backgroundColor:
                                  selected.localDate == day.localDate
                                      ? AppColors.primaryTint
                                      : AppColors.surface,
                              side: BorderSide(
                                  color: selected.localDate == day.localDate
                                      ? AppColors.primary
                                      : AppColors.hairline)),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_weekdayNames[
                                    DateTime.parse(day.localDate).weekday - 1]
                                .substring(0, 3)),
                            Text('${DateTime.parse(day.localDate).day}',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w700)),
                            if (day.localDate == data.todayLocalDate)
                              const Text('Today',
                                  style: TextStyle(fontSize: 12)),
                            if (_blocksForDate(day).isNotEmpty)
                              Tooltip(
                                  message:
                                      '${_blocksForDate(day).length} blocked period${_blocksForDate(day).length == 1 ? '' : 's'}',
                                  child: const Icon(Icons.block, size: 14))
                          ]))))
          ])),
      const SizedBox(height: 12),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_readableDate(selected.localDate),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _sourceBadge(custom
              ? 'Custom hours'
              : loadingWeekly
                  ? 'Loading schedule'
                  : weeklyConfigured
                      ? 'Weekly hours'
                      : 'Not configured'),
          if (roster?.dirty == true) _sourceBadge('Unsaved preview')
        ]),
        const SizedBox(height: 12),
        Text(
            windows.isEmpty
                ? (loadingWeekly
                    ? 'Loading weekly hours…'
                    : !custom && !weeklyConfigured
                        ? 'Set up weekly hours to begin.'
                        : 'No working hours')
                : windows
                    .map((w) =>
                        '${selected.labelFor(w.startAtMillis)} – ${selected.labelFor(w.endAtMillis)}')
                    .join('\n'),
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.5)),
        for (final branch in windows.map((w) => w.branchId).toSet())
          Text(_branchLabel(branch)),
        if (roster?.dailyHours != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  'Daily capacity · ${roster!.dailyHours} booked hours total')),
        if (blocks.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Breaks & time off',
              style: Theme.of(context).textTheme.titleMedium),
          for (final block in blocks)
            Text(
                '${rosterExceptionType(block.type)} · ${_formatBlockInterval(selected, block)}')
        ],
        if (outside)
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Outside the advance booking window.',
                  style: TextStyle(color: AppColors.warning))),
        const SizedBox(height: 10),
        const Text('Working hours are not remaining bookable slots.',
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        if (custom)
          const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'Custom hours replace the weekly schedule for this date.',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
              onPressed: enabled
                  ? () =>
                      _editDayHours(DateTime.parse(selected.localDate).weekday)
                  : null,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Weekly Hours')),
          OutlinedButton.icon(
              key: const ValueKey('open-specific-date-btn'),
              onPressed: enabled
                  ? () => _openSpecificDateSheet(date: selected.localDate)
                  : null,
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: const Text('Change This Date')),
          TextButton.icon(
              onPressed: enabled ? _addException : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Time Off')),
        ])
      ]))
    ]);
  }

  Widget _sourceBadge(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: AppColors.primaryTint, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.primary)));

  Widget _recurringHours() {
    if (roster?.loading == true && roster?.baseline == null) {
      return const Panel(child: Text('Loading weekly hours…'));
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
              if (i > 0)
                const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.hairline),
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final large =
                        MediaQuery.textScalerOf(context).scale(14) > 19;
                    final controls = <Widget>[
                      Semantics(
                          label: '${_weekdayNames[number - 1]} working day',
                          child: Switch(
                              value: active,
                              onChanged: enabled && day != null
                                  ? (v) => roster!.toggleDay(number, v)
                                  : null)),
                      IconButton(
                          key: ValueKey('weekly-day-$number'),
                          tooltip: 'Edit ${_weekdayNames[number - 1]}',
                          onPressed: enabled && day != null
                              ? () => _editDayHours(number)
                              : null,
                          icon: const Icon(Icons.edit_outlined)),
                    ];
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(_weekdayNames[number - 1],
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium)),
                            if (!large) ...controls
                          ]),
                          Text(
                              day == null
                                  ? 'Not configured'
                                  : active
                                      ? '${rosterMinute(day.startMinute)} – ${rosterMinute(day.endMinute)} · ${_branchLabel(day.branchId)}'
                                      : 'Off',
                              style: Theme.of(context).textTheme.bodyMedium),
                          if (large)
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: controls),
                        ]);
                  })),
            ],
          );
        }),
      ),
    );
  }

  List<Widget> _timeOffSection() {
    if (roster?.baseline == null && roster?.message != null) return [];
    if (roster?.baseline == null) {
      return const [Panel(child: Text('Loading time off…'))];
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
      return const Text('Load your schedule to set booking limits.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Daily Coaching Capacity',
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('Total booked hours across all members.'),
      const SizedBox(height: 10),
      DropdownButtonFormField<int>(
          key: ValueKey(('daily-capacity', roster!.dailyHours)),
          initialValue: roster!.dailyHours,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Maximum hours per day', border: OutlineInputBorder()),
          items: [
            for (var i = 1; i <= 24; i++)
              DropdownMenuItem(value: i, child: Text('$i hours total'))
          ],
          onChanged: enabled ? (v) => roster!.limits(hours: v) : null),
      const SizedBox(height: 20),
      const Text('Advance Booking Window',
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('How far ahead members can book.'),
      const SizedBox(height: 10),
      DropdownButtonFormField<int>(
          key: ValueKey(('advance-window', roster!.advanceDays)),
          initialValue: roster!.advanceDays,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Days ahead', border: OutlineInputBorder()),
          items: [
            for (var i = 1; i <= 30; i++)
              DropdownMenuItem(value: i, child: Text('$i days ahead'))
          ],
          onChanged: enabled ? (v) => roster!.limits(days: v) : null),
      ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Learn More'),
          children: const [
            Text(
                'Confirmed bookings and valid payment holds count toward capacity. Lower limits preserve existing reservations. Capacity never adds working hours; final booking eligibility is checked when booking.',
                style: TextStyle(height: 1.5))
          ])
    ]);
  }

  Widget? _saveBar() {
    final draft = roster;
    if (draft == null || (!draft.dirty && !draft.uncertain && !draft.saving)) {
      return null;
    }
    return SafeArea(
        top: false,
        child: Container(
            key: const Key('availability-save-bar'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.hairline))),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      draft.saving
                          ? 'Saving…'
                          : draft.conflict
                              ? 'Changes need attention'
                              : draft.uncertain
                                  ? "Couldn’t Save · Retry"
                                  : 'Unsaved Changes',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  const SizedBox(height: 8),
                  FilledButton(
                      key: const ValueKey('save-roster'),
                      onPressed: canSave ? _saveChanges : null,
                      child: draft.saving
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white)),
                                  SizedBox(width: 10),
                                  Flexible(child: Text('Saving…'))
                                ])
                          : Text(
                              draft.uncertain ? 'Retry Save' : 'Save Changes')),
                  if (draft.conflict)
                    TextButton(
                        onPressed: draft.busy ? null : _reload,
                        child: const Text('Review & Reload')),
                ])));
  }

  List<Widget> _feedback() {
    if (roster?.message == null) return const [];
    final saved = roster!.message == 'Roster saved and refreshed.';
    return [
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: saved
                      ? AppColors.successTint
                      : AppColors.warning.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(saved ? 'Saved' : roster!.message!,
                        style: TextStyle(
                            color: saved ? AppColors.success : AppColors.ink)),
                    if (roster!.conflict)
                      TextButton(
                          onPressed: _reload,
                          child: const Text('Review & Reload'))
                  ])))
    ];
  }

  @override
  Widget build(BuildContext context) {
    final busy = roster?.busy == true;
    return BlocBuilder<CoachAvailabilityCubit, CoachAvailabilityState>(
        bloc: availabilityCubit,
        builder: (context, state) => UnsavedChangesGuard(
            dirty: roster?.dirty == true,
            busy: busy,
            child: AvailabilityPage(
              workingHoursTitle: 'Weekly Working Hours',
              saveBar: _saveBar(),
              onRefresh: _reload,
              actions: [
                IconButton(
                    tooltip: 'Refresh availability',
                    onPressed: busy ? null : _reload,
                    icon: const Icon(Icons.refresh_rounded))
              ],
              timeOffSummary: roster?.baseline == null
                  ? 'Not loaded'
                  : '${roster!.exceptions.length} blocked periods',
              limitsSummary:
                  '${roster?.dailyHours == null ? 'Set capacity' : '${roster!.dailyHours} hours / day'} · ${roster?.advanceDays == null ? 'Set advance window' : '${roster!.advanceDays} days ahead'}',
              header: [
                ..._feedback(),
                if (state.message != null && state.context != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      background: AppColors.warning.withValues(alpha: .1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.message!),
                          const Text('Showing the last loaded schedule.'),
                          TextButton(
                              onPressed: _reload, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  ),
                if (busy || state.loading || state.saving)
                  const LinearProgressIndicator(),
                if (roster?.baseline == null && roster?.message != null)
                  TextButton(
                      onPressed: _reload,
                      child: const Text('Retry loading schedule'))
              ],
              weekAtGlance: _weekAtGlance(state),
              workingHours: [
                if (roster?.baseline != null && roster!.schedule.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                          onPressed: enabled
                              ? () => roster!.initializeAllDays()
                              : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Set up weekly hours'))),
                _recurringHours()
              ],
              onAddTimeOff: enabled ? _addException : null,
              timeOff: _timeOffSection(),
              limits: [_limitsSection()],
              footer: [
                GoogleIntegrationPanel(
                    compact: true,
                    actions: googleIntegrationPanelActions(
                        widget.googleIntegration ??
                            const DisconnectedGoogleIntegrationRepository()),
                    coachId: _effectiveCoachId)
              ],
            )));
  }
}
