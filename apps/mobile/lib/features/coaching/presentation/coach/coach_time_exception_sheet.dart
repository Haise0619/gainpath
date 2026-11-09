import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'coach_roster_editor.dart';

/// All instants and labels come from server calendar boundaries, including DST.
class CoachTimeExceptionSheet extends StatefulWidget {
  const CoachTimeExceptionSheet(
      {super.key,
      required this.repository,
      required this.roster,
      required this.isCurrent,
      this.initial,
      this.initialDate});
  final CoachAvailabilityRepository repository;
  final CoachRosterSnapshot roster;
  final bool Function() isCurrent;
  final CoachTimeException? initial;
  final String? initialDate;
  @override
  State<CoachTimeExceptionSheet> createState() =>
      _CoachTimeExceptionSheetState();
}

class _CoachTimeExceptionSheetState extends State<CoachTimeExceptionSheet> {
  final _days = <CoachAvailabilityDay>[];
  late final _reason =
      TextEditingController(text: widget.initial?.reason ?? '');
  late String _type = widget.initial?.type ?? 'breakTime';
  String? _startDate, _endDate, _message;
  int? _start, _end;
  bool _loading = true, _dirty = false, _fullDay = false, _applying = false;
  int _generation = 0;
  late int _serverNowMillis = widget.roster.serverNowMillis;

  Iterable<CoachTimeBoundary> _starts(CoachAvailabilityDay day) =>
      day.boundaries
          .take(day.boundaries.length - 1)
          .where((boundary) => boundary.atMillis > _serverNowMillis);

  bool get _current => mounted && widget.isCurrent();

  String _shift(String date, int days) => DateTime.parse('${date}T00:00:00Z')
      .add(Duration(days: days))
      .toIso8601String()
      .substring(0, 10);

  String _readableDate(String isoDate) {
    try {
      final dt = DateTime.parse('${isoDate}T00:00:00Z');
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      var date = widget.roster.todayLocalDate;
      final days = <CoachAvailabilityDay>[];
      while (date.compareTo(widget.roster.throughLocalDate) <= 0) {
        final remaining =
            DateTime.parse('${widget.roster.throughLocalDate}T00:00:00Z')
                    .difference(DateTime.parse('${date}T00:00:00Z'))
                    .inDays +
                1;
        final value = await widget.repository.load(
            coachId: widget.roster.coachId,
            firstLocalDate: date,
            dayCount: remaining < 7 ? remaining : 7);
        if (!_current || generation != _generation) return;
        if (value.serverNowMillis > _serverNowMillis) {
          _serverNowMillis = value.serverNowMillis;
        }
        if (value.timeZone != widget.roster.timeZone ||
            value.policyVersion != widget.roster.policyVersion ||
            value.todayLocalDate != widget.roster.todayLocalDate ||
            (value.rosterRevision != null &&
                value.rosterRevision != widget.roster.revision)) {
          throw const CoachAvailabilityException('aborted');
        }
        days.addAll(value.days.where((d) =>
            !d.reviewRequired &&
            (d.editable || d.localDate == widget.roster.todayLocalDate) &&
            d.boundaries.length >= 2 &&
            _starts(d).isNotEmpty &&
            d.localDate.compareTo(widget.roster.todayLocalDate) >= 0 &&
            d.localDate.compareTo(widget.roster.throughLocalDate) <= 0));
        date = _shift(date, remaining < 7 ? remaining : 7);
      }
      if (!_current || generation != _generation) return;
      days.removeWhere((day) => _starts(day).isEmpty);
      _days.addAll(days);
      if (days.isEmpty) {
        _message = 'No editable future dates are available. Reload the roster.';
      } else if (widget.initial != null) {
        final old = widget.initial!;
        final startDay = days
            .where(
                (d) => _starts(d).any((b) => b.atMillis == old.startAtMillis))
            .firstOrNull;
        final endDay = days
            .where((d) =>
                d.boundaries.skip(1).any((b) => b.atMillis == old.endAtMillis))
            .firstOrNull;
        if (startDay == null || endDay == null) {
          _message =
              'This blocked time is outside the editable dates. Reload the roster.';
        } else {
          _startDate = startDay.localDate;
          _endDate = endDay.localDate;
          _start = old.startAtMillis;
          _end = old.endAtMillis;
          _fullDay = _startDate != widget.roster.todayLocalDate &&
              _start == startDay.boundaries.first.atMillis &&
              _end == endDay.boundaries.last.atMillis;
        }
      } else {
        final selected =
            days.where((d) => d.localDate == widget.initialDate).firstOrNull ??
                days.first;
        _startDate = selected.localDate;
        _endDate = _startDate;
        _start = _starts(selected).first.atMillis;
        _end = selected.boundaries
            .firstWhere((b) => b.atMillis > _start!)
            .atMillis;
      }
      setState(() => _loading = false);
    } catch (error) {
      if (!_current || generation != _generation) return;
      setState(() {
        _loading = false;
        _message = error is CoachAvailabilityException
            ? error.message
            : 'Could not load organization dates. Cancel and retry.';
      });
    }
  }

  CoachAvailabilityDay get _first =>
      _days.firstWhere((d) => d.localDate == _startDate);
  CoachAvailabilityDay get _last =>
      _days.firstWhere((d) => d.localDate == _endDate);

  void _dates({String? startDate, String? endDate}) {
    setState(() {
      _dirty = true;
      _startDate = startDate ?? _startDate;
      _endDate = endDate ?? _endDate;
      if (_endDate!.compareTo(_startDate!) < 0) _endDate = _startDate;
      if (_startDate == widget.roster.todayLocalDate) _fullDay = false;
      _start = _starts(_first).first.atMillis;
      _end = _fullDay
          ? _last.boundaries.last.atMillis
          : _last.boundaries.firstWhere((b) => b.atMillis > _start!).atMillis;
    });
  }

  Future<void> _cancel() async {
    if (!_dirty ||
        await confirmSheet(context,
            title: 'Discard unsaved changes?',
            message: 'This blocked time has not been applied.',
            confirmLabel: 'Discard changes')) {
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _typeChip(String type, String label, IconData icon, bool editable) {
    final selected = _type == type;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: editable
              ? () => setState(() {
                    _type = type;
                    _dirty = true;
                    if (type == 'offDay' &&
                        _startDate != widget.roster.todayLocalDate) {
                      _fullDay = true;
                      _dates();
                    }
                  })
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryTint : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.hairline,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.inkSoft),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? AppColors.primaryDark : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editable =
        !_loading && _message == null && _startDate != null && _current;
    return PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _cancel();
        },
        child: SafeArea(
            child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
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
                              widget.initial == null
                                  ? 'Add Time Off / Break'
                                  : 'Edit Time Off / Break',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: _cancel,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Block periods on your calendar to prevent member bookings.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 12),

                      if (_loading) const LinearProgressIndicator(),
                      if (_message != null) ...[
                        const SizedBox(height: 8),
                        Text(_message!,
                            style: const TextStyle(color: AppColors.danger)),
                      ],
                      if (!_current)
                        const Text('Schedule unavailable for this session.',
                            style: TextStyle(color: AppColors.danger)),

                      // Block Type Selection
                      Row(
                        children: [
                          _typeChip('breakTime', 'Break', Icons.coffee_rounded,
                              editable),
                          const SizedBox(width: 8),
                          _typeChip('offDay', 'Off Day',
                              Icons.event_busy_rounded, editable),
                          const SizedBox(width: 8),
                          _typeChip('leave', 'Leave',
                              Icons.flight_takeoff_rounded, editable),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Reason input
                      TextField(
                          controller: _reason,
                          enabled: editable,
                          maxLength: 200,
                          decoration: InputDecoration(
                              labelText: 'Reason (optional)',
                              hintText: 'e.g. Lunch break, Personal appointment',
                              prefixIcon: const Icon(Icons.notes_rounded,
                                  size: 18, color: AppColors.primary),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10)),
                          onChanged: (_) => setState(() => _dirty = true)),
                      const SizedBox(height: 10),

                      if (editable) ...[
                        // Date Pickers
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                  key: ValueKey(('start-date', _startDate)),
                                  initialValue: _startDate,
                                  decoration: InputDecoration(
                                      labelText: 'Start date',
                                      prefixIcon: const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                          color: AppColors.primary),
                                      filled: true,
                                      fillColor: AppColors.surface,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8)),
                                  items: _days
                                      .map((d) => DropdownMenuItem(
                                          value: d.localDate,
                                          child: Text(
                                            _readableDate(d.localDate),
                                            style: const TextStyle(
                                                fontSize: 12.5),
                                            overflow: TextOverflow.ellipsis,
                                          )))
                                      .toList(),
                                  onChanged: (v) => _dates(startDate: v)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                  key: ValueKey(
                                      ('end-date', _startDate, _endDate)),
                                  initialValue: _endDate,
                                  decoration: InputDecoration(
                                      labelText: 'End date',
                                      prefixIcon: const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                          color: AppColors.primary),
                                      filled: true,
                                      fillColor: AppColors.surface,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8)),
                                  items: _days
                                      .where((d) =>
                                          d.localDate.compareTo(_startDate!) >= 0)
                                      .map((d) => DropdownMenuItem(
                                          value: d.localDate,
                                          child: Text(
                                            _readableDate(d.localDate),
                                            style: const TextStyle(
                                                fontSize: 12.5),
                                            overflow: TextOverflow.ellipsis,
                                          )))
                                      .toList(),
                                  onChanged: (v) => _dates(endDate: v)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Full Day Switch
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 2),
                              title: const Text('Full day',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: const Text(
                                  'Block all working hours for the selected date(s)',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.inkSoft)),
                              value: _fullDay,
                              onChanged:
                                  _startDate == widget.roster.todayLocalDate
                                      ? null
                                      : (v) {
                                          _fullDay = v;
                                          _dates();
                                        }),
                        ),

                        // Time Range Inputs (when not full day)
                        if (!_fullDay) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                    key: ValueKey(
                                        ('start-time', _startDate, _start)),
                                    initialValue: _start,
                                    decoration: InputDecoration(
                                        labelText: 'Start time',
                                        prefixIcon: const Icon(
                                            Icons.schedule_rounded,
                                            size: 16,
                                            color: AppColors.primary),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8)),
                                    items: _starts(_first)
                                        .map((b) => DropdownMenuItem(
                                            value: b.atMillis,
                                            child: Text(b.label,
                                                style: const TextStyle(
                                                    fontSize: 12.5))))
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                          _start = v;
                                          _dirty = true;
                                          if (_end! <= _start!) {
                                            _end = _last.boundaries
                                                .firstWhere(
                                                    (b) => b.atMillis > _start!)
                                                .atMillis;
                                          }
                                        })),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                    key: ValueKey((
                                      'end-time',
                                      _endDate,
                                      _start,
                                      _end
                                    )),
                                    initialValue: _end,
                                    decoration: InputDecoration(
                                        labelText: 'End time',
                                        prefixIcon: const Icon(
                                            Icons.schedule_rounded,
                                            size: 16,
                                            color: AppColors.primary),
                                        filled: true,
                                        fillColor: AppColors.surface,
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8)),
                                    items: _last.boundaries
                                        .where((b) => b.atMillis > _start!)
                                        .map((b) => DropdownMenuItem(
                                            value: b.atMillis,
                                            child: Text(b.label,
                                                style: const TextStyle(
                                                    fontSize: 12.5))))
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                          _end = v;
                                          _dirty = true;
                                        })),
                              ),
                            ],
                          ),
                        ],
                      ],
                      const SizedBox(height: 18),

                      // Footer Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _cancel,
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const ValueKey('apply-time-exception-btn'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: editable &&
                                      !_applying &&
                                      _start! > _serverNowMillis &&
                                      _end! > _start!
                                  ? () {
                                      if (!_current || _applying) return;
                                      _applying = true;
                                      Navigator.pop(
                                          context,
                                          CoachTimeException(
                                              id: widget.initial?.id ??
                                                  CoachRosterEditor.newId(),
                                              type: _type,
                                              reason: _reason.text.trim(),
                                              startLabel:
                                                  '$_startDate ${_first.boundaries.firstWhere((b) => b.atMillis == _start).label}',
                                              endLabel:
                                                  '$_endDate ${_last.boundaries.firstWhere((b) => b.atMillis == _end).label}',
                                              startAtMillis: _start!,
                                              endAtMillis: _end!));
                                    }
                                  : null,
                              child: const Text('Apply blocked time'),
                            ),
                          ),
                        ],
                      ),
                    ]))));
  }
}
