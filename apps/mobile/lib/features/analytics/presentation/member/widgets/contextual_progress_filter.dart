import 'package:flutter/material.dart';
import 'package:gainpath_domain/analytics.dart';
import '../../../domain/member_workout_report.dart';

/// Uses the combined report's Malaysia date semantics, applied in place.
class ContextualProgressFilter extends StatefulWidget {
  const ContextualProgressFilter(
      {super.key,
      required this.progress,
      required this.builder,
      this.onExport,
      this.showDisabledExport = false});
  final MemberLocalProgress progress;
  final void Function(WorkoutReportFilter)? onExport;
  final bool showDisabledExport;
  final Widget Function(MemberLocalProgress) builder;
  @override
  State<ContextualProgressFilter> createState() =>
      _ContextualProgressFilterState();
}

class _ContextualProgressFilterState extends State<ContextualProgressFilter> {
  int? _days;
  String? _exercise;
  @override
  void didUpdateWidget(covariant ContextualProgressFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.scope != widget.progress.scope) {
      _days = null;
      _exercise = null;
    }
    if (_exercise != null &&
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
    final ids = source.records.map((r) => r.exerciseId).toSet().toList()
      ..sort();
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
              DropdownMenuItem(value: id, child: Text(reportExerciseLabel(id)))
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
      widget.builder(filtered),
    ]);
  }
}
