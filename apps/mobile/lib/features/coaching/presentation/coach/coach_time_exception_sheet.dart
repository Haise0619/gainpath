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
      this.initial});
  final CoachAvailabilityRepository repository;
  final CoachRosterSnapshot roster;
  final bool Function() isCurrent;
  final CoachTimeException? initial;
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
        _startDate = days.first.localDate;
        _endDate = _startDate;
        _start = _starts(days.first).first.atMillis;
        _end = days.first.boundaries
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
                    20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          widget.initial == null
                              ? 'Add time off or break'
                              : 'Edit time off or break',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('Organization time: ${widget.roster.timeZone}'),
                      if (_loading) const LinearProgressIndicator(),
                      if (_message != null) Text(_message!),
                      if (!_current)
                        const Text('Schedule unavailable for this session.'),
                      DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(
                                value: 'breakTime', child: Text('Break')),
                            DropdownMenuItem(
                                value: 'offDay', child: Text('Off day')),
                            DropdownMenuItem(
                                value: 'leave', child: Text('Leave'))
                          ],
                          onChanged: editable
                              ? (v) => setState(() {
                                    _type = v!;
                                    _dirty = true;
                                  })
                              : null),
                      TextField(
                          controller: _reason,
                          enabled: editable,
                          maxLength: 200,
                          decoration: const InputDecoration(
                              labelText: 'Reason (optional)'),
                          onChanged: (_) => setState(() => _dirty = true)),
                      if (editable) ...[
                        DropdownButtonFormField<String>(
                            key: ValueKey(('start-date', _startDate)),
                            initialValue: _startDate,
                            decoration:
                                const InputDecoration(labelText: 'Start date'),
                            items: _days
                                .map((d) => DropdownMenuItem(
                                    value: d.localDate,
                                    child: Text(d.localDate)))
                                .toList(),
                            onChanged: (v) => _dates(startDate: v)),
                        DropdownButtonFormField<String>(
                            key: ValueKey(('end-date', _startDate, _endDate)),
                            initialValue: _endDate,
                            decoration:
                                const InputDecoration(labelText: 'End date'),
                            items: _days
                                .where((d) =>
                                    d.localDate.compareTo(_startDate!) >= 0)
                                .map((d) => DropdownMenuItem(
                                    value: d.localDate,
                                    child: Text(d.localDate)))
                                .toList(),
                            onChanged: (v) => _dates(endDate: v)),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Full day'),
                            value: _fullDay,
                            onChanged:
                                _startDate == widget.roster.todayLocalDate
                                    ? null
                                    : (v) {
                                        _fullDay = v;
                                        _dates();
                                      }),
                        if (!_fullDay) ...[
                          DropdownButtonFormField<int>(
                              key: ValueKey(('start-time', _startDate, _start)),
                              initialValue: _start,
                              decoration: const InputDecoration(
                                  labelText: 'Start time'),
                              items: _starts(_first)
                                  .map((b) => DropdownMenuItem(
                                      value: b.atMillis, child: Text(b.label)))
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
                          DropdownButtonFormField<int>(
                              key: ValueKey(
                                  ('end-time', _endDate, _start, _end)),
                              initialValue: _end,
                              decoration:
                                  const InputDecoration(labelText: 'End time'),
                              items: _last.boundaries
                                  .where((b) => b.atMillis > _start!)
                                  .map((b) => DropdownMenuItem(
                                      value: b.atMillis, child: Text(b.label)))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                    _end = v;
                                    _dirty = true;
                                  })),
                        ],
                      ],
                      const SizedBox(height: 16),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                            onPressed: _cancel, child: const Text('Cancel')),
                        FilledButton(
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
                            child: const Text('Apply blocked time'))
                      ]),
                    ]))));
  }
}
