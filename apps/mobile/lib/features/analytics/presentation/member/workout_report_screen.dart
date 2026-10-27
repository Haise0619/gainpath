import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../domain/member_workout_report.dart';
import '../../domain/local_member_progress_repository.dart';

class WorkoutReportScreen extends StatefulWidget {
  const WorkoutReportScreen(
      {super.key,
      required this.scope,
      required this.source,
      required this.asOf,
      required this.exporter,
      required this.isCurrent,
      required this.onRefresh,
      this.loading = false,
      this.error});
  final SessionScope scope;
  final LocalMemberProgressSnapshot? source;
  final DateTime asOf;
  final WorkoutReportExporter exporter;
  final bool Function() isCurrent;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String? error;
  @override
  State<WorkoutReportScreen> createState() => _WorkoutReportScreenState();
}

class _WorkoutReportScreenState extends State<WorkoutReportScreen> {
  late WorkoutReportFilter _filter =
      WorkoutReportFilter.lastDays(widget.asOf, 30);
  bool _saving = false;
  int _visible = 20;
  @override
  void dispose() {
    unawaited(widget.exporter.cancel());
    super.dispose();
  }

  Future<void> _export(MemberWorkoutReport report) async {
    if (_saving || !widget.isCurrent()) return;
    setState(() => _saving = true);
    // Capture this exact filter/result snapshot before opening the destination picker.
    final document = report.toDocument();
    try {
      final saved = await widget.exporter.save(document);
      if (!mounted || !widget.isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(saved ? 'PDF saved' : 'Export cancelled'),
          action: saved
              ? SnackBarAction(
                  label: 'Open',
                  onPressed: () async {
                    if (!widget.isCurrent()) return;
                    try {
                      final opened = await widget.exporter.open();
                      if (!opened && mounted && widget.isCurrent()) {
                        _message('No PDF viewer is available.');
                      }
                    } catch (_) {
                      if (mounted && widget.isCurrent()) {
                        _message('No PDF viewer is available.');
                      }
                    }
                  })
              : null));
    } catch (_) {
      if (mounted && widget.isCurrent()) {
        _message('PDF could not be saved. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _filters(MemberWorkoutReport report) async {
    final selected = await showModalBottomSheet<WorkoutReportFilter>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => _ReportFilters(report: report));
    if (selected != null && mounted && widget.isCurrent()) {
      setState(() {
        _filter = selected;
        _visible = 20;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final report = source == null
        ? null
        : MemberWorkoutReport.build(
            scope: widget.scope,
            source: source,
            filter: _filter,
            asOf: widget.asOf);
    return Scaffold(
        appBar: AppBar(title: const Text('Workout report'), actions: [
          IconButton(
              tooltip: 'Filter report',
              onPressed:
                  report == null || _saving ? null : () => _filters(report),
              icon: const Icon(Icons.tune_rounded)),
          IconButton(
              tooltip: 'Export PDF',
              onPressed: report == null || _saving || widget.loading
                  ? null
                  : () => _export(report),
              icon: const Icon(Icons.picture_as_pdf_outlined)),
        ]),
        body: !widget.isCurrent()
            ? const Center(
                child: Text('Sign in to view this account’s report.'))
            : report == null
                ? Center(
                    child: widget.loading
                        ? const CircularProgressIndicator()
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(widget.error ?? 'Workout report unavailable.'),
                            FilledButton(
                                onPressed: widget.onRefresh,
                                child: const Text('Retry'))
                          ]))
                : RefreshIndicator(
                    onRefresh: widget.onRefresh,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16, 12, 16,
                            24 + MediaQuery.paddingOf(context).bottom),
                        children: [
                          if (widget.loading || _saving)
                            const LinearProgressIndicator(),
                          Text(_filter.dateLabel,
                              style: Theme.of(context).textTheme.titleMedium),
                          const Text('Malaysia dates · UTC+08:00'),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            if (_filter.routineId != null)
                              Chip(
                                  label: Text(
                                      report.routineNames[_filter.routineId] ??
                                          _filter.routineId!)),
                            if (_filter.exerciseId != null)
                              Chip(
                                  label: Text(report
                                      .exerciseName(_filter.exerciseId!))),
                            TextButton(
                                onPressed: _saving
                                    ? null
                                    : () => setState(() {
                                          _filter = WorkoutReportFilter.all();
                                          _visible = 20;
                                        }),
                                child: const Text('Reset filters'))
                          ]),
                          const Text(
                              'Saved measurements are provisional. Self-reported sets are shown separately.'),
                          for (final warning in report.warnings)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(warning,
                                    style: const TextStyle(
                                        color: AppColors.warning))),
                          const SizedBox(height: 16),
                          LayoutBuilder(builder: (context, c) {
                            final columns = c.maxWidth >= 520 &&
                                    MediaQuery.textScalerOf(context).scale(14) <
                                        19
                                ? 3
                                : 2;
                            final width =
                                (c.maxWidth - (columns - 1) * 8) / columns;
                            return Wrap(spacing: 8, runSpacing: 8, children: [
                              _metric('Camera sessions',
                                  '${report.sessions.length}', width),
                              _metric('Full reps', '${report.fullReps}', width),
                              _metric('Partial attempts',
                                  '${report.partialReps}', width),
                              _metric('Tracked time',
                                  reportDuration(report.trackedMicros), width),
                              _metric(
                                  'Completed routine days',
                                  report.completedRoutineDays?.toString() ??
                                      'Unavailable',
                                  width),
                              _metric(
                                  'Self-reported sets',
                                  report.manualSets?.toString() ??
                                      'Unavailable',
                                  width),
                            ]);
                          }),
                          const SizedBox(height: 8),
                          const Text(
                              'Routine completion requires the whole day’s targets. Manual sets reflect matching saved routine snapshots.'),
                          if (report.unknownCompletionDays > 0)
                            Text(
                                '${report.unknownCompletionDays} completed routine day(s) have no known completion date.'),
                          if (!report.routineHistoryAvailable)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('Routine history unavailable')),
                          if (report.sessions.isEmpty &&
                              report.routines.isEmpty)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child:
                                    Text('No activity matches these filters.')),
                          if (report.days.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Eyebrow('Measured repetitions'),
                            SizedBox(
                                height: 230,
                                child: SfCartesianChart(
                                    primaryXAxis:
                                        CategoryAxis(labelRotation: -45),
                                    primaryYAxis: NumericAxis(minimum: 0),
                                    legend: const Legend(
                                        isVisible: true,
                                        position: LegendPosition.bottom),
                                    tooltipBehavior:
                                        TooltipBehavior(enable: true),
                                    series: <CartesianSeries<WorkoutReportDay,
                                        String>>[
                                      ColumnSeries(
                                          dataSource: report.days,
                                          xValueMapper: (d, _) => d.date,
                                          yValueMapper: (d, _) => d.fullReps,
                                          name: 'Full reps',
                                          color: AppColors.primary,
                                          animationDuration: 0),
                                      ColumnSeries(
                                          dataSource: report.days,
                                          xValueMapper: (d, _) => d.date,
                                          yValueMapper: (d, _) => d.partialReps,
                                          name: 'Partial attempts',
                                          color: AppColors.warning,
                                          animationDuration: 0),
                                    ])),
                          ],
                          const SizedBox(height: 16),
                          const Eyebrow('Estimated form'),
                          const Text(
                              'Each exercise, rule, model and camera view is kept separate. Estimates are weighted by scored attempts.'),
                          if (report.formGroups.isEmpty)
                            const Text('No estimated form available.'),
                          for (var i = 0;
                              i < report.formGroups.length;
                              i++) ...[
                            const SizedBox(height: 12),
                            Text(report.formCharts[i].label,
                                style: Theme.of(context).textTheme.titleSmall),
                            Text(
                                '${report.formGroups[i].meanScore?.toStringAsFixed(1) ?? 'Unavailable'}${report.formGroups[i].meanScore == null ? '' : '%'} · '
                                '${report.formGroups[i].scoredAttempts} scored / ${report.formGroups[i].unassessedAttempts} unassessed attempts'),
                            if (report.formCharts[i].points.isNotEmpty)
                              SizedBox(
                                  height: 180,
                                  child: SfCartesianChart(
                                      primaryXAxis:
                                          CategoryAxis(labelRotation: -45),
                                      primaryYAxis:
                                          NumericAxis(minimum: 0, maximum: 100),
                                      series: <CartesianSeries<
                                          WorkoutReportFormPoint, String>>[
                                        LineSeries(
                                            dataSource:
                                                report.formCharts[i].points,
                                            xValueMapper: (d, _) => d.date,
                                            yValueMapper: (d, _) => d.score,
                                            color: AppColors.primary,
                                            animationDuration: 0,
                                            markerSettings:
                                                const MarkerSettings(
                                                    isVisible: true))
                                      ])),
                          ],
                          const SizedBox(height: 20),
                          ExpansionTile(
                              title: Text(
                                  'Camera session details (${report.sessions.length})'),
                              children: [
                                for (final s in report.sessions.take(_visible))
                                  ListTile(
                                      title: Text(
                                          report.exerciseName(s.exerciseId)),
                                      subtitle: Text(
                                          '${reportDate(s.endedAt)} · ${s.repetitions} full · ${s.partialRepetitions} partial\n'
                                          '${reportDuration(s.trackedDurationMicros)} tracked · ${s.status.name}\n${s.sessionId}')),
                                if (report.sessions.length > _visible)
                                  TextButton(
                                      onPressed: () =>
                                          setState(() => _visible += 20),
                                      child:
                                          const Text('Show 20 more sessions'))
                              ]),
                          ExpansionTile(
                              title: Text(
                                  'Routine attempts (${report.routines.length})'),
                              children: [
                                for (final r in report.routines.take(_visible))
                                  ListTile(
                                      title: Text(
                                          '${r.attempt.routine.title} · Day ${r.attempt.day}'),
                                      subtitle: Text(
                                          '${r.attempt.statusLabel} · ${r.attempt.completedExercises}/${r.attempt.entries.length} exercises\n'
                                          '${r.dateBasis}: ${reportDate(r.activityAt)}\n${r.manualSets} self-reported sets in selection')),
                                if (report.routines.length > _visible)
                                  TextButton(
                                      onPressed: () =>
                                          setState(() => _visible += 20),
                                      child:
                                          const Text('Show 20 more attempts'))
                              ]),
                          const SizedBox(height: 8),
                          const Text(
                              'PDF includes every matching row, the selected filters and chart data.'),
                        ])));
  }

  Widget _metric(String label, String value, double width) => SizedBox(
      width: width,
      child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(label)
                  ]))));
}

class _ReportFilters extends StatefulWidget {
  const _ReportFilters({required this.report});
  final MemberWorkoutReport report;
  @override
  State<_ReportFilters> createState() => _ReportFiltersState();
}

class _ReportFiltersState extends State<_ReportFilters> {
  late DateTime? _start = widget.report.filter.startDay,
      _end = widget.report.filter.endDay;
  late String? _routine =
      widget.report.routineNames.containsKey(widget.report.filter.routineId)
          ? widget.report.filter.routineId
          : null;
  late String? _exercise =
      widget.report.exerciseNames.containsKey(widget.report.filter.exerciseId)
          ? widget.report.filter.exerciseId
          : null;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter workout report',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final days in [7, 30])
                OutlinedButton(
                    onPressed: () => setState(() {
                          final f = WorkoutReportFilter.lastDays(
                              widget.report.asOf, days);
                          _start = f.startDay;
                          _end = f.endDay;
                        }),
                    child: Text('Last $days days')),
              OutlinedButton(
                  onPressed: () => setState(() {
                        _start = null;
                        _end = null;
                      }),
                  child: const Text('All time')),
            ]),
            OutlinedButton.icon(
                icon: const Icon(Icons.date_range_outlined),
                label: Text(_start == null
                    ? 'Choose date range'
                    : WorkoutReportFilter(startDay: _start, endDay: _end)
                        .dateLabel),
                onPressed: () async {
                  final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(1970),
                      lastDate: DateTime(2100),
                      initialDateRange: _start == null || _end == null
                          ? null
                          : DateTimeRange(start: _start!, end: _end!));
                  if (range != null && mounted) {
                    setState(() {
                      _start = range.start;
                      _end = range.end;
                    });
                  }
                }),
            const SizedBox(height: 12),
            _dropdown(
                'Routine',
                const ValueKey('report-routine-filter'),
                _routine,
                widget.report.routineNames,
                (v) => setState(() => _routine = v)),
            const SizedBox(height: 12),
            _dropdown(
                'Exercise',
                const ValueKey('report-exercise-filter'),
                _exercise,
                widget.report.exerciseNames,
                (v) => setState(() => _exercise = v)),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: () => Navigator.pop(
                    context,
                    WorkoutReportFilter(
                        startDay: _start,
                        endDay: _end,
                        routineId: _routine,
                        exerciseId: _exercise)),
                child: const Text('Apply filters')),
          ]));
  Widget _dropdown(String label, Key key, String? value,
      Map<String, String> names, ValueChanged<String?> changed) {
    final sorted = names.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return DropdownButtonFormField<String>(
        key: key,
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem<String>(
              value: null, child: Text('All ${label.toLowerCase()}s')),
          for (final e in sorted)
            DropdownMenuItem(
                value: e.key,
                child:
                    Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis))
        ],
        onChanged: changed);
  }
}
