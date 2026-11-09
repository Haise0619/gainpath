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
    this.initialContext,
    this.onSaved,
    this.branchNames = const {},
  });

  final CoachAvailabilityRepository repository;
  final String coachId;
  final bool Function() isCurrent;
  final String? initialDate;
  final CoachAvailabilityContext? initialContext;
  final VoidCallback? onSaved;
  final Map<String, String> branchNames;

  @override
  State<CoachSpecificDateSheet> createState() => _CoachSpecificDateSheetState();
}

class _CoachSpecificDateSheetState extends State<CoachSpecificDateSheet> {
  late final controller = CoachAvailabilityCubit(
    repository: widget.repository,
    coachId: widget.coachId,
    isCurrent: widget.isCurrent,
  );

  @override
  void initState() {
    super.initState();
    final cached = widget.initialContext;
    if (cached != null &&
        cached.coachId == widget.coachId &&
        cached.days.isNotEmpty) {
      controller.useCachedContext(cached, date: widget.initialDate);
    } else {
      controller.loadWeek(firstLocalDate: widget.initialDate);
    }
  }

  String? _editingDay, _branch;
  int? _editingIndex, _start, _end;

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
      final lastEnd = state.windows.isEmpty
          ? null
          : state.windows
              .map((w) => w.endAtMillis)
              .reduce((a, b) => a > b ? a : b);
      _start = old?.startAtMillis ??
          (lastEnd != null && lastEnd < boundaries.last.atMillis
              ? lastEnd
              : boundaries.first.atMillis);
      _end = old?.endAtMillis ??
          boundaries.firstWhere((b) => b.atMillis > _start!).atMillis;
    });
  }

  Widget _editor(CoachAvailabilityState state, bool enabled) {
    final boundaries = state.day!.boundaries;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.primarySoft.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _editingIndex == null
                    ? Icons.add_circle_outline_rounded
                    : Icons.edit_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _editingIndex == null
                    ? 'New Time Window'
                    : 'Edit Time Window',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _branch,
            decoration: InputDecoration(
              labelText: 'Branch',
              prefixIcon: const Icon(Icons.location_on_outlined,
                  size: 18, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.surface,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: state.context!.assignedBranchIds
                .map((b) => DropdownMenuItem(
                    value: b, child: Text(widget.branchNames[b] ?? b)))
                .toList(),
            onChanged: enabled ? (b) => setState(() => _branch = b!) : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _start,
                  decoration: InputDecoration(
                    labelText: 'Start Time',
                    prefixIcon: const Icon(Icons.schedule_rounded,
                        size: 18, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: boundaries
                      .take(boundaries.length - 1)
                      .map((b) => DropdownMenuItem(
                          value: b.atMillis, child: Text(b.label)))
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey((_start, _end)),
                  initialValue: _end,
                  decoration: InputDecoration(
                    labelText: 'End Time',
                    prefixIcon: const Icon(Icons.schedule_rounded,
                        size: 18, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: boundaries
                      .where((b) => b.atMillis > _start!)
                      .map((b) => DropdownMenuItem(
                          value: b.atMillis, child: Text(b.label)))
                      .toList(),
                  onChanged: enabled ? (v) => setState(() => _end = v!) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _editingDay = null),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
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
                icon: Icon(_editingIndex == null ? Icons.add : Icons.check,
                    size: 16),
                label:
                    Text(_editingIndex == null ? 'Add Window' : 'Update Window'),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          'Edit Day Hours',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: busy ? null : _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  if (busy) const LinearProgressIndicator(),
                  if (state.message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.message!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],

                  if (data != null && day != null) ...[
                    const SizedBox(height: 10),

                    // Dedicated Date Banner Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _readableDate(day.localDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Changes to this date only',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Overrides recurring weekly schedule',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Standalone week navigation (only rendered when initialDate is omitted)
                    if (widget.initialDate == null) ...[
                      const SizedBox(height: 8),
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
                      DropdownButtonFormField<String>(
                        key: ValueKey((data, day.localDate)),
                        initialValue: day.localDate,
                        decoration:
                            const InputDecoration(labelText: 'Select date'),
                        items: data.days
                            .map((d) => DropdownMenuItem(
                                value: d.localDate,
                                child: Text(_readableDate(d.localDate))))
                            .toList(),
                        onChanged: busy || editing
                            ? null
                            : (v) => controller.openDay(v!),
                      ),
                    ],

                    if (state.conflict || state.dirty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextButton.icon(
                          onPressed: busy || editing
                              ? null
                              : () => controller.loadWeek(
                                  firstLocalDate: data.days.first.localDate,
                                  discard: true),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Discard and reload'),
                        ),
                      ),

                    const SizedBox(height: 12),
                    if (day.reviewRequired)
                      const Text(
                        'Legacy schedule is read-only and requires authorized review.',
                      ),

                    // Empty State
                    if (state.windows.isEmpty && !editing)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.event_available_outlined,
                                size: 36,
                                color:
                                    AppColors.inkSoft.withValues(alpha: 0.6)),
                            const SizedBox(height: 8),
                            const Text(
                              'No custom hours for this date',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add custom time windows below to override your weekly hours.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),

                    // Time Windows List
                    for (final entry in state.windows.indexed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.schedule_rounded,
                                  size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${day.labelFor(entry.$2.startAtMillis)} – ${day.labelFor(entry.$2.endAtMillis)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.branchNames[entry.$2.branchId] ??
                                        entry.$2.branchId,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: ValueKey('edit-window-${entry.$1}'),
                              tooltip: 'Edit window',
                              onPressed: canEdit && !editing
                                  ? () => _window(state, index: entry.$1)
                                  : null,
                              icon: const Icon(Icons.edit_outlined, size: 20),
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
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: AppColors.danger),
                            ),
                          ],
                        ),
                      ),

                    if (_editingDay == day.localDate) _editor(state, canEdit),

                    const SizedBox(height: 14),

                    // Actions Bar
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: canEdit &&
                                    !editing &&
                                    state.windows.length < 16
                                ? () => _window(state)
                                : null,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add window'),
                          ),
                        ),
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
