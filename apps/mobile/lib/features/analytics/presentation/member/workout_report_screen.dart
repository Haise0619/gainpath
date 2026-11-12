import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../domain/member_workout_report.dart';
import '../../domain/local_member_progress_repository.dart';
import 'widgets/workout_report_overview.dart';
import '../../domain/workout_activity_overview.dart';
import '../../../workout/domain/routine_attempt.dart';

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
      this.initialFilter,
      this.error,
      this.onOpenWorkout,
      this.onOpenRoutine});
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;
  final void Function(String)? onOpenRoutine;
  final SessionScope scope;
  final WorkoutReportFilter? initialFilter;
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
      widget.initialFilter ?? WorkoutReportFilter.lastDays(widget.asOf, 30);
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

  Widget _activity(MemberWorkoutReport report) {
    final events = overviewWorkoutEvents(report);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Workout activity (${events.length})',
          style: Theme.of(context).textTheme.titleLarge),
      const Text('Newest first · tap a workout to review exercises',
          style: TextStyle(color: AppColors.inkSoft)),
      const SizedBox(height: 8),
      for (final event in events.take(_visible))
        if (event.kind == WorkoutTimelineKind.routine)
          _routineActivity(report, event)
        else
          ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading:
                  const Icon(Icons.videocam_outlined, color: AppColors.primary),
              title: Text(event.title),
              subtitle: Text(
                  '${event.dateTimeLabel} MYT\nAI Tracked · ${event.detail.split(' · Estimated Form Score').first}'),
              trailing: widget.onOpenWorkout == null
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpenWorkout == null
                  ? null
                  : () => widget.onOpenWorkout!(report.sessions
                      .firstWhere((s) => s.sessionId == event.id))),
      if (events.length > _visible)
        TextButton(
            onPressed: () => setState(() => _visible += 20),
            child: const Text('Show 20 more workouts')),
    ]);
  }

  Widget _routineActivity(
      MemberWorkoutReport report, WorkoutReportTimelineEntry event) {
    final row = report.routines.firstWhere((r) => r.attempt.id == event.id);
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: ExpansionTile(
            expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                ? AnimationStyle.noAnimation
                : const AnimationStyle(duration: Duration(milliseconds: 180)),
            key: PageStorageKey(
                'report-workout-${event.id}-${_filter.exerciseId}'),
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(event.title),
            subtitle: Text(
                '${event.dateTimeLabel} MYT\n${routineActivitySummary(row.attempt, entries: row.entries)}'),
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                      'Whole workout: ${row.attempt.statusLabel} · ${row.attempt.completedExercises}/${row.attempt.entries.length} exercises complete${_filter.exerciseId == null ? '' : '\nExercise breakdown is filtered.'}')),
              for (final e in row.entries)
                ListTile(
                    title: Text(row.attempt.routine.exercises[e.index].name),
                    subtitle: Text(_exerciseResult(e))),
              for (final capture in report.sessions.where((s) =>
                  row.entries.any((e) => e.sessionIds.contains(s.sessionId))))
                ListTile(
                    title: Text(
                        'View ${report.exerciseName(capture.exerciseId)} result'),
                    subtitle: Text(
                        '${reportDate(capture.endedAt)} · ${capture.repetitions} full reps'),
                    trailing: widget.onOpenWorkout == null
                        ? null
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onOpenWorkout == null
                        ? null
                        : () => widget.onOpenWorkout!(capture)),
              if (widget.onOpenRoutine != null)
                TextButton(
                    onPressed: () => widget.onOpenRoutine!(event.id),
                    child: const Text('Open workout record')),
            ]));
  }

  String _exerciseResult(RoutineExerciseResult entry) {
    if (entry.isTimed && entry.guided != null) {
      return 'Video Timed · ${entry.guided!.completedSets} sets · ${reportDuration(entry.guided!.totalActiveMicroseconds)} active';
    }
    if (entry.sessionIds.isNotEmpty) {
      return 'AI Tracked · ${entry.fullRepetitions} full reps · ${entry.partialRepetitions} partial attempts';
    }
    if (entry.manualSets > 0 ||
        entry.status == RoutineExerciseStatus.selfReportedCompleted ||
        entry.status == RoutineExerciseStatus.selfReportedPartial) {
      return 'Manual · ${entry.manualSets} user-recorded sets';
    }
    return switch (entry.status) {
      RoutineExerciseStatus.skipped => 'Skipped · no activity recorded',
      RoutineExerciseStatus.instructionsReviewed =>
        'Instructions reviewed · no activity recorded',
      RoutineExerciseStatus.notStarted => 'Not started · no activity recorded',
      _ => 'Recorded result details unavailable',
    };
  }

  Widget _assessment(MemberWorkoutReport report, int i) {
    final group = report.formGroups[i];
    final chart = report.formCharts[i];
    return ExpansionTile(
        expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(duration: Duration(milliseconds: 180)),
        key: PageStorageKey('report-assessment-$i-${_filter.exerciseId}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(chart.label),
        subtitle: Text(group.meanScore == null
            ? progressFormLabel(group.records.first)
            : '${group.meanScore!.toStringAsFixed(1)}% estimated form · ${group.scoredAttempts} scored attempts'),
        children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'An estimate of recorded movements, not an overall workout score. Missing assessments are unavailable, never 0%.'),
                    Text(
                        '${group.scoredAttempts} scored / ${group.unassessedAttempts} unassessed attempts'),
                    if (chart.points.where((p) => p.score != null).length >
                        1) ...[
                      const SizedBox(height: 8),
                      const Text(
                          'Recorded captures · Malaysia time · gaps mean unassessed'),
                      SizedBox(
                          height: 180,
                          child: SfCartesianChart(
                              primaryXAxis: CategoryAxis(
                                  labelStyle: const TextStyle(
                                      fontFamily: 'Barlow', fontSize: 12),
                                  labelRotation: -45,
                                  axisLabelFormatter: (args) => ChartAxisLabel(
                                      chart.points
                                          .firstWhere((p) => p.key == args.text)
                                          .date,
                                      args.textStyle)),
                              primaryYAxis: NumericAxis(
                                  minimum: 0,
                                  maximum: 100,
                                  labelStyle: const TextStyle(
                                      fontFamily: 'Barlow', fontSize: 12)),
                              series: <CartesianSeries<WorkoutReportFormPoint,
                                  String>>[
                                LineSeries(
                                    dataSource: chart.points,
                                    xValueMapper: (d, _) => d.key,
                                    yValueMapper: (d, _) => d.score,
                                    emptyPointSettings:
                                        const EmptyPointSettings(
                                            mode: EmptyPointMode.gap),
                                    color: AppColors.primary,
                                    animationDuration: 0,
                                    markerSettings:
                                        const MarkerSettings(isVisible: true))
                              ])),
                    ],
                    for (final capture in group.records)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${reportDate(capture.endedAt)} · ${progressFormLabel(capture)}'),
                          trailing: widget.onOpenWorkout == null
                              ? null
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: widget.onOpenWorkout == null
                              ? null
                              : () => widget.onOpenWorkout!(capture)),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        key: PageStorageKey(
                            'report-assessment-method-$i-${group.scoringVersion}'),
                        title: const Text('Assessment details'),
                        children: [
                          Text(
                              '${group.scoringVersion} · ${group.detectorId}/${group.detectorVersion} · ${group.cameraView}'),
                          const Text(
                              'Attempt-weighted within compatible exercise, scoring version, detector, camera view and arm-mode groups. Different methods remain separate.')
                        ]),
                  ]))
        ]);
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
        backgroundColor: AppColors.bg,
        appBar: AppBar(
            toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
            title: const Text('Training Report', maxLines: 2, softWrap: true),
            bottom: PreferredSize(
                preferredSize: Size.fromHeight(
                    MediaQuery.textScalerOf(context).scale(1) >= 1.8 ? 96 : 48),
                child: Wrap(alignment: WrapAlignment.end, children: [
                  IconButton(
                      tooltip: 'Filter report',
                      onPressed: report == null || _saving
                          ? null
                          : () => _filters(report),
                      icon: const Icon(Icons.tune_rounded)),
                  Tooltip(
                      message: 'Export PDF',
                      child: TextButton.icon(
                          label: const Text('Export PDF'),
                          onPressed: report == null || _saving || widget.loading
                              ? null
                              : () => _export(report),
                          icon: const Icon(Icons.picture_as_pdf_outlined))),
                ]))),
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
                          if (widget.error != null)
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(widget.error!),
                                trailing: TextButton(
                                    onPressed: widget.onRefresh,
                                    child: const Text('Retry'))),
                          Text(_filter.dateLabel,
                              style: Theme.of(context).textTheme.titleMedium),
                          const Text('Malaysia time · UTC+08:00',
                              style: TextStyle(color: AppColors.inkSoft)),
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
                            if (_filter.routineId != null ||
                                _filter.exerciseId != null ||
                                _filter.dateLabel !=
                                    WorkoutReportFilter.lastDays(
                                            widget.asOf, 30)
                                        .dateLabel)
                              TextButton(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() {
                                            _filter =
                                                WorkoutReportFilter.lastDays(
                                                    widget.asOf, 30);
                                            _visible = 20;
                                          }),
                                  child: const Text('Reset filters'))
                          ]),
                          for (final warning in report.warnings)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(warning,
                                    style: const TextStyle(
                                        color: AppColors.warning))),
                          const SizedBox(height: 16),
                          if (report.sessions.isEmpty &&
                              report.routines.isEmpty)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child:
                                    Text('No activity matches these filters.')),
                          WorkoutReportOverview(report: report),
                          if (_filter.exerciseId != null)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                    'Activity shows the selected exercise. Completed workouts still require the whole workout’s targets.')),
                          if (!report.routineHistoryAvailable)
                            const Text(
                                'Routine history unavailable. Timed and manual totals are unavailable.'),
                          const SizedBox(height: 20),
                          _activity(report),
                          const SizedBox(height: 16),
                          const Eyebrow('AI form assessments'),
                          const Text(
                              'Recorded estimates for supported AI exercises. Timed and manual activity is not scored.'),
                          if (report.formGroups.isEmpty)
                            const Text(
                                'No recorded form assessments in this period.'),
                          for (var i = 0; i < report.formGroups.length; i++)
                            _assessment(report, i),
                          const SizedBox(height: 20),
                          ExpansionTile(
                              key: const PageStorageKey(
                                  'report-technical-details'),
                              title: const Text('Technical details'),
                              children: [
                                ExpansionTile(
                                    key: const PageStorageKey(
                                        'report-camera-evidence'),
                                    title: Text(
                                        'Camera session details (${report.sessions.length})'),
                                    children: [
                                      for (final s
                                          in report.sessions.take(_visible))
                                        ListTile(
                                            title: Text(report
                                                .exerciseName(s.exerciseId)),
                                            subtitle: Text(
                                                '${reportDate(s.endedAt)} · ${s.repetitions} full · ${s.partialRepetitions} partial\n'
                                                '${reportDuration(s.trackedDurationMicros)} tracked · ${workoutAcceptanceLabel(s)}\n${s.sessionId}')),
                                      if (report.sessions.length > _visible)
                                        TextButton(
                                            onPressed: () =>
                                                setState(() => _visible += 20),
                                            child: const Text(
                                                'Show 20 more sessions'))
                                    ]),
                                const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                        'Saved AI measurements are provisional. Workout acceptance is separate from Cloud Backup and rewards. Completed workouts count completed sessions, including multiple sessions on one day. Workout elapsed time is not active exercise time. Manual sets come from matching saved records.')),
                                if (report.unknownCompletionDays > 0)
                                  Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                          '${report.unknownCompletionDays} completed workout(s) have no recorded completion date.')),
                                for (final r in report.routines.take(_visible))
                                  ListTile(
                                      title: Text(
                                          'Workout record: ${r.attempt.id}'),
                                      subtitle: Text(
                                          '${r.dateBasis}: ${reportDate(r.activityAt)} · ${r.attempt.statusLabel}')),
                              ]),
                          const SizedBox(height: 8),
                          const Text(
                              'PDF includes every matching row, the selected filters and chart data.'),
                        ])));
  }
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
            Text('Filter Training Report',
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
