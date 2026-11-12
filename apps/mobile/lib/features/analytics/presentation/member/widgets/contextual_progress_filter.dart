import 'package:flutter/material.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../domain/member_workout_report.dart';

/// Uses the combined report's Malaysia date semantics, applied in place.
class ContextualProgressFilter extends StatefulWidget {
  const ContextualProgressFilter(
      {super.key,
      required this.progress,
      this.builder,
      this.reportBuilder,
      this.exerciseChoices = const {},
      this.onExport,
      this.showDisabledExport = false,
      this.compact = false});
  final MemberLocalProgress progress;
  final Map<String, String> exerciseChoices;
  final void Function(WorkoutReportFilter)? onExport;
  final bool showDisabledExport;
  final bool compact;
  final Widget Function(MemberLocalProgress)? builder;
  final Widget Function(MemberLocalProgress, WorkoutReportFilter)?
      reportBuilder;
  @override
  State<ContextualProgressFilter> createState() =>
      _ContextualProgressFilterState();
}

class _ContextualProgressFilterState extends State<ContextualProgressFilter> {
  int? _days = 30;
  String? _exercise;
  @override
  void didUpdateWidget(covariant ContextualProgressFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.scope != widget.progress.scope) {
      _days = 30;
      _exercise = null;
    }
    if (_exercise != null &&
        !widget.exerciseChoices.containsKey(_exercise) &&
        !widget.progress.records.any((r) => r.exerciseId == _exercise)) {
      _exercise = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.progress;
    final filter = _days == null
        ? WorkoutReportFilter.all()
        : WorkoutReportFilter.lastDays(source.asOf, _days!);
    final filtered = calculateLocalMemberProgress(
        scope: source.scope,
        asOf: source.asOf,
        utcOffset: source.utcOffset,
        records: source.records.where((r) =>
            filter.includes(r.endedAt) &&
            (_exercise == null || r.exerciseId == _exercise)));
    final ids = {
      ...source.records.map((r) => r.exerciseId),
      ...widget.exerciseChoices.keys
    }.toList()
      ..sort();

    final hasCustomFilters = _days != 30 || _exercise != null;

    if (widget.compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final days in <int?>[30, 7, null])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    days == null ? 'All time' : 'Last $days days',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          _days == days ? FontWeight.w600 : FontWeight.normal,
                      color: _days == days ? Colors.white : AppColors.ink,
                    ),
                  ),
                  selected: _days == days,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceAlt,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                    color: _days == days
                        ? AppColors.primary
                        : AppColors.hairline,
                  ),
                  onSelected: (_) => setState(() => _days = days),
                ),
              ),
            Container(
              height: 20,
              width: 1,
              color: AppColors.hairline,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      _exercise != null ? AppColors.primary : AppColors.hairline,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: ValueKey((source.scope, _exercise)),
                  value: ids.contains(_exercise) ? _exercise : null,
                  isDense: true,
                  hint: const Text('All exercises',
                      style: TextStyle(fontSize: 12)),
                  style: const TextStyle(fontSize: 12, color: AppColors.ink),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null,
                        child:
                            Text('All exercises', style: TextStyle(fontSize: 12))),
                    for (final id in ids)
                      DropdownMenuItem(
                          value: id,
                          child: Text(
                              widget.exerciseChoices[id] ??
                                  reportExerciseLabel(id),
                              style: const TextStyle(fontSize: 12)))
                  ],
                  onChanged: (value) => setState(() => _exercise = value),
                ),
              ),
            ),
            if (widget.onExport != null || widget.showDisabledExport)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconButton(
                  key: const ValueKey('progress-export-pdf'),
                  tooltip: 'Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  onPressed: widget.onExport == null
                      ? null
                      : () => widget.onExport!(WorkoutReportFilter(
                          startDay: filter.startDay,
                          endDay: filter.endDay,
                          exerciseId: _exercise)),
                ),
              ),
            if (hasCustomFilters)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.surfaceAlt,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: const BorderSide(color: AppColors.hairline),
                  onPressed: () => setState(() {
                    _days = 30;
                    _exercise = null;
                  }),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(
          '${filtered.records.length} captures · ${filter.dateLabel}',
          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 12),
        if (widget.reportBuilder != null)
          widget.reportBuilder!(
              filtered,
              WorkoutReportFilter(
                  startDay: filter.startDay,
                  endDay: filter.endDay,
                  exerciseId: _exercise))
        else
          widget.builder!(filtered),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, children: [
        for (final days in <int?>[7, 30, null])
          ChoiceChip(
              label: Text(days == null ? 'All time' : 'Last $days days'),
              selected: _days == days,
              onSelected: (_) => setState(() => _days = days)),
      ]),
      DropdownButtonFormField<String>(
          key: ValueKey((source.scope, _exercise)),
          initialValue: ids.contains(_exercise) ? _exercise : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Exercise'),
          items: [
            const DropdownMenuItem<String>(
                value: null, child: Text('All exercises')),
            for (final id in ids)
              DropdownMenuItem(
                  value: id,
                  child: Text(
                      widget.exerciseChoices[id] ?? reportExerciseLabel(id)))
          ],
          onChanged: (value) => setState(() => _exercise = value)),
      Text(
          '${filtered.records.length} captures · ${filter.dateLabel} · Malaysia time'),
      if (widget.onExport != null || widget.showDisabledExport)
        Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
                message: 'Export',
                child: TextButton.icon(
                    key: const ValueKey('progress-export-pdf'),
                    label: const Text('Export PDF'),
                    onPressed: widget.onExport == null
                        ? null
                        : () => widget.onExport!(WorkoutReportFilter(
                            startDay: filter.startDay,
                            endDay: filter.endDay,
                            exerciseId: _exercise)),
                    icon: const Icon(Icons.picture_as_pdf_outlined)))),
      const SizedBox(height: 16),
      if (widget.reportBuilder != null)
        widget.reportBuilder!(
            filtered,
            WorkoutReportFilter(
                startDay: filter.startDay,
                endDay: filter.endDay,
                exerciseId: _exercise))
      else
        widget.builder!(filtered),
    ]);
  }
}
