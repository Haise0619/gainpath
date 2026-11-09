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

String _durationText(int start, int end) {
  final diffMinutes = end > start ? end - start : 0;
  final hours = diffMinutes ~/ 60;
  final mins = diffMinutes % 60;
  if (mins == 0) return '$hours hrs';
  return '$hours h $mins m';
}

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
                  20, 10, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            availabilityWeekdays[widget.day.dayOfWeek - 1],
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: close,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Text(
                      'Done updates your draft. Save Changes to publish it.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 8),

                    // Working Day Switch
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Working day',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          active
                              ? 'Members may book within these hours'
                              : 'Off — no weekly working hours',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft),
                        ),
                        value: active,
                        onChanged: (v) => setState(() => active = v)),
                    const SizedBox(height: 6),

                    // Branch Selector
                    if (widget.branches.length > 1) ...[
                      DropdownButtonFormField<String>(
                          initialValue: branch,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Branch',
                            prefixIcon: const Icon(Icons.store_outlined,
                                size: 18, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          items: widget.branches
                              .map((id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(widget.branchNames[id] ?? id)))
                              .toList(),
                          onChanged: (v) => setState(() => branch = v!)),
                      const SizedBox(height: 10),
                    ],

                    // Time Range Selector Card (when active)
                    if (active) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 15, color: AppColors.primary),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'WORKING HOURS',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: AppColors.inkSoft),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _durationText(start, end),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  key: const Key('weekly-start-time'),
                                  onPressed: () => pick(true),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    side: const BorderSide(
                                        color: AppColors.hairline),
                                  ),
                                  icon: const Icon(
                                      Icons.schedule_rounded,
                                      size: 16,
                                      color: AppColors.primary),
                                  label: Text(
                                      'Start ${availabilityClock(start)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink)),
                                ),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 15, color: AppColors.inkSoft),
                                OutlinedButton.icon(
                                  key: const Key('weekly-end-time'),
                                  onPressed: () => pick(false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    side: const BorderSide(
                                        color: AppColors.hairline),
                                  ),
                                  icon: const Icon(
                                      Icons.schedule_rounded,
                                      size: 16,
                                      color: AppColors.primary),
                                  label: Text(
                                      'End ${availabilityClock(end)}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 14, color: AppColors.danger),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(error!,
                                      style: const TextStyle(
                                          color: AppColors.danger,
                                          fontSize: 12)),
                                ),
                              ],
                            )),
                      const SizedBox(height: 10),
                    ],

                    // Copy to Other Days Section
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Copy to other days',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          targets.isEmpty
                              ? 'Use the same hours or Off setting'
                              : '${targets.length} days selected',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft),
                        ),
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
                    const SizedBox(height: 14),

                    // Actions Row
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: close,
                              child: const Text('Cancel'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
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
