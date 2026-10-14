import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_availability_cubit.dart';

class LiveCoachAvailabilityView extends StatefulWidget {
  const LiveCoachAvailabilityView(
      {super.key,
      required this.repository,
      required this.coachId,
      required this.isCurrent});
  final CoachAvailabilityRepository repository;
  final String coachId;
  final bool Function() isCurrent;
  @override
  State<LiveCoachAvailabilityView> createState() =>
      _LiveCoachAvailabilityViewState();
}

class _LiveCoachAvailabilityViewState extends State<LiveCoachAvailabilityView> {
  late final controller = CoachAvailabilityCubit(
      repository: widget.repository,
      coachId: widget.coachId,
      isCurrent: widget.isCurrent)
    ..loadWeek();
  String? _editingDay, _branch;
  int? _editingIndex, _start, _end;
  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  void _window(CoachAvailabilityState state, {int? index}) {
    final day = state.day!,
        boundaries = day.boundaries,
        branches = state.context!.assignedBranchIds;
    if (boundaries.length < 2) return;
    final old = index == null ? null : state.windows[index];
    setState(() {
      _editingDay = day.localDate;
      _editingIndex = index;
      _branch = old?.branchId ?? branches.first;
      _start = old?.startAtMillis ?? boundaries.first.atMillis;
      _end = old?.endAtMillis ?? boundaries[1].atMillis;
    });
  }

  void _reload() {
    setState(() => _editingDay = null);
    controller.discardAndReload();
  }

  Widget _editor(CoachAvailabilityState state, bool enabled) {
    final boundaries = state.day!.boundaries;
    return Panel(
        child: Column(children: [
      DropdownButtonFormField<String>(
          initialValue: _branch,
          decoration: const InputDecoration(labelText: 'Branch'),
          items: state.context!.assignedBranchIds
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: enabled ? (b) => setState(() => _branch = b!) : null),
      DropdownButtonFormField<int>(
          initialValue: _start,
          decoration: const InputDecoration(labelText: 'Start'),
          items: boundaries
              .take(boundaries.length - 1)
              .map((b) =>
                  DropdownMenuItem(value: b.atMillis, child: Text(b.label)))
              .toList(),
          onChanged: enabled
              ? (v) => setState(() {
                    _start = v!;
                    if (_end! <= _start!) {
                      _end = boundaries
                          .firstWhere((b) => b.atMillis > _start!)
                          .atMillis;
                    }
                  })
              : null),
      DropdownButtonFormField<int>(
          key: ValueKey((_start, _end)),
          initialValue: _end,
          decoration: const InputDecoration(labelText: 'End'),
          items: boundaries
              .where((b) => b.atMillis > _start!)
              .map((b) =>
                  DropdownMenuItem(value: b.atMillis, child: Text(b.label)))
              .toList(),
          onChanged: enabled ? (v) => setState(() => _end = v!) : null),
      Row(children: [
        TextButton(
            onPressed: () => setState(() => _editingDay = null),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: enabled
                ? () {
                    final value = DatedCoachWindow(
                        branchId: _branch!,
                        startAtMillis: _start!,
                        endAtMillis: _end!);
                    final next = List<DatedCoachWindow>.of(state.windows);
                    if (_editingIndex == null) {
                      next.add(value);
                    } else {
                      next[_editingIndex!] = value;
                    }
                    controller.setWindows(next);
                    setState(() => _editingDay = null);
                  }
                : null,
            child: Text(_editingIndex == null ? 'Add' : 'Update'))
      ]),
    ]));
  }

  String _shift(String date, int days) => DateTime.parse('${date}T00:00:00Z')
      .add(Duration(days: days))
      .toIso8601String()
      .substring(0, 10);
  @override
  Widget build(BuildContext context) => BlocBuilder<CoachAvailabilityCubit,
          CoachAvailabilityState>(
      bloc: controller,
      builder: (context, state) {
        if (!widget.isCurrent()) {
          return const Center(
              child: Text('Schedule unavailable for this session.'));
        }
        final data = state.context,
            day = state.day,
            busy = state.loading || state.saving;
        final canEdit = !busy && !state.conflict && day?.editable == true;
        final editing = _editingDay != null;
        return Scaffold(
            appBar: AppBar(title: const Text('Availability'), actions: [
              IconButton(
                  tooltip: 'Discard and reload',
                  onPressed: busy ? null : _reload,
                  icon: const Icon(Icons.refresh))
            ]),
            body: PageBody(children: [
              if (busy) const LinearProgressIndicator(),
              if (state.message != null) Text(state.message!),
              if (data != null && day != null) ...[
                Text('Organization time: ${data.timeZone}'),
                Text(
                    'Edit ${data.writableFromLocalDate} through ${data.writableThroughLocalDate}. Today is read-only.'),
                Row(children: [
                  TextButton(
                      onPressed: busy ||
                              editing ||
                              data.days.first.localDate == data.todayLocalDate
                          ? null
                          : () {
                              final prior =
                                  _shift(data.days.first.localDate, -7);
                              controller.loadWeek(
                                  firstLocalDate:
                                      prior.compareTo(data.todayLocalDate) < 0
                                          ? data.todayLocalDate
                                          : prior);
                            },
                      child: const Text('Previous 7 days')),
                  TextButton(
                      onPressed: busy ||
                              editing ||
                              _shift(data.days.first.localDate, 7).compareTo(
                                      data.writableThroughLocalDate!) >
                                  0
                          ? null
                          : () => controller.loadWeek(
                              firstLocalDate:
                                  _shift(data.days.first.localDate, 7)),
                      child: const Text('Next 7 days')),
                ]),
                DropdownButtonFormField<String>(
                    key: ValueKey((data, day.localDate)),
                    initialValue: day.localDate,
                    decoration: const InputDecoration(labelText: 'Date'),
                    items: data.days
                        .map((d) => DropdownMenuItem(
                            value: d.localDate, child: Text(d.localDate)))
                        .toList(),
                    onChanged:
                        busy || editing ? null : (v) => controller.openDay(v!)),
                if (day.reviewRequired)
                  const Text(
                      'Legacy schedule is read-only and requires authorized review.'),
                if (state.windows.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No availability windows for this date.')),
                for (final entry in state.windows.indexed)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          '${day.labelFor(entry.$2.startAtMillis)} – ${day.labelFor(entry.$2.endAtMillis)}'),
                      subtitle: Text(entry.$2.branchId),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            tooltip: 'Edit window',
                            onPressed: canEdit && !editing
                                ? () => _window(state, index: entry.$1)
                                : null,
                            icon: const Icon(Icons.edit_outlined)),
                        IconButton(
                            tooltip: 'Remove window',
                            onPressed: canEdit && !editing
                                ? () {
                                    final next =
                                        List<DatedCoachWindow>.of(state.windows)
                                          ..removeAt(entry.$1);
                                    controller.setWindows(next);
                                  }
                                : null,
                            icon: const Icon(Icons.delete_outline))
                      ])),
                if (_editingDay == day.localDate) _editor(state, canEdit),
                OutlinedButton.icon(
                    onPressed: canEdit && !editing && state.windows.length < 16
                        ? () => _window(state)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add window')),
                FilledButton(
                    onPressed: canEdit && !editing && state.dirty
                        ? controller.save
                        : null,
                    child: const Text('Save day')),
                TextButton(
                    onPressed: busy ? null : _reload,
                    child: const Text('Discard and reload')),
                const Text(
                    'Saving an empty day removes its windows. Reserved intervals must be preserved.'),
              ],
            ]));
      });
}
