import 'package:flutter/material.dart';
import '../../../domain/member_workout_report.dart';
import '../../../domain/workout_activity_overview.dart';
import '../../../../workout/presentation/member/widgets/workout_save_indicator.dart';
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
      this.saveStatus,
      this.exerciseName,
      this.historyMode = false});
  final LocalWorkoutProgressRecord record;
  final String? exerciseName;
  final Widget? saveStatus;
  final Duration utcOffset;
  final bool historyMode;
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;

  Widget _formScoreBadge(BuildContext context) {
    final isUnscoredExercise = record.exerciseId.contains('lateral-raise') ||
        record.exerciseId.contains('overhead-press') ||
        record.exerciseId.contains('shoulder-press');

    if (isUnscoredExercise) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Assessment unavailable',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
          ),
        ),
      );
    }

    if (record.formScorePercent != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Estimated Form: ${record.formScorePercent!.round()}/100',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Not assessed',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      LocalWorkoutRecordStatus.rejected => AppColors.danger,
      LocalWorkoutRecordStatus.retryable => AppColors.warning,
      _ => AppColors.inkSoft,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenWorkout == null ? null : () => onOpenWorkout!(record),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.videocam_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            exerciseName ?? reportExerciseLabel(record.exerciseId),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _formScoreBadge(context),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${localProgressDate(record.endedAt, utcOffset)} · '
                      '${record.repetitions} full reps · ${record.partialRepetitions} partial attempts',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (record.scoringVersion == 'single-arm-curl-side-v1' &&
                        record.armMode != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        progressArmModeLabel(record.armMode),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (record.scope.datasetScope != null)
                      const Text(
                        'Fictional recorded fixture · read only',
                        style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                      )
                    else
                      saveStatus ?? const WorkoutSaveIndicator(),
                    if (!historyMode)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Measurement details'),
                        children: [
                          Text(localProgressStatus(record.status),
                              style: TextStyle(color: statusColor)),
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
                  ],
                ),
              ),
              if (onOpenWorkout != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
                ),
            ],
          ),
        ),
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
