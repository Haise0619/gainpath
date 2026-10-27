import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/admin_workout_reporting.dart';

class AdminWorkoutAnalytics extends StatefulWidget {
  const AdminWorkoutAnalytics(
      {super.key,
      required this.query,
      this.compact = false,
      this.refreshToken = 0,
      this.anchorKey});
  final AdminReportQuery query;
  final bool compact;
  final int refreshToken;
  final GlobalKey? anchorKey;
  @override
  State<AdminWorkoutAnalytics> createState() => _AdminWorkoutAnalyticsState();
}

class _AdminWorkoutAnalyticsState extends State<AdminWorkoutAnalytics> {
  AdminWorkoutReportingCubit? _cubit;
  bool _weekly = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gateway = context.read<AdminReportingGateway>();
    if (gateway is AdminWorkoutReportingGateway &&
        !identical(_cubit?.gateway, gateway)) {
      _cubit?.close();
      _cubit = AdminWorkoutReportingCubit(
          gateway: gateway as AdminWorkoutReportingGateway, query: widget.query)
        ..load();
    }
  }

  @override
  void didUpdateWidget(AdminWorkoutAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query ||
        widget.refreshToken != oldWidget.refreshToken) {
      _cubit?.load(widget.query);
    }
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cubit == null) return const SizedBox.shrink();
    return BlocBuilder<AdminWorkoutReportingCubit, AdminWorkoutReportingState>(
        bloc: _cubit,
        builder: (context, state) {
          final report = state.report;
          final controls = Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Chip(
                    label: Text('Provisional backups'),
                    visualDensity: VisualDensity.compact),
                IconButton(
                    tooltip: 'Refresh workout analytics',
                    onPressed: state.loading ? null : () => _cubit!.load(),
                    icon: const Icon(Icons.refresh_rounded)),
                if (widget.compact)
                  IconButton(
                      tooltip: 'Export workout CSV',
                      onPressed: report == null
                          ? null
                          : () => downloadCsv(
                              'gainpath-workout-activity.csv', report.toCsv()),
                      icon: const Icon(Icons.download_rounded)),
              ]);
          final content = state.loading
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(children: [
                    SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Expanded(child: Text('Loading workout analytics…'))
                  ]))
              : report == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(state.error ??
                              'Workout analytics is unavailable.'),
                          TextButton.icon(
                              onPressed: () => _cubit!.load(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry workout analytics'))
                        ])
                  : _data(context, report);
          if (widget.compact) {
            return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Workout activity',
                          style: Theme.of(context).textTheme.titleMedium),
                      controls,
                      const SizedBox(height: 10),
                      content
                    ])));
          }
          return ReportSection(
              anchorKey: widget.anchorKey ?? _fallbackAnchor,
              title: 'Workout activity',
              subtitle:
                  'Saved device measurements and routine-day progress · organization-wide',
              live: true,
              tagLabel: 'Provisional backups',
              exportFilename: 'gainpath-workout-activity.csv',
              exportEnabled: report != null,
              exportRows: report?.toCsv,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [controls, const SizedBox(height: 10), content]));
        });
  }

  final _fallbackAnchor = GlobalKey();
  Widget _data(BuildContext context, AdminWorkoutReport r) {
    final t = r.totals, text = Theme.of(context).textTheme;
    Widget stat(String value, String label) => SizedBox(
        width: widget.compact ? 175 : 210, child: StatTile(value, label));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        stat('${t.sessions}', 'Saved camera sessions'),
        stat('${t.completedRoutineDays}', 'Completed routine days'),
        stat('${t.fullReps}', 'Measured full reps'),
        stat(_duration(t.trackedMicros), 'Tracked duration'),
        if (!widget.compact) ...[
          stat('${t.partialReps}', 'Measured partial reps'),
          stat('${t.manualSets}', 'Manual sets')
        ],
      ]),
      const SizedBox(height: 12),
      Text(
          '${r.coverage['membersWithBackups']} / ${r.coverage['activeMembers']} current active Members have backup records · '
          '${r.coverage['membersWithActivity']} with activity in range.',
          style: text.bodySmall),
      const SizedBox(height: 6),
      Text(
          'Backup coverage only. Missing or device-only workouts are excluded. Counts are provisional; manual sets are self-reported. Backup presence does not mean backup is currently enabled.',
          style: text.bodySmall),
      if (t.sessions == 0 && t.routineAttempts == 0)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('No backed-up workout activity in this date range.')),
      if (widget.compact) ...[
        const SizedBox(height: 8),
        Text(
            '${t.inProgressRoutineDays} in progress · ${t.partialRoutineDays} finished incomplete · ${t.unknownCompletionDays} completion dates unknown',
            style: text.bodySmall),
      ] else ...[
        const SizedBox(height: 20),
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Workout activity trend', style: text.titleMedium),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: const Text('Daily'),
                selected: !_weekly,
                onSelected: (_) => setState(() => _weekly = false)),
            ChoiceChip(
                label: const Text('Weekly'),
                selected: _weekly,
                onSelected: (_) => setState(() => _weekly = true))
          ]),
          if (r.daily.isNotEmpty)
            _trend(r.trend(weekly: _weekly))
          else
            const NoFilteredData(message: 'No activity dates to chart.'),
          Text(
              _weekly
                  ? 'Weeks start Monday; boundary weeks include only the selected date range.'
                  : 'Malaysia calendar dates with recorded activity. Gaps have no backed-up activity.',
              style: text.bodySmall),
        ])),
        const SizedBox(height: 14),
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Routine-day progress', style: text.titleMedium),
          for (final e in <String, int>{
            'Completed': t.completedRoutineDays,
            'Finished incomplete': t.partialRoutineDays,
            'In progress': t.inProgressRoutineDays,
            'Completion date unknown': t.unknownCompletionDays
          }.entries)
            ProgressRow(
                e.key,
                t.routineAttempts == 0 ? 0 : e.value / t.routineAttempts,
                '${e.value}'),
          Text(
              'Completion is device-reported and requires all day targets, including manual targets. Routine dates use finish time, or last update when unfinished/unknown. Resuming can move a record between periods. Sessions use end time and are counted once, separately from routine summaries.',
              style: text.bodySmall),
        ])),
        const SizedBox(height: 14),
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Most-used exercises', style: text.titleMedium),
          Text(
              'Ranked by saved camera sessions. Snapshot names may differ from the current catalog. Top ${r.exercises.length > 10 ? 10 : r.exercises.length} of ${r.exercises.length}; CSV includes all.',
              style: text.bodySmall),
          for (final e in r.exercises.take(10))
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name, style: text.titleSmall),
                      Text(
                          '${e.sessions} camera sessions · ${e.fullReps} full / ${e.partialReps} partial reps · ${_duration(e.trackedMicros)} tracked · ${e.manualSets} manual sets',
                          style: text.bodySmall),
                    ])),
          if (r.exercises.isEmpty)
            const Text('No measured sessions or manual sets in range.'),
        ])),
        const SizedBox(height: 14),
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Estimated form by compatible version', style: text.titleMedium),
          Text(
              'Mean of scored session estimates within each exercise/rule/model/view/arm group. No platform-wide accuracy or clinical assessment is inferred.',
              style: text.bodySmall),
          for (final f in r.forms)
            ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                    '${f.average.toStringAsFixed(1)}% · ${f.scoredSessions} scored sessions'),
                subtitle: Text(f.label, softWrap: true),
                children: [
                  for (final d in f.daily)
                    ListTile(
                        dense: true,
                        title: Text(d.date),
                        subtitle: Text(
                            '${d.average.toStringAsFixed(1)}% · ${d.count} scored sessions'))
                ]),
          if (r.forms.isEmpty)
            const Text('No compatible scored measurements in range.'),
        ])),
        const SizedBox(height: 12),
        Text(
            'Latest backups only; archived revisions are excluded. Current active Member census is not historical attendance. Source scan ${r.scanStartedAt.toUtc().toIso8601String()} to ${r.capturedAt.toUtc().toIso8601String()}; these bounded reads are not one atomic snapshot.',
            style: text.bodySmall),
      ],
    ]);
  }

  Widget _trend(List<WorkoutReportDay> days) => SizedBox(
      height: 250,
      child: SfCartesianChart(
          plotAreaBorderWidth: 0,
          primaryXAxis: const CategoryAxis(
              majorGridLines: MajorGridLines(width: 0),
              labelIntersectAction: AxisLabelIntersectAction.rotate45),
          primaryYAxis: const NumericAxis(minimum: 0, decimalPlaces: 0),
          legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              overflowMode: LegendItemOverflowMode.wrap),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <CartesianSeries<WorkoutReportDay, String>>[
            ColumnSeries<WorkoutReportDay, String>(
                name: 'Camera sessions',
                dataSource: days,
                xValueMapper: (d, _) => d.date,
                yValueMapper: (d, _) => d.sessions,
                color: AppColors.primary),
            ColumnSeries<WorkoutReportDay, String>(
                name: 'Completed routine days',
                dataSource: days,
                xValueMapper: (d, _) => d.date,
                yValueMapper: (d, _) => d.totals.completedRoutineDays,
                color: AppColors.success),
          ]));
}

String _duration(int micros) {
  final seconds = micros ~/ 1000000;
  return '${seconds ~/ 60}m ${seconds % 60}s';
}
