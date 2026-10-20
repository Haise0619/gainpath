import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'coach_roster_editor.dart';
import 'coach_time_exception_sheet.dart';

const rosterWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];
String rosterMinute(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String rosterExceptionType(String type) => switch (type) {
      'breakTime' => 'Break',
      'offDay' => 'Off day',
      _ => 'Leave'
    };

class CoachRosterSections {
  const CoachRosterSections(
      this.editor, this.availabilityRepository, this.context,
      {required this.allowEdit});
  final CoachRosterEditor editor;
  final CoachAvailabilityRepository availabilityRepository;
  final BuildContext context;
  final bool allowEdit;
  bool get enabled => allowEdit && editor.enabled;
  Future<void> editDay(int number) async {
    final baseline = editor.baseline;
    if (!enabled || baseline == null || baseline.assignedBranchIds.isEmpty) {
      return;
    }
    final old = editor.schedule.where((d) => d.dayOfWeek == number).firstOrNull;
    var active = old?.isActive ?? false;
    var start = old?.startMinute ?? 540;
    var end = old?.endMinute ?? 1020;
    var branch = old?.branchId ?? baseline.assignedBranchIds.first;
    var dirty = false;
    final result = await showModalBottomSheet<CoachWeeklyDay>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, update) => PopScope(
                  canPop: !dirty,
                  onPopInvokedWithResult: (didPop, _) async {
                    if (didPop) return;
                    final discard = await confirmSheet(sheetContext,
                        title: 'Discard unsaved changes?',
                        message: 'Your working hours have not been applied.',
                        confirmLabel: 'Discard changes');
                    if (discard && sheetContext.mounted) {
                      Navigator.pop(sheetContext);
                    }
                  },
                  child: SafeArea(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(rosterWeekdays[number - 1],
                                style: Theme.of(context).textTheme.titleLarge),
                            SwitchListTile(
                                title: const Text('Working day'),
                                value: active,
                                onChanged: (v) => update(() {
                                      active = v;
                                      dirty = true;
                                    })),
                            DropdownButtonFormField<String>(
                                initialValue: branch,
                                decoration:
                                    const InputDecoration(labelText: 'Branch'),
                                items: baseline.assignedBranchIds
                                    .map((b) => DropdownMenuItem(
                                        value: b, child: Text(b)))
                                    .toList(),
                                onChanged: (v) => update(() {
                                      branch = v!;
                                      dirty = true;
                                    })),
                            DropdownButtonFormField<int>(
                                initialValue: start,
                                decoration: const InputDecoration(
                                    labelText: 'Start time'),
                                items: List.generate(
                                    48,
                                    (i) => DropdownMenuItem(
                                        value: i * 30,
                                        child: Text(rosterMinute(i * 30)))),
                                onChanged: !active
                                    ? null
                                    : (v) => update(() {
                                          start = v!;
                                          if (end <= start) end = start + 30;
                                          dirty = true;
                                        })),
                            DropdownButtonFormField<int>(
                                key: ValueKey((start, end)),
                                initialValue: end,
                                decoration: const InputDecoration(
                                    labelText: 'End time'),
                                items: [
                                  for (var minute = start + 30;
                                      minute <= 1440;
                                      minute += 30)
                                    DropdownMenuItem(
                                        value: minute,
                                        child: Text(rosterMinute(minute)))
                                ],
                                onChanged: !active
                                    ? null
                                    : (v) => update(() {
                                          end = v!;
                                          dirty = true;
                                        })),
                            const SizedBox(height: 16),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                      onPressed: () async {
                                        if (!dirty ||
                                            await confirmSheet(sheetContext,
                                                title:
                                                    'Discard unsaved changes?',
                                                message:
                                                    'Your working hours have not been applied.',
                                                confirmLabel:
                                                    'Discard changes')) {
                                          if (sheetContext.mounted) {
                                            Navigator.pop(sheetContext);
                                          }
                                        }
                                      },
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(
                                          sheetContext,
                                          CoachWeeklyDay(
                                              dayOfWeek: number,
                                              isActive: active,
                                              startMinute: start,
                                              endMinute: end,
                                              branchId: branch)),
                                      child: const Text('Apply day'))
                                ]),
                          ]))),
                )));
    if (result != null && context.mounted && enabled) editor.day(result);
  }

  Future<void> editException([CoachTimeException? old]) async {
    if (!enabled) return;
    final result = await showModalBottomSheet<CoachTimeException>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CoachTimeExceptionSheet(
            repository: availabilityRepository,
            roster: editor.baseline!,
            isCurrent: editor.isCurrent,
            initial: old));
    if (result != null && context.mounted && enabled) editor.exception(result);
  }

  List<Widget> get workingHours => [
        const Eyebrow('Recurring working hours'),
        if (editor.loading) const LinearProgressIndicator(),
        if (editor.baseline == null && editor.message != null)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        editor.message!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => editor.reload(discard: true),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry loading roster'),
                ),
              ],
            ),
          )
        else if (editor.message != null)
          Text(editor.message!),
        if (editor.baseline == null && editor.message == null)
          const Panel(child: Text('-'))
        else if (editor.baseline != null) ...[
          Text('Organization time: ${editor.baseline!.timeZone}'),
          const Text(
              'Weekly changes apply to future unbooked time. Existing bookings are preserved.'),
          for (var number = 1; number <= 7; number++) _dayCard(number),
        ],
        const SizedBox(height: 20),
        const Eyebrow('Dated overrides'),
      ];
  Widget _dayCard(int number) {
    final day = editor.schedule.where((d) => d.dayOfWeek == number).firstOrNull;
    return Panel(
        child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(rosterWeekdays[number - 1]),
            subtitle: Text(day == null
                ? '-'
                : day.isActive
                    ? '${rosterMinute(day.startMinute)} – ${rosterMinute(day.endMinute)} · ${day.branchId}'
                    : 'Off'),
            trailing: IconButton(
                key: ValueKey('weekly-day-$number'),
                tooltip: 'Edit ${rosterWeekdays[number - 1]}',
                onPressed: enabled ? () => editDay(number) : null,
                icon: const Icon(Icons.edit_outlined))));
  }

  List<Widget> get timeOff => [
        if (editor.baseline == null && editor.message != null)
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
                  onPressed: () => editor.reload(discard: true),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry loading roster'),
                ),
              ],
            ),
          )
        else if (editor.baseline == null)
          const Panel(child: Text('-'))
        else if (editor.exceptions.isEmpty)
          const Panel(child: Text('No time off or breaks scheduled.')),
        for (final exception in editor.exceptions)
          Panel(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(exception.type == 'breakTime'
                      ? Icons.coffee_outlined
                      : exception.type == 'offDay'
                          ? Icons.event_busy_outlined
                          : Icons.flight_takeoff_outlined),
                  title: Text(rosterExceptionType(exception.type)),
                  subtitle: Text([
                    if (exception.startLabel != null &&
                        exception.endLabel != null)
                      '${exception.startLabel} – ${exception.endLabel}'
                    else
                      'View dates and times',
                    if (exception.reason.isNotEmpty) exception.reason,
                  ].join('\n')),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        key: ValueKey('edit-exception-${exception.id}'),
                        tooltip: 'Edit blocked time',
                        onPressed:
                            enabled ? () => editException(exception) : null,
                        icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                        key: ValueKey('remove-exception-${exception.id}'),
                        tooltip: 'Remove blocked time',
                        onPressed:
                            enabled ? () => editor.remove(exception.id) : null,
                        icon: const Icon(Icons.delete_outline))
                  ]))),
      ];
  List<Widget> get limits => [
        Panel(
            child: Column(children: [
          if (editor.baseline == null && editor.message != null) ...[
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => editor.reload(discard: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry loading roster'),
              ),
            ),
          ] else ...[
            DetailRow('Maximum booking hours per day',
                editor.dailyHours?.toString() ?? '-'),
            DropdownButtonFormField<int>(
                key: ValueKey(('hours', editor.dailyHours)),
                initialValue: editor.dailyHours,
                decoration:
                    const InputDecoration(labelText: 'Booking hours per day'),
                items: List.generate(
                    24,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text('${i + 1} hours'))),
                onChanged: enabled ? (v) => editor.limits(hours: v) : null),
            const Divider(height: 20),
            DetailRow('How far ahead members can book',
                editor.advanceDays == null ? '-' : '${editor.advanceDays} days'),
            DropdownButtonFormField<int>(
                key: ValueKey(('days', editor.advanceDays)),
                initialValue: editor.advanceDays,
                decoration:
                    const InputDecoration(labelText: 'Advance booking days'),
                items: List.generate(
                    30,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text('${i + 1} days'))),
                onChanged: enabled ? (v) => editor.limits(days: v) : null),
            const SizedBox(height: 16),
            if (editor.uncertain)
              const Text(
                  'Save could not be confirmed. Retry the same changes or discard and reload.'),
            FilledButton(
                onPressed: allowEdit &&
                        !editor.busy &&
                        !editor.conflict &&
                        editor.dirty &&
                        editor.isCurrent()
                    ? editor.save
                    : null,
                child: Text(editor.saving
                    ? 'Saving roster…'
                    : editor.uncertain
                        ? 'Retry roster save'
                        : 'Save roster')),
          ],
        ]))
      ];
}
