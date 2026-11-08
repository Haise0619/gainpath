import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

const availabilityWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];
String availabilityClock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class WeeklyHoursEdit {
  const WeeklyHoursEdit(this.day, this.copyTo);
  final CoachWeeklyDay day;
  final Set<int> copyTo;
}

class WeeklyHoursSheet extends StatefulWidget {
  const WeeklyHoursSheet(
      {super.key,
      required this.day,
      required this.branches,
      this.branchNames = const {}});
  final CoachWeeklyDay day;
  final List<String> branches;
  final Map<String, String> branchNames;
  @override
  State<WeeklyHoursSheet> createState() => _WeeklyHoursSheetState();
}

class _WeeklyHoursSheetState extends State<WeeklyHoursSheet> {
  late bool active = widget.day.isActive;
  late int start = widget.day.startMinute, end = widget.day.endMinute;
  late String branch = widget.day.branchId;
  final targets = <int>{};
  String? error;
  bool get dirty =>
      active != widget.day.isActive ||
      start != widget.day.startMinute ||
      end != widget.day.endMinute ||
      branch != widget.day.branchId ||
      targets.isNotEmpty;
  Future<void> close() async {
    if (!dirty ||
        await confirmSheet(context,
            title: 'Discard unsaved changes?',
            message: 'Your working hours have not been added to the draft.',
            confirmLabel: 'Discard changes')) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> pick(bool starting) async {
    final minute = starting ? start : end;
    final value = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: (minute ~/ 60) % 24, minute: minute % 60),
        builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
            child: child!));
    if (value == null || !mounted) return;
    final picked = value.hour * 60 + value.minute;
    if (picked % 30 != 0) {
      setState(() => error = 'Use 30-minute steps, such as 09:00 or 09:30.');
      return;
    }
    final next = starting ? picked : (picked == 0 ? 1440 : picked);
    if (!starting && next <= start) {
      setState(() => error = 'End time must be after start time.');
      return;
    }
    setState(() {
      error = null;
      if (starting) {
        start = next;
        if (end <= start) end = start + 30;
      } else {
        end = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await close();
      },
      child: SafeArea(
          child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(availabilityWeekdays[widget.day.dayOfWeek - 1],
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    const Text(
                        'Done updates your draft. Save Changes to publish it.'),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Working day'),
                        subtitle: Text(active
                            ? 'Members may book within these hours'
                            : 'Off — no weekly working hours'),
                        value: active,
                        onChanged: (v) => setState(() => active = v)),
                    if (widget.branches.length > 1)
                      DropdownButtonFormField<String>(
                          initialValue: branch,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Branch'),
                          items: widget.branches
                              .map((id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(widget.branchNames[id] ?? id)))
                              .toList(),
                          onChanged: (v) => setState(() => branch = v!)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      OutlinedButton.icon(
                          key: const Key('weekly-start-time'),
                          onPressed: active ? () => pick(true) : null,
                          icon: const Icon(Icons.schedule),
                          label: Text('Start ${availabilityClock(start)}')),
                      OutlinedButton.icon(
                          key: const Key('weekly-end-time'),
                          onPressed: active ? () => pick(false) : null,
                          icon: const Icon(Icons.schedule),
                          label: Text('End ${availabilityClock(end)}')),
                    ]),
                    if (error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(error!,
                              style: const TextStyle(color: AppColors.danger))),
                    const SizedBox(height: 12),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Copy to other days'),
                        subtitle: Text(targets.isEmpty
                            ? 'Use the same hours or Off setting'
                            : '${targets.length} days selected'),
                        children: [
                          for (var i = 1; i <= 7; i++)
                            if (i != widget.day.dayOfWeek)
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(availabilityWeekdays[i - 1]),
                                  value: targets.contains(i),
                                  onChanged: (v) => setState(() {
                                        v == true
                                            ? targets.add(i)
                                            : targets.remove(i);
                                      }))
                        ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: close, child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: FilledButton(
                              onPressed: () => Navigator.pop(
                                  context,
                                  WeeklyHoursEdit(
                                      CoachWeeklyDay(
                                          dayOfWeek: widget.day.dayOfWeek,
                                          isActive: active,
                                          startMinute: start,
                                          endMinute: end,
                                          branchId: branch),
                                      targets)),
                              child: const Text('Done')))
                    ]),
                  ]))));
}
