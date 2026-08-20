import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _fmtDate(DateTime d) => '${_weekdayNames[d.weekday - 1]}, ${d.day} ${_monthNames[d.month - 1]}';

Color _blockColor(BlockType type) {
  switch (type) {
    case BlockType.breakTime:
      return AppColors.info;
    case BlockType.offDay:
      return AppColors.warning;
    case BlockType.leave:
      return AppColors.danger;
  }
}

/// AD-M10.1/10.2 — View Availability Calendar. Three genuinely separate
/// scheduling concepts get three distinct sections rather than being
/// flattened into one list: a *recurring weekly template* (working
/// hours), *date-specific exceptions* (breaks/off-days/leave), and
/// *booking limits* — mixing "every Monday 8-5" with "leave on 12 Sep"
/// in one data structure would conflate a repeating rule with a
/// one-off override, which is exactly the kind of scheduling bug real
/// calendar systems spend a lot of effort avoiding.
///
/// Every edit here writes straight to `MockData.workingDays` /
/// `blockedSlots` — no local copy that only *looks* saved. The previous
/// version copied both into local lists and never wrote them back at
/// all, including the "add block" sheet, which silently threw away
/// whatever the coach typed and inserted a hardcoded placeholder row
/// instead.
class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  final _dayKeys = List.generate(7, (_) => GlobalKey());
  late double _dailyCap = MockData.dailyBookingCap.toDouble();
  late double _lookAhead = MockData.advanceBookingDays.toDouble();

  void _jumpToDay(int index) {
    final ctx = _dayKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut, alignment: 0.1);
    }
  }

  Future<void> _editHours(WorkingDay day) async {
    final start = await showTimePicker(context: context, initialTime: day.start, helpText: 'START TIME');
    if (start == null || !mounted) return;
    final end = await showTimePicker(context: context, initialTime: day.end, helpText: 'END TIME');
    if (end == null || !mounted) return;
    if (_toMinutes(end) <= _toMinutes(start)) {
      showToast(context, 'End time must be after start time.');
      return;
    }
    setState(() {
      day.start = start;
      day.end = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = MockData.workingDays;
    final blocks = [...MockData.blockedSlots]..sort((a, b) => a.date.compareTo(b.date));
    final now = DateTime.now();
    final bookedThisWeek = MockData.coachRoster
        .where((b) => b.start.isAfter(now) && b.start.isBefore(now.add(const Duration(days: 7))) && b.status != 'Cancelled')
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Availability')),
      body: PageBody(
        children: [
          const Eyebrow('This week at a glance'),
          Row(
            children: List.generate(7, (i) {
              final day = days[i];
              final hours = _toMinutes(day.end) - _toMinutes(day.start);
              return Expanded(
                child: GestureDetector(
                  onTap: () => _jumpToDay(i),
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
                        Text(_weekdayNames[i][0],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                        const SizedBox(height: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: day.active ? AppColors.success : AppColors.hairline,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          day.active ? '${(hours / 60).toStringAsFixed(hours % 60 == 0 ? 0 : 1)}h' : 'Off',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: day.active ? AppColors.ink : AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Recurring working hours'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(days.length, (i) {
                final day = days[i];
                return Container(
                  key: _dayKeys[i],
                  child: Column(
                    children: [
                      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Switch(
                              value: day.active,
                              onChanged: (v) => setState(() => day.active = v),
                            ),
                            const SizedBox(width: 6),
                            Text(day.day, style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            if (day.active)
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _editHours(day),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Row(
                                    children: [
                                      Text('${_fmtTime(day.start)} – ${_fmtTime(day.end)}',
                                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.edit_rounded, size: 15, color: AppColors.primary),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Text('Not working', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Eyebrow('Time off and breaks'),
              TextButton.icon(
                onPressed: () => _showBlockSheet(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (blocks.isEmpty)
            Panel(
              child: Text('Nothing blocked out right now.', style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ...blocks.map((b) => Padding(
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
                          child: Icon(b.type.icon, size: 19, color: _blockColor(b.type)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.reason, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                '${b.type.label}  ·  ${_fmtDate(b.date)}  ·  '
                                '${b.fullDay ? 'Full day' : '${_fmtTime(b.startTime!)} to ${_fmtTime(b.endTime!)}'}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showBlockSheet(context, existing: b),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 19),
                          onPressed: () async {
                            final ok = await confirmSheet(context,
                                title: 'Remove this block?',
                                message: 'That time reopens for members to book.',
                                confirmLabel: 'Remove',
                                destructive: true);
                            if (ok) setState(() => MockData.blockedSlots.remove(b));
                          },
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 20),
          const Eyebrow('Roster scheduling limits'),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              children: [
                const Icon(Icons.event_note_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('$bookedThisWeek session${bookedThisWeek == 1 ? '' : 's'} already booked this week',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Maximum sessions per day', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _dailyCap,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        label: '${_dailyCap.round()}',
                        onChanged: (v) => setState(() => _dailyCap = v),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text('${_dailyCap.round()}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Text('How far ahead members can book', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _lookAhead,
                        min: 7,
                        max: 60,
                        divisions: 53,
                        label: '${_lookAhead.round()} days',
                        onChanged: (v) => setState(() => _lookAhead = v),
                      ),
                    ),
                    SizedBox(
                      width: 62,
                      child: Text('${_lookAhead.round()} days',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    'Members can book up to ${_dailyCap.round()} session${_dailyCap.round() == 1 ? '' : 's'} with you '
                    'per day, up to ${_lookAhead.round()} days in advance.',
                    style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              MockData.dailyBookingCap = _dailyCap.round();
              MockData.advanceBookingDays = _lookAhead.round();
              showToast(context, 'Availability saved.');
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  void _showBlockSheet(BuildContext context, {BlockedSlot? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _BlockSlotSheet(existing: existing),
    ).then((_) => setState(() {}));
  }
}

/// Add/edit form for a single blocked slot. Both flows share this one
/// widget — editing just seeds the fields from [existing] and mutates it
/// in place on save instead of creating a new entry.
class _BlockSlotSheet extends StatefulWidget {
  final BlockedSlot? existing;
  const _BlockSlotSheet({this.existing});

  @override
  State<_BlockSlotSheet> createState() => _BlockSlotSheetState();
}

class _BlockSlotSheetState extends State<_BlockSlotSheet> {
  late BlockType _type;
  late final TextEditingController _reason;
  late DateTime _date;
  late bool _fullDay;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? BlockType.breakTime;
    _reason = TextEditingController(text: e?.reason ?? '');
    _date = e?.date ?? DateTime.now().add(const Duration(days: 1));
    _fullDay = e?.fullDay ?? false;
    _start = e?.startTime ?? const TimeOfDay(hour: 13, minute: 0);
    _end = e?.endTime ?? const TimeOfDay(hour: 14, minute: 0);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _save() {
    if (_reason.text.trim().isEmpty) {
      showToast(context, 'Add a reason first.');
      return;
    }
    if (!_fullDay && _toMinutes(_end) <= _toMinutes(_start)) {
      showToast(context, 'End time must be after start time.');
      return;
    }
    final existing = widget.existing;
    if (existing != null) {
      existing
        ..type = _type
        ..reason = _reason.text.trim()
        ..date = _date
        ..fullDay = _fullDay
        ..startTime = _fullDay ? null : _start
        ..endTime = _fullDay ? null : _end;
    } else {
      MockData.blockedSlots.add(BlockedSlot(
        id: 'bl${DateTime.now().millisecondsSinceEpoch}',
        type: _type,
        reason: _reason.text.trim(),
        date: _date,
        fullDay: _fullDay,
        startTime: _fullDay ? null : _start,
        endTime: _fullDay ? null : _end,
      ));
    }
    Navigator.pop(context);
    showToast(context, existing != null ? 'Block updated.' : 'Time blocked out.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing != null ? 'Edit blocked time' : 'Block out time',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const Eyebrow('Type'),
          Wrap(
            spacing: 8,
            children: BlockType.values.map((t) {
              final selected = t == _type;
              return ChoiceChip(
                label: Text(t.label),
                selected: selected,
                onSelected: (_) => setState(() => _type = t),
                avatar: Icon(t.icon, size: 16, color: selected ? Colors.white : _blockColor(t)),
                backgroundColor: AppColors.surface,
                selectedColor: _blockColor(t),
                labelStyle: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999), side: const BorderSide(color: AppColors.hairline)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(labelText: 'Reason', hintText: 'Medical leave, holiday, break'),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 17, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Text(_fmtDate(_date), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _fullDay,
            onChanged: (v) => setState(() => _fullDay = v),
            title: const Text('Full day'),
          ),
          if (!_fullDay) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('From ${_fmtTime(_start)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('To ${_fmtTime(_end)}'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _save,
            child: Text(widget.existing != null ? 'Save changes' : 'Block this time'),
          ),
        ],
      ),
    );
  }
}
