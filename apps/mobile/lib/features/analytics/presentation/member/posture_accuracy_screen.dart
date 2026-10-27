import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'widgets/local_progress_widgets.dart';

/// AD-M5.2 (Posture accuracy) — a smoothed trend area answers "is form
/// improving over time"; a horizontal bar ranking answers "which exercise
/// needs work right now." Two different questions get two different
/// chart shapes rather than reusing one chart for both.
class PostureAccuracyScreen extends StatelessWidget {
  const PostureAccuracyScreen(
      {super.key, this.localProgress, this.onOpenReport});

  final MemberLocalProgress? localProgress;
  final VoidCallback? onOpenReport;

  static const _sessionLabels = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7'];

  static const _byExercise = <_ExerciseAccuracy>[
    _ExerciseAccuracy('Dumbbell Row', 88),
    _ExerciseAccuracy('Barbell Squat', 84),
    _ExerciseAccuracy('Overhead Press', 79),
    _ExerciseAccuracy('Romanian Deadlift', 71),
  ];

  @override
  Widget build(BuildContext context) {
    final local = localProgress;

    final trend = local == null
        ? context.read<AnalyticsRepository>().postureTrend
        : <int>[];
    final data = List.generate(
        trend.length, (i) => _SessionPoint(_sessionLabels[i], trend[i]));

    return Scaffold(
      appBar: AppBar(
        title: Text(local == null ? 'Posture accuracy' : 'Estimated form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export',
            onPressed: onOpenReport ?? () => showUnavailable(context),
          ),
        ],
      ),
      body: PageBody(
        children: [
          const Eyebrow('Form accuracy over time'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 190,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    primaryXAxis: const CategoryAxis(
                      majorGridLines: MajorGridLines(width: 0),
                      axisLine: AxisLine(width: 0),
                    ),
                    primaryYAxis: const NumericAxis(
                      minimum: 50,
                      maximum: 100,
                      majorGridLines:
                          MajorGridLines(width: 0.6, color: AppColors.hairline),
                      axisLine: AxisLine(width: 0),
                      labelStyle:
                          TextStyle(fontSize: 10, color: AppColors.inkSoft),
                    ),
                    trackballBehavior: TrackballBehavior(
                      enable: true,
                      activationMode: ActivationMode.singleTap,
                      tooltipSettings: const InteractiveTooltip(enable: true),
                    ),
                    series: <CartesianSeries<_SessionPoint, String>>[
                      SplineAreaSeries<_SessionPoint, String>(
                        dataSource: data,
                        xValueMapper: (d, _) => d.label,
                        yValueMapper: (d, _) => d.accuracy,
                        color: AppColors.primary.withValues(alpha: 0.18),
                        borderColor: AppColors.primary,
                        borderWidth: 2.4,
                        markerSettings: const MarkerSettings(
                            isVisible: true, height: 6, width: 6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  local == null
                      ? 'Up ${trend.last - trend.first} points over the last ${trend.length} sessions.'
                      : '-',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('By exercise'),
          if (local != null) const Text('-'),
          Panel(
            child: SizedBox(
              height: 210,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 11),
                ),
                primaryYAxis: const NumericAxis(
                    isVisible: false, minimum: 0, maximum: 100),
                series: <CartesianSeries<_ExerciseAccuracy, String>>[
                  BarSeries<_ExerciseAccuracy, String>(
                    dataSource:
                        local == null ? _byExercise : <_ExerciseAccuracy>[],
                    xValueMapper: (d, _) => d.name,
                    yValueMapper: (d, _) => d.accuracy,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.outer,
                      textStyle:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    pointColorMapper: (d, _) => d.accuracy >= 80
                        ? AppColors.success
                        : AppColors.warning,
                    borderRadius: BorderRadius.circular(6),
                    width: 0.6,
                  ),
                ],
              ),
            ),
          ),
          if (local != null) ..._localDetails(context, local),
        ],
      ),
    );
  }

  List<Widget> _localDetails(
          BuildContext context, MemberLocalProgress progress) =>
      [
        Text(
            'Provisional rule estimates · ${localProgressZone(progress.utcOffset)}',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        const Text(
            'Each exercise, rule, detector, model and camera view is shown '
            'separately. Upload acceptance does not validate the form estimate. '
            'Unassessed captures appear as gaps.'),
        const SizedBox(height: 20),
        const Eyebrow('Estimated form by version'),
        if (progress.formSeries.isEmpty)
          const Panel(child: Text('No estimated form measurements yet.')),
        for (final group in progress.formSeries) ...[
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(group.exerciseId,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                    'Rule ${group.scoringVersion} · detector ${group.detectorId} · '
                    'model ${group.detectorVersion} · view ${group.cameraView}'),
                const SizedBox(height: 10),
                Text(group.meanScore == null
                    ? 'Estimated form: unassessed'
                    : 'Estimated form: ${group.meanScore!.toStringAsFixed(1)}%'),
                Text('${group.scoredAttempts} scored attempts · '
                    '${group.unassessedAttempts} unassessed attempts'),
                SizedBox(
                    height: 190,
                    child: SfCartesianChart(
                      plotAreaBorderWidth: 0,
                      primaryXAxis: DateTimeAxis(
                          axisLabelFormatter: (details) => ChartAxisLabel(
                              localProgressDate(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      details.value.toInt(),
                                      isUtc: true),
                                  progress.utcOffset),
                              details.textStyle),
                          majorGridLines: MajorGridLines(width: 0),
                          axisLine: AxisLine(width: 0)),
                      primaryYAxis: const NumericAxis(
                          minimum: 0,
                          maximum: 100,
                          majorGridLines: MajorGridLines(
                              width: 0.6, color: AppColors.hairline),
                          axisLine: AxisLine(width: 0)),
                      tooltipBehavior: TooltipBehavior(
                          enable: true,
                          builder:
                              (data, point, series, pointIndex, seriesIndex) {
                            final record = data as LocalWorkoutProgressRecord;
                            return Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                    '${localProgressDate(record.endedAt, progress.utcOffset)} · ${localProgressZone(progress.utcOffset)}\n'
                                    '${record.formScorePercent == null ? 'Unassessed' : '${record.formScorePercent!.toStringAsFixed(1)}% estimated form'}',
                                    style:
                                        const TextStyle(color: Colors.white)));
                          }),
                      series: <CartesianSeries<LocalWorkoutProgressRecord,
                          DateTime>>[
                        LineSeries<LocalWorkoutProgressRecord, DateTime>(
                          name:
                              '${group.exerciseId} · ${group.scoringVersion} · '
                              '${group.detectorId} · ${group.detectorVersion} · ${group.cameraView}',
                          dataSource: group.records,
                          xValueMapper: (record, _) => record.endedAt,
                          yValueMapper: (record, _) => record.formScorePercent,
                          color: AppColors.primary,
                          width: 2,
                          emptyPointSettings: const EmptyPointSettings(
                              mode: EmptyPointMode.gap),
                          markerSettings: const MarkerSettings(
                              isVisible: true, height: 6, width: 6),
                        ),
                      ],
                    )),
                for (final record in group.records)
                  Text(
                      '${localProgressDate(record.endedAt, progress.utcOffset)} · '
                      '${record.formScorePercent == null ? 'unassessed' : '${record.formScorePercent!.toStringAsFixed(1)}%'}'
                      ' · measurement coverage: ${localProgressCoverage(record.coverage)}',
                      style: Theme.of(context).textTheme.bodyMedium),
              ])),
          const SizedBox(height: 12),
        ],
      ];
}

class _SessionPoint {
  final String label;
  final int accuracy;
  const _SessionPoint(this.label, this.accuracy);
}

class _ExerciseAccuracy {
  final String name;
  final int accuracy;
  const _ExerciseAccuracy(this.name, this.accuracy);
}
