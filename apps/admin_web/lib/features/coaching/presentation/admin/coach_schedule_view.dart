import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class AdminCoachScheduleView extends StatefulWidget {
  const AdminCoachScheduleView(
      {super.key,
      required this.repository,
      required this.coachId,
      required this.isCurrent,
      this.branchRequest,
      this.initialBranchId,
      this.initialLocalDate});
  final CoachAvailabilityRepository repository;
  final String coachId;
  final String? initialBranchId, initialLocalDate;
  final bool Function() isCurrent;
  final BranchRequest? branchRequest;
  @override
  State<AdminCoachScheduleView> createState() => _AdminCoachScheduleViewState();
}

class _AdminCoachScheduleViewState extends State<AdminCoachScheduleView> {
  late String? _branch = widget.initialBranchId;
  bool _saving = false;
  final _branchNames = <String, String>{};
  String _name(String id) => _branchNames[id] ?? 'Unavailable branch';

  @override
  void initState() {
    super.initState();
    _loadBranchNames();
  }

  Future<void> _loadBranchNames() async {
    final request = widget.branchRequest;
    if (request == null) return;
    final names = <String, String>{};
    final cursors = <String>{};
    String? cursor;
    try {
      do {
        final page = await request(
            {'action': 'list', if (cursor != null) 'afterId': cursor});
        for (final row in page['records'] as List) {
          if (row['status'] == 'active') {
            names[row['branchId'] as String] = row['displayName'] as String;
          }
        }
        cursor = page['nextAfterId'] as String?;
        if (cursor != null && !cursors.add(cursor))
          throw StateError('Branch pagination did not advance.');
      } while (cursor != null);
      if (mounted && widget.isCurrent())
        setState(() => _branchNames.addAll(names));
    } catch (_) {
      if (mounted && widget.isCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Branch names could not be loaded. Refresh to retry.'),
        ));
      }
    }
  }

  String? get _manageableInitialDate {
    final selected = widget.initialLocalDate;
    if (selected == null) return null;
    final malaysia = DateTime.now().toUtc().add(const Duration(hours: 8));
    return selected.compareTo(malaysia.toIso8601String().substring(0, 10)) >= 0
        ? selected
        : null;
  }

  late Future<CoachAvailabilityContext> future = widget.repository
      .load(coachId: widget.coachId, firstLocalDate: _manageableInitialDate);
  Future<CoachRosterSnapshot>? roster;
  void _loadRoster() {
    final repository = widget.repository;
    if (repository is CoachRosterRepository) {
      roster = (repository as CoachRosterRepository)
          .loadRoster(coachId: widget.coachId);
    }
  }

  void _load([String? date]) => setState(() {
        future = widget.repository
            .load(coachId: widget.coachId, firstLocalDate: date);
      });

  Future<void> _editAssignments() async {
    final request = widget.branchRequest;
    if (_saving || request == null || !widget.isCurrent()) return;
    setState(() => _saving = true);
    try {
      final current = await request({
        'action': 'coachAssignments',
        'coachId': widget.coachId,
      });
      final expected = List<String>.from(current['branchIds'] as List);
      final selection = expected.toSet();
      final options = <String, String>{for (final id in expected) id: id};
      String? cursor;
      final cursors = <String>{};
      do {
        final page = await request(
            {'action': 'list', if (cursor != null) 'afterId': cursor});
        for (final row in page['records'] as List) {
          if (row['status'] == 'active' ||
              selection.contains(row['branchId'])) {
            options[row['branchId'] as String] =
                '${row['displayName']}${row['status'] == 'active' ? '' : ' (inactive)'}';
          }
        }
        cursor = page['nextAfterId'] as String?;
        if (cursor != null && !cursors.add(cursor))
          throw StateError('Branch list did not advance.');
      } while (cursor != null);
      if (!mounted || !widget.isCurrent()) return;
      final result = await showDialog<List<String>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Assigned branches'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final option in options.entries)
                  CheckboxListTile(
                    title: Text(option.value),
                    value: selection.contains(option.key),
                    onChanged: (checked) => update(() {
                      if (checked == true) {
                        selection.add(option.key);
                      } else {
                        selection.remove(option.key);
                      }
                    }),
                  ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: selection.isEmpty || selection.length > 8
                    ? null
                    : () => Navigator.pop(context, selection.toList()..sort()),
                child: const Text('Save assignments'),
              ),
            ],
          ),
        ),
      );
      if (result == null || !mounted || !widget.isCurrent()) return;
      await request({
        'action': 'saveCoachAssignments',
        'coachId': widget.coachId,
        'expectedBranchIds': expected,
        'branchIds': result,
      });
      final readBack = await request(
          {'action': 'coachAssignments', 'coachId': widget.coachId});
      final actual = List<String>.from(readBack['branchIds'] as List)..sort();
      if (actual.join(',') != result.join(','))
        throw StateError('Assignment verification failed.');
      if (mounted && widget.isCurrent()) {
        roster = null;
        _load();
      }
    } catch (error) {
      if (mounted && widget.isCurrent()) {
        final message = switch (error) {
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message:
                'Move or remove current schedule windows before removing that branch.'
          ) =>
            'This branch is still used in the coach’s schedule. Keep both '
                'branches assigned, then move or remove the recurring hours and '
                'any dated availability for the branch you want to remove. '
                'After that, save the branch assignment again.',
          FirebaseFunctionsException(code: 'aborted') =>
            'The coach’s branch assignments changed. Reopen the editor to load the latest assignments.',
          FirebaseFunctionsException(
            code: 'permission-denied' || 'unauthenticated'
          ) =>
            'Your Admin session could not save assignments. Sign in again and retry.',
          _ =>
            'Could not verify the saved assignments. Refresh the schedule before retrying.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 12),
          showCloseIcon: true,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(
    CoachAvailabilityContext schedule,
    CoachAvailabilityDay day,
    DatedCoachWindow? original,
  ) async {
    if (_saving || !widget.isCurrent()) return;
    final assigned = schedule.assignedBranchIds
        .where((id) =>
            widget.branchRequest == null || _branchNames.containsKey(id))
        .toList();
    if (assigned.isEmpty) return;
    var branch = original?.branchId ?? _branch ?? assigned.first;
    if (!assigned.contains(branch)) {
      branch = assigned.first;
    }
    int? start = original?.startAtMillis, end = original?.endAtMillis;
    final replacement = await showDialog<List<DatedCoachWindow>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
              '${original == null ? 'Add availability' : 'Edit availability'} · ${day.localDate}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: branch,
              decoration: const InputDecoration(labelText: 'Branch'),
              items: [
                for (final id in assigned)
                  DropdownMenuItem(value: id, child: Text(_name(id)))
              ],
              onChanged: (value) {
                if (value != null) update(() => branch = value);
              },
            ),
            for (final isStart in [true, false])
              DropdownButtonFormField<int>(
                initialValue: isStart ? start : end,
                decoration:
                    InputDecoration(labelText: isStart ? 'Start' : 'End'),
                items: [
                  for (final time in day.boundaries)
                    DropdownMenuItem(
                        value: time.atMillis, child: Text(time.label))
                ],
                onChanged: (value) => update(() {
                  if (isStart) {
                    start = value;
                  } else {
                    end = value;
                  }
                }),
              ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            if (original != null)
              TextButton(
                onPressed: () => Navigator.pop(
                    context,
                    day.windows
                        .where((window) => !identical(window, original))
                        .toList()),
                child: const Text('Remove'),
              ),
            FilledButton(
              onPressed: start == null || end == null || start! >= end!
                  ? null
                  : () => Navigator.pop(context, [
                        ...day.windows
                            .where((window) => !identical(window, original)),
                        DatedCoachWindow(
                            branchId: branch,
                            startAtMillis: start!,
                            endAtMillis: end!),
                      ]),
              child: const Text('Save availability'),
            ),
          ],
        ),
      ),
    );
    if (replacement == null || !mounted || !widget.isCurrent()) return;
    setState(() => _saving = true);
    final random = Random.secure();
    final requestId = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    try {
      await widget.repository.save(
        baseline: day,
        context: schedule,
        windows: replacement,
        requestId: requestId,
      );
      if (mounted && widget.isCurrent()) _load(schedule.days.first.localDate);
    } catch (error) {
      if (mounted && widget.isCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is CoachAvailabilityException
              ? error.message
              : 'Could not save availability.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Coach schedule'), actions: [
        if (widget.branchRequest != null)
          TextButton(
            onPressed: _saving ? null : _editAssignments,
            child: const Text('Edit assigned branches'),
          ),
        IconButton(
            tooltip: 'Refresh schedule',
            onPressed: () {
              roster = null;
              _loadBranchNames();
              _load();
            },
            icon: const Icon(Icons.refresh))
      ]),
      body: FutureBuilder<CoachAvailabilityContext>(
          future: future,
          builder: (context, snapshot) {
            if (!widget.isCurrent()) {
              return const Center(
                  child: Text('Schedule unavailable for this session.'));
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text('Coach schedule unavailable. Refresh to retry.'));
            }
            final data = snapshot.data!;
            final branches = [...data.assignedBranchIds]..sort();
            final branchFilter = branches.contains(_branch) ? _branch : null;
            if (roster == null) _loadRoster();
            final first = data.days.first.localDate;
            final next = DateTime.parse('${first}T00:00:00Z')
                .add(const Duration(days: 7))
                .toIso8601String()
                .substring(0, 10);
            final through = DateTime.parse('${data.todayLocalDate}T00:00:00Z')
                .add(const Duration(days: 30))
                .toIso8601String()
                .substring(0, 10);
            return PageBody(children: [
              if (widget.initialLocalDate != null &&
                  _manageableInitialDate == null)
                const Text(
                    'Past availability is shown in the calendar. Manage schedules from today onward.'),
              Text('Organization time: ${data.timeZone}'),
              Text('Assigned branches: ${branches.map(_name).join(', ')}'),
              if (branches.isNotEmpty)
                DropdownButton<String>(
                  value: branchFilter ?? '',
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('All branches')),
                    for (final branch in branches)
                      DropdownMenuItem(
                          value: branch, child: Text(_name(branch))),
                  ],
                  onChanged: (branch) =>
                      setState(() => _branch = branch == '' ? null : branch),
                ),
              if (roster != null)
                FutureBuilder<CoachRosterSnapshot>(
                    future: roster,
                    builder: (context, snapshot) {
                      if (!widget.isCurrent()) return const SizedBox.shrink();
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return const Text(
                            'Roster details unavailable. Refresh to retry.');
                      }
                      final schedule = snapshot.data!,
                          weekly = schedule.weeklyAvailability;
                      return Panel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Eyebrow('Roster scheduling limits'),
                            DetailRow(
                                'Maximum bookable hours per day',
                                weekly == null
                                    ? '-'
                                    : '${weekly.dailyCapacityHours} hours'),
                            DetailRow(
                                'Advance booking window',
                                weekly == null
                                    ? '-'
                                    : '${weekly.advanceBookingWindowDays} days'),
                            const SizedBox(height: 12),
                            const Eyebrow('Recurring working hours'),
                            if (weekly == null)
                              const Text('-')
                            else
                              for (final day in weekly.schedule)
                                DetailRow(
                                    [
                                      'Mon',
                                      'Tue',
                                      'Wed',
                                      'Thu',
                                      'Fri',
                                      'Sat',
                                      'Sun'
                                    ][day.dayOfWeek - 1],
                                    day.isActive
                                        ? '${_minutes(day.startMinute)} – ${_minutes(day.endMinute)} · ${day.branchId}'
                                        : 'Off'),
                            const SizedBox(height: 12),
                            const Eyebrow('Time off and breaks'),
                            if (schedule.exceptions.isEmpty)
                              const Text('No blocked time exceptions.')
                            else
                              for (final block in schedule.exceptions)
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                        '${block.startLabel ?? _utc(block.startAtMillis)} – ${block.endLabel ?? _utc(block.endAtMillis)}'),
                                    subtitle: Text(block.reason.isEmpty
                                        ? '-'
                                        : block.reason)),
                          ]));
                    }),
              if (_saving) const LinearProgressIndicator(),
              Row(children: [
                TextButton(
                    onPressed: first == data.todayLocalDate
                        ? null
                        : () {
                            final previous =
                                DateTime.parse('${first}T00:00:00Z')
                                    .subtract(const Duration(days: 7))
                                    .toIso8601String()
                                    .substring(0, 10);
                            _load(previous.compareTo(data.todayLocalDate) < 0
                                ? data.todayLocalDate
                                : previous);
                          },
                    child: const Text('Previous 7 days')),
                TextButton(
                    onPressed:
                        next.compareTo(through) > 0 ? null : () => _load(next),
                    child: const Text('Next 7 days'))
              ]),
              for (final day in data.days) ...[
                Text(day.localDate,
                    style: Theme.of(context).textTheme.titleMedium),
                if (day.editable &&
                    day.boundaries.isNotEmpty &&
                    branches.isNotEmpty)
                  TextButton(
                    onPressed: _saving ? null : () => _edit(data, day, null),
                    child: const Text('Add availability'),
                  ),
                if (!day.windows.any(
                    (w) => branchFilter == null || w.branchId == branchFilter))
                  const Text('No permitted availability windows.'),
                for (final w in day.windows.where(
                    (w) => branchFilter == null || w.branchId == branchFilter))
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${day.labelFor(w.startAtMillis)} – ${day.labelFor(w.endAtMillis)}'),
                      subtitle: Wrap(
                          children: [Chip(label: Text(_name(w.branchId)))]),
                      trailing: day.editable && day.boundaries.isNotEmpty
                          ? IconButton(
                              tooltip: 'Edit availability',
                              onPressed:
                                  _saving ? null : () => _edit(data, day, w),
                              icon: const Icon(Icons.edit_outlined),
                            )
                          : null)
              ],
            ]);
          }));
}

String _minutes(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
String _utc(int value) =>
    '${DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toIso8601String()} UTC';
