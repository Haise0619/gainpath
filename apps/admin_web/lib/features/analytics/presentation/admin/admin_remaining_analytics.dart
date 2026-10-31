import 'admin_report_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/admin_check_in_reporting.dart';
import '../../application/admin_observed_activity.dart';
import '../../application/admin_workout_reporting.dart';
import '../../application/admin_commerce_report.dart';

class AdminObservedSection extends StatefulWidget {
  const AdminObservedSection(
      {super.key,
      required this.query,
      required this.anchorKey,
      this.retention = false,
      this.refreshToken = 0});
  final AdminReportQuery query;
  final GlobalKey anchorKey;
  final bool retention;
  final int refreshToken;
  @override
  State<AdminObservedSection> createState() => _AdminObservedSectionState();
}

class _AdminObservedSectionState extends State<AdminObservedSection> {
  AdminCheckInReportingCubit? _cubit;
  bool _weekly = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final g = context.read<AdminReportingGateway>();
    if (g is AdminCheckInReportingGateway && !identical(_cubit?.gateway, g)) {
      _cubit?.close();
      _cubit = AdminCheckInReportingCubit(
          gateway: g as AdminCheckInReportingGateway, query: widget.query)
        ..load();
    }
  }

  @override
  void didUpdateWidget(AdminObservedSection old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query || widget.refreshToken != old.refreshToken) {
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
    if (_cubit == null) {
      return _section(
          null, const Text('Recorded activity reporting is unavailable.'));
    }
    return BlocBuilder<AdminCheckInReportingCubit, AdminCheckInReportingState>(
        bloc: _cubit,
        builder: (context, s) {
          final r = s.report?.observations;
          return _section(
              r,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (s.loading) const LinearProgressIndicator(),
                if (s.error != null) Text(s.error!),
                if (r == null && s.error == null)
                  Text(s.error ??
                      (s.loading
                          ? 'Loading recorded activity…'
                          : 'Recorded activity analytics awaits compatible server activation.')),
                if (r == null || s.error != null)
                  TextButton(
                      onPressed: () => _cubit!.load(),
                      child: const Text('Retry activity report')),
                if (r != null) _data(r)
              ]));
        });
  }

  Widget _section(AdminObservedActivity? r, Widget child) => ReportSection(
      anchorKey: widget.anchorKey,
      title: widget.retention
          ? 'Recorded engagement & returning Members'
          : 'Platform Usage Pattern',
      subtitle: widget.retention
          ? 'Explainable observed recency · no predictive dropout score'
          : 'Observable events · not full app usage or gym attendance',
      live: true,
      tagLabel: r == null ? 'Unavailable' : 'Recorded activity',
      exportFilename: widget.retention
          ? 'recorded-engagement.csv'
          : 'observable-activity.csv',
      exportEnabled: r != null,
      exportRows: r == null
          ? null
          : () => r.csv(retention: widget.retention, weeklyView: _weekly),
      child: child);
  Widget _data(AdminObservedActivity r) {
    final periods = _weekly ? r.weekly : r.daily;
    Widget stat(String label, String value) =>
        SizedBox(width: 210, child: StatTile(value, label));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        stat('Current Member cohort', '${r.cohort}'),
        if (widget.retention) ...[
          stat('Observed within 7 days', '${r.recency['within7Days']}'),
          stat('No observed activity / unknown',
              '${r.recency['noObservedActivity']}')
        ] else
          for (final e in r.sources.entries)
            stat(AdminObservedActivity.sourceLabels[e.key]!, '${e.value}')
      ]),
      const SizedBox(height: 12),
      Text(
          'Observation cutoff: ${r.asOf.toUtc().add(const Duration(hours: 8)).toIso8601String().replaceFirst('T', ' ').substring(0, 16)} Malaysia time. Current canonical active Members only.'),
      const AdminReportDetails(
          child: Text(
              'Recorded check-ins, booking creation, server game starts and backed-up camera captures only. Missing backups or local-only activity do not prove inactivity. No login frequency or physical attendance telemetry.')),
      const SizedBox(height: 16),
      if (widget.retention) ...[
        SizedBox(
            height: 230,
            child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(
                    labelIntersectAction: AxisLabelIntersectAction.wrap),
                primaryYAxis: const NumericAxis(minimum: 0, decimalPlaces: 0),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<MapEntry<String, int>, String>>[
                  BarSeries<MapEntry<String, int>, String>(
                      dataSource: r.recency.entries.toList(),
                      xValueMapper: (e, _) => const {
                            'within7Days': '0–6 days',
                            'days8To30': '7–29 days',
                            'over30Days': '30+ days',
                            'noObservedActivity': 'Unobserved'
                          }[e.key],
                      yValueMapper: (e, _) => e.value,
                      color: AppColors.primary)
                ])),
        for (final e in r.recency.entries)
          ListTile(
              dense: true,
              title: Text(AdminObservedActivity.recencyLabels[e.key]!),
              trailing: Text('${e.value}')),
        const SizedBox(height: 10),
        Text('Returning Members',
            style: Theme.of(context).textTheme.titleMedium),
        Text(r.returning['available'] == true
            ? '${r.returning['returningMembers']} returning / ${r.returning['previousMembers']} observed in preceding period · ${r.returning['ratePercent'] == null ? 'rate unavailable' : '${(r.returning['ratePercent'] as num).toStringAsFixed(1)}%'}'
            : 'Select a closed date range with a supported preceding period to compare returning Members.'),
        Text(
            'Current period: ${r.returning['currentMembers']} observed Members. Return rate = Members observed in both equal-duration periods / observed Members in the preceding period. Recency is not a probability of dropout.'),
      ] else ...[
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
        if (periods.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Text('No observed events in this date range.'))
        else
          SizedBox(
              height: 260,
              child: SfCartesianChart(
                  primaryXAxis: const DateTimeAxis(),
                  primaryYAxis: const NumericAxis(minimum: 0, decimalPlaces: 0),
                  legend: const Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                      overflowMode: LegendItemOverflowMode.wrap),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries<ObservedDay, DateTime>>[
                    for (final key in AdminObservedActivity.sourceLabels.keys)
                      ColumnSeries<ObservedDay, DateTime>(
                          color: adminReportPalette[AdminObservedActivity
                                  .sourceLabels.keys
                                  .toList()
                                  .indexOf(key) %
                              adminReportPalette.length],
                          name: AdminObservedActivity.sourceLabels[key],
                          dataSource: periods,
                          xValueMapper: (d, _) =>
                              DateTime.parse('${d.date}T00:00:00Z'),
                          yValueMapper: (d, _) => d[key])
                  ])),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(columns: [
              DataColumn(
                  label:
                      Text(_weekly ? 'Week starting Monday' : 'Malaysia date')),
              for (final label in AdminObservedActivity.sourceLabels.values)
                DataColumn(label: Text(label)),
              const DataColumn(label: Text('Unique Members'))
            ], rows: [
              for (final d in periods)
                DataRow(cells: [
                  DataCell(Text(d.date)),
                  for (final key in AdminObservedActivity.sourceLabels.keys)
                    DataCell(Text('${d[key]}')),
                  DataCell(Text('${d['uniqueMembers']}'))
                ])
            ])),
        const Text(
            'Weeks start Monday; boundary weeks contain selected dates only. Distinct Members are deduplicated within each period and must not be summed across days.'),
      ]
    ]);
  }
}

class AdminPostureSection extends StatefulWidget {
  const AdminPostureSection(
      {super.key,
      required this.query,
      required this.anchorKey,
      this.refreshToken = 0});
  final AdminReportQuery query;
  final GlobalKey anchorKey;
  final int refreshToken;
  @override
  State<AdminPostureSection> createState() => _AdminPostureSectionState();
}

class _FormPoint {
  const _FormPoint(this.date, this.score, this.samples);
  final DateTime date;
  final double? score;
  final int samples;
}

class _AdminPostureSectionState extends State<AdminPostureSection> {
  AdminWorkoutReportingCubit? _cubit;
  String? _exercise, _version;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final g = context.read<AdminReportingGateway>();
    if (g is AdminWorkoutReportingGateway && !identical(_cubit?.gateway, g)) {
      _cubit?.close();
      _cubit = AdminWorkoutReportingCubit(
          gateway: g as AdminWorkoutReportingGateway, query: widget.query)
        ..load();
    }
  }

  @override
  void didUpdateWidget(AdminPostureSection old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query || widget.refreshToken != old.refreshToken) {
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
        builder: (context, s) {
          final r = s.report;
          final ids = r?.forms.map((f) => f.exerciseId).toSet().toList() ?? [];
          final selected =
              ids.contains(_exercise) ? _exercise : ids.firstOrNull;
          final groups =
              r?.forms.where((f) => f.exerciseId == selected).toList() ?? [];
          final group = groups.where((f) => f.label == _version).firstOrNull ??
              groups.firstOrNull;
          final points = group == null ? <_FormPoint>[] : _points(r!, group);
          return ReportSection(
              anchorKey: widget.anchorKey,
              title: 'Estimated Form Score Trend',
              subtitle:
                  'Provisional session estimates · not validated biomechanical accuracy',
              live: true,
              tagLabel: 'Provisional backups',
              exportFilename: 'estimated-form-scores.csv',
              exportEnabled: r != null,
              exportRows: r == null
                  ? null
                  : () => [
                        [
                          'GainPath Estimated Form Scores',
                          'Provisional; not validated accuracy'
                        ],
                        [
                          'Start inclusive UTC',
                          widget.query.range.start.toUtc().toIso8601String()
                        ],
                        [
                          'End exclusive UTC',
                          widget.query.range.end.toUtc().toIso8601String()
                        ],
                        ['Timezone', 'Asia/Kuala_Lumpur'],
                        ['Exercise', selected ?? 'Unavailable'],
                        [
                          'Compatible group',
                          _safeCsv(group?.label ?? 'Unavailable')
                        ],
                        ['Saved camera captures', r.totals.sessions],
                        [
                          'Scored samples in selected group',
                          group?.scoredSessions ?? 0
                        ],
                        [
                          'Backup coverage Members',
                          r.coverage['membersWithBackups']
                        ],
                        ['Current active Members', r.coverage['activeMembers']],
                        ['Date', 'Estimated mean %', 'Scored samples'],
                        for (final p in points)
                          [
                            p.date.toIso8601String().substring(0, 10),
                            p.score,
                            p.samples
                          ]
                      ],
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.loading) const LinearProgressIndicator(),
                    if (s.error != null) Text(s.error!),
                    if (r == null)
                      TextButton(
                          onPressed: () => _cubit!.load(),
                          child: const Text('Retry estimated form report')),
                    if (r != null) ...[
                      Text(
                          '${r.coverage['membersWithBackups']} / ${r.coverage['activeMembers']} current active Members have backup records · ${r.totals.sessions} saved camera captures. Device-only and unscored results are not estimated scores.'),
                      if (ids.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                                'No compatible scored measurements in this date range.'))
                      else ...[
                        DropdownButtonFormField<String>(
                            key: ValueKey('exercise-$selected'),
                            initialValue: selected,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Exercise'),
                            items: [
                              for (final id in ids)
                                DropdownMenuItem(value: id, child: Text(id))
                            ],
                            onChanged: (v) => setState(() {
                                  _exercise = v;
                                  _version = null;
                                })),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                            key: ValueKey('group-${group?.label}'),
                            initialValue: group?.label,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText:
                                    'Compatible scoring / model / view group'),
                            items: [
                              for (final g in groups)
                                DropdownMenuItem(
                                    value: g.label,
                                    child: Text(g.label,
                                        overflow: TextOverflow.ellipsis))
                            ],
                            onChanged: (v) => setState(() => _version = v)),
                        const SizedBox(height: 12),
                        Text(
                            'Exercise overall: ${groups.fold<int>(0, (n, g) => n + g.scoredSessions)} scored samples across compatible groups / ${r.exercises.where((e) => e.exerciseId == selected).fold<int>(0, (n, e) => n + e.sessions)} saved camera captures. Unscored capture versions are unknown.'),
                        Text(
                            '${group!.scoredSessions} scored samples · session-weighted mean ${group.average.toStringAsFixed(1)}%'),
                        SizedBox(
                            height: 250,
                            child: SfCartesianChart(
                                primaryXAxis: const DateTimeAxis(),
                                primaryYAxis:
                                    const NumericAxis(minimum: 0, maximum: 100),
                                tooltipBehavior: TooltipBehavior(enable: true),
                                series: <CartesianSeries<_FormPoint, DateTime>>[
                                  LineSeries<_FormPoint, DateTime>(
                                      name: 'Estimated Form Score %',
                                      dataSource: points,
                                      xValueMapper: (p, _) => p.date,
                                      yValueMapper: (p, _) => p.score,
                                      emptyPointSettings:
                                          const EmptyPointSettings(
                                              mode: EmptyPointMode.gap),
                                      markerSettings:
                                          const MarkerSettings(isVisible: true),
                                      color: AppColors.primary)
                                ])),
                        const Text(
                            'Each point averages scored sessions in this exact exercise, scoring rule, detector/model, camera view and arm group. Missing dates remain gaps; no score is inferred.'),
                        ExpansionTile(
                            title: const Text('View score samples'),
                            children: [
                              for (final p in points)
                                ListTile(
                                    dense: true,
                                    title: Text(p.date
                                        .toIso8601String()
                                        .substring(0, 10)),
                                    subtitle: Text(p.score == null
                                        ? 'No measured score'
                                        : '${p.score!.toStringAsFixed(1)}% · ${p.samples} samples'))
                            ]),
                      ]
                    ]
                  ]));
        });
  }

  List<_FormPoint> _points(AdminWorkoutReport r, WorkoutFormGroup g) {
    final by = {for (final d in g.daily) d.date: d};
    if (by.isEmpty) return [];
    final points = <_FormPoint>[];
    for (var i = 0; i < g.daily.length; i++) {
      final sample = g.daily[i],
          day = DateTime.parse('${sample.date}T00:00:00Z');
      if (i > 0) {
        final previous = DateTime.parse('${g.daily[i - 1].date}T00:00:00Z');
        if (day.difference(previous).inDays > 1) {
          points
              .add(_FormPoint(previous.add(const Duration(days: 1)), null, 0));
        }
      }
      points.add(_FormPoint(day, sample.average, sample.count));
    }
    return points;
  }
}

class AdminCoachActivitySection extends StatelessWidget {
  const AdminCoachActivitySection(
      {super.key, required this.anchorKey, required this.report});
  final GlobalKey anchorKey;
  final AdminCommerceReport report;
  @override
  Widget build(BuildContext context) => ReportSection(
      anchorKey: anchorKey,
      title: 'Coach Booking Utilization',
      subtitle:
          'Per-Coach recorded activity · available-time utilization unavailable',
      live: true,
      tagLabel: 'Booking activity',
      exportFilename: 'coach-booking-activity.csv',
      exportRows: () => [
            [
              'GainPath Coach activity',
              'No trustworthy historical availability denominator'
            ],
            [
              'Start inclusive UTC',
              report.query.range.start.toUtc().toIso8601String()
            ],
            [
              'End exclusive UTC',
              report.query.range.end.toUtc().toIso8601String()
            ],
            ['Timezone', 'Asia/Kuala_Lumpur'],
            [
              'Coach',
              'Created bookings',
              'Confirmed outcomes',
              'Scheduled starts',
              'Published consultations',
              'Utilization %'
            ],
            for (final c in report.coaches)
              [
                _safe(c.name),
                c['bookings'],
                c['confirmed'],
                c['scheduledStarts'],
                c['consultations'],
                null
              ]
          ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'Bookings use creation time; scheduled starts use appointment time and may be upcoming. Consultations use publication time. Current rosters are not applied retrospectively: utilization percentage is unavailable without evidenced capacity for the selected period.'),
        if (report.coaches.isEmpty)
          const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No Coach activity records available.'))
        else ...[
          SizedBox(
              height: 250,
              child: SfCartesianChart(
                  primaryXAxis: const CategoryAxis(
                      labelIntersectAction: AxisLabelIntersectAction.wrap),
                  primaryYAxis: const NumericAxis(minimum: 0, decimalPlaces: 0),
                  legend: const Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                      overflowMode: LegendItemOverflowMode.wrap),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries<CommerceRow, String>>[
                    ColumnSeries<CommerceRow, String>(
                        name: 'Bookings created',
                        dataSource: report.coaches,
                        xValueMapper: (c, _) => c.name,
                        yValueMapper: (c, _) => c['bookings']),
                    ColumnSeries<CommerceRow, String>(
                        name: 'Consultations published',
                        dataSource: report.coaches,
                        xValueMapper: (c, _) => c.name,
                        yValueMapper: (c, _) => c['consultations'])
                  ])),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(columns: const [
                DataColumn(label: Text('Coach')),
                DataColumn(label: Text('Created bookings')),
                DataColumn(label: Text('Confirmed outcomes')),
                DataColumn(label: Text('Scheduled starts')),
                DataColumn(label: Text('Consultations')),
                DataColumn(label: Text('Utilization'))
              ], rows: [
                for (final c in report.coaches)
                  DataRow(cells: [
                    DataCell(Text(c.name)),
                    DataCell(Text('${c['bookings']}')),
                    DataCell(Text('${c['confirmed']}')),
                    DataCell(Text('${c['scheduledStarts']}')),
                    DataCell(Text('${c['consultations']}')),
                    const DataCell(Text('Unavailable'))
                  ])
              ])),
        ]
      ]));
  String _safe(String v) => RegExp(r'^\s*[=+@\-]').hasMatch(v) ? "'$v" : v;
}

Object? _safeCsv(Object? value) =>
    value is String && RegExp(r'^\s*[=+@\-]').hasMatch(value)
        ? "'$value"
        : value;
