import 'package:flutter/material.dart';
import '../../../domain/member_workout_report.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

String localProgressCoverage(double? coverage) =>
    coverage == null ? 'Not measured' : '${(coverage * 100).round()}%';

String localProgressDate(DateTime instant, Duration offset) {
  final date = instant.add(offset);
  return '${date.day}/${date.month}/${date.year}';
}

String localProgressZone(Duration offset) {
  final minutes = offset.inMinutes.abs();
  final sign = offset.isNegative ? '-' : '+';
  return 'UTC$sign${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

String localProgressStatus(LocalWorkoutRecordStatus status) => switch (status) {
      LocalWorkoutRecordStatus.localOnly => 'Provisional · local only',
      LocalWorkoutRecordStatus.pending => 'Pending upload',
      LocalWorkoutRecordStatus.retryable => 'Pending upload · retry needed',
      LocalWorkoutRecordStatus.rejected => 'Upload rejected',
      LocalWorkoutRecordStatus.accepted => 'Server-accepted',
      LocalWorkoutRecordStatus.unknown => 'Upload status unavailable',
    };

class LocalProgressPeriod extends StatelessWidget {
  const LocalProgressPeriod({super.key, required this.progress});
  final MemberLocalProgress progress;

  @override
  Widget build(BuildContext context) => Text(
        'Monday–Sunday · ${localProgressDate(progress.weekStart, progress.utcOffset)}'
        ' – ${localProgressDate(progress.weekEnd.subtract(const Duration(days: 1)), progress.utcOffset)}'
        ' · ${localProgressZone(progress.utcOffset)}',
        style: Theme.of(context).textTheme.bodyMedium,
      );
}

class LocalProgressRecordTile extends StatelessWidget {
  const LocalProgressRecordTile(
      {super.key,
      required this.record,
      required this.utcOffset,
      this.onOpenWorkout,
      this.exerciseName});
  final LocalWorkoutProgressRecord record;
  final String? exerciseName;
  final Duration utcOffset;
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      LocalWorkoutRecordStatus.rejected => AppColors.danger,
      LocalWorkoutRecordStatus.retryable => AppColors.warning,
      _ => AppColors.inkSoft,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenWorkout == null ? null : () => onOpenWorkout!(record),
        child: Panel(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.fitness_center_rounded,
                  size: 19, color: AppColors.primary)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(exerciseName ?? reportExerciseLabel(record.exerciseId),
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                    '${localProgressDate(record.endedAt, utcOffset)} · '
                    '${record.repetitions} full reps · ${record.partialRepetitions} partial attempts',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text(localProgressStatus(record.status),
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.w700)),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Measurement details'),
                  children: [
                    Text('Exercise ID: ${record.exerciseId}'),
                    Text(record.sessionId),
                    if (record.failureCode != null)
                      Text('Upload detail: ${record.failureCode}'),
                    if (record.acceptedAt != null)
                      Text(
                          'Accepted ${localProgressDate(record.acceptedAt!, utcOffset)}'),
                    Text(record.formScorePercent == null
                        ? 'Estimated form: unassessed'
                        : 'Estimated form: ${record.formScorePercent!.toStringAsFixed(1)}%'),
                    const Text(
                        'Provisional estimate · upload acceptance does not validate form'),
                    Text(
                        'Measurement coverage: ${localProgressCoverage(record.coverage)}'),
                    Text(
                        'Tracked ${(record.trackedDurationMicros / 1000000).toStringAsFixed(1)} s · '
                        'rejected ${(record.rejectedDurationMicros / 1000000).toStringAsFixed(1)} s'),
                    Text(
                        'Rule ${record.scoringVersion} · detector ${record.detectorId} · '
                        'model ${record.detectorVersion} · view ${record.cameraView}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ])),
          if (onOpenWorkout != null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
        ])),
      ),
    );
  }
}

class LocalWeeklyChart extends StatelessWidget {
  const LocalWeeklyChart(
      {super.key, required this.progress, this.repetitions = false});
  final MemberLocalProgress progress;
  final bool repetitions;

  @override
  Widget build(BuildContext context) => Panel(
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
                    labelStyle: TextStyle(fontSize: 10)),
                primaryYAxis: const NumericAxis(
                    minimum: 0,
                    decimalPlaces: 0,
                    majorGridLines:
                        MajorGridLines(width: 0.6, color: AppColors.hairline),
                    axisLine: AxisLine(width: 0)),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<WeeklyWorkoutProgress, String>>[
                  ColumnSeries<WeeklyWorkoutProgress, String>(
                    name: repetitions ? 'Full reps' : 'Saved sessions',
                    dataSource: progress.weeks,
                    xValueMapper: (week, _) =>
                        localProgressDate(week.start, progress.utcOffset),
                    yValueMapper: (week, _) =>
                        repetitions ? week.repetitions : week.sessions,
                    color:
                        repetitions ? AppColors.primary : AppColors.primarySoft,
                    width: 0.55,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              )),
          // The text equivalent preserves chart values for screen readers.
          Text(
              progress.weeks
                  .map((week) =>
                      '${localProgressDate(week.start, progress.utcOffset)}: '
                      '${repetitions ? week.repetitions : week.sessions}')
                  .join(' · '),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ));
}

Widget localProgressRefresh(
        {required Widget child, Future<void> Function()? onRefresh}) =>
    onRefresh == null
        ? child
        : RefreshIndicator(onRefresh: onRefresh, child: child);
