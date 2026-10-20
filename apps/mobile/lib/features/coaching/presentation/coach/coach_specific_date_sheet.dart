import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_availability_cubit.dart';

/// Modal bottom sheet for editing advanced date-specific availability overrides.
class CoachSpecificDateSheet extends StatefulWidget {
  const CoachSpecificDateSheet({
    super.key,
    required this.repository,
    required this.coachId,
    required this.isCurrent,
    this.initialDate,
    this.onSaved,
  });

  final CoachAvailabilityRepository repository;
  final String coachId;
  final bool Function() isCurrent;
  final String? initialDate;
  final VoidCallback? onSaved;

  @override
  State<CoachSpecificDateSheet> createState() => _CoachSpecificDateSheetState();
}

class _CoachSpecificDateSheetState extends State<CoachSpecificDateSheet> {
  late final controller = CoachAvailabilityCubit(
    repository: widget.repository,
    coachId: widget.coachId,
    isCurrent: widget.isCurrent,
  )..loadWeek(firstLocalDate: widget.initialDate);

  String? _editingDay, _branch;
  int? _editingIndex, _start, _end;

  String _shift(String date, int days) => DateTime.parse('${date}T00:00:00Z')
      .add(Duration(days: days))
      .toIso8601String()
      .substring(0, 10);

  Future<void> _close() async {
    if (controller.state.loading || controller.state.saving) return;
    if (controller.state.dirty || _editingDay != null) {
      final discard = await confirmSheet(context,
          title: 'Discard unsaved changes?',
          message: 'Your date changes have not been saved.',
          confirmLabel: 'Discard changes');
      if (!discard || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

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

  Widget _editor(CoachAvailabilityState state, bool enabled) {
    final boundaries = state.day!.boundaries;
    return Panel(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _branch,
            decoration: const InputDecoration(labelText: 'Branch'),
            items: state.context!.assignedBranchIds
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: enabled ? (b) => setState(() => _branch = b!) : null,
          ),
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
                : null,
          ),
          DropdownButtonFormField<int>(
            key: ValueKey((_start, _end)),
            initialValue: _end,
            decoration: const InputDecoration(labelText: 'End'),
            items: boundaries
                .where((b) => b.atMillis > _start!)
                .map((b) =>
                    DropdownMenuItem(value: b.atMillis, child: Text(b.label)))
                .toList(),
            onChanged: enabled ? (v) => setState(() => _end = v!) : null,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _editingDay = null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: enabled
                    ? () {
                        final value = DatedCoachWindow(
                          branchId: _branch!,
                          startAtMillis: _start!,
                          endAtMillis: _end!,
                        );
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
                child: Text(_editingIndex == null ? 'Add' : 'Update'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CoachAvailabilityCubit, CoachAvailabilityState>(
      bloc: controller,
      builder: (context, state) {
        final data = state.context,
            day = state.day,
            busy = state.loading || state.saving;
        final canEdit = !busy && !state.conflict && day?.editable == true;
        final editing = _editingDay != null;

        return PopScope(
          canPop: !busy && !state.dirty && !editing,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _close();
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit specific date',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: busy ? null : _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (data != null)
                    Text(
                      'Organization time: ${data.timeZone}. Specific date windows replace your recurring weekly hours for this day.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (busy) const LinearProgressIndicator(),
                  if (state.message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.message!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  if (data != null && day != null) ...[
                    const SizedBox(height: 16),
                    Wrap(children: [
                      TextButton(
                          onPressed: busy ||
                                  editing ||
                                  state.dirty ||
                                  state.conflict ||
                                  data.days.first.localDate
                                          .compareTo(data.todayLocalDate) <=
                                      0
                              ? null
                              : () {
                                  final prior =
                                      _shift(data.days.first.localDate, -7);
                                  controller.loadWeek(
                                      firstLocalDate:
                                          prior.compareTo(data.todayLocalDate) <
                                                  0
                                              ? data.todayLocalDate
                                              : prior);
                                },
                          child: const Text('Previous 7 days')),
                      TextButton(
                          onPressed: busy ||
                                  editing ||
                                  state.dirty ||
                                  state.conflict ||
                                  data.writableThroughLocalDate == null ||
                                  _shift(data.days.first.localDate, 7)
                                          .compareTo(
                                              data.writableThroughLocalDate!) >
                                      0
                              ? null
                              : () => controller.loadWeek(
                                  firstLocalDate:
                                      _shift(data.days.first.localDate, 7)),
                          child: const Text('Next 7 days')),
                    ]),
                    if (state.conflict || state.dirty)
                      TextButton(
                          onPressed: busy || editing
                              ? null
                              : () => controller.loadWeek(
                                  firstLocalDate: data.days.first.localDate,
                                  discard: true),
                          child: const Text('Discard and reload')),
                    DropdownButtonFormField<String>(
                      key: ValueKey((data, day.localDate)),
                      initialValue: day.localDate,
                      decoration:
                          const InputDecoration(labelText: 'Select date'),
                      items: data.days
                          .map((d) => DropdownMenuItem(
                              value: d.localDate, child: Text(d.localDate)))
                          .toList(),
                      onChanged: busy || editing
                          ? null
                          : (v) => controller.openDay(v!),
                    ),
                    const SizedBox(height: 12),
                    if (day.reviewRequired)
                      const Text(
                        'Legacy schedule is read-only and requires authorized review.',
                      ),
                    if (state.windows.isEmpty && !editing)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No availability windows for this date.'),
                      ),
                    for (final entry in state.windows.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Panel(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${day.labelFor(entry.$2.startAtMillis)} – ${day.labelFor(entry.$2.endAtMillis)}',
                            ),
                            subtitle: Text(entry.$2.branchId),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: ValueKey('edit-window-${entry.$1}'),
                                  tooltip: 'Edit window',
                                  onPressed: canEdit && !editing
                                      ? () => _window(state, index: entry.$1)
                                      : null,
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  key: ValueKey('remove-window-${entry.$1}'),
                                  tooltip: 'Remove window',
                                  onPressed: canEdit && !editing
                                      ? () {
                                          final next =
                                              List<DatedCoachWindow>.of(
                                                  state.windows)
                                                ..removeAt(entry.$1);
                                          controller.setWindows(next);
                                        }
                                      : null,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_editingDay == day.localDate) _editor(state, canEdit),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              canEdit && !editing && state.windows.length < 16
                                  ? () => _window(state)
                                  : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Add window'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: canEdit && !editing && state.dirty
                              ? () async {
                                  await controller.save();
                                  if (context.mounted &&
                                      !controller.state.dirty) {
                                    widget.onSaved?.call();
                                    Navigator.pop(context);
                                  }
                                }
                              : null,
                          child: const Text('Save day'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
