import 'report_metric_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_workout_reporting.dart';

const currentAiReportExercises = {
  'F3b8xIr8ynBDd3gEICKX': 'Squat',
  'standing-single-arm-curl-side-v1': 'Dumbbell Biceps Curl',
  'standing-calf-raise-side-v1': 'Standing Calf Raise',
  'standing-lateral-raise-front-v1': 'Standing Lateral Raise',
  'dumbbell-shoulder-press-front-v1': 'Dumbbell Shoulder Press',
  'standard-floor-push-up-side-v1': 'Standard Floor Push-Up',
};

String reportExerciseName(String id, AdminWorkoutReport report) {
  final current = currentAiReportExercises[id];
  if (current != null) return current;
  for (final exercise in report.exercises) {
    if (exercise.exerciseId == id &&
        exercise.name != id &&
        exercise.name.isNotEmpty) {
      return exercise.name;
    }
  }
  return id
      .replaceAll(RegExp(r'-v\d+$'), '')
      .split(RegExp(r'[-_]'))
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class AdminWorkoutSummary extends StatelessWidget {
  const AdminWorkoutSummary(
      {super.key, required this.controller, required this.onDetails});
  final AdminWorkoutReportingCubit controller;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => BlocBuilder<AdminWorkoutReportingCubit,
          AdminWorkoutReportingState>(
      bloc: controller,
      builder: (context, state) {
        final report = state.report;
        return Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Workout activity summary',
                    style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View Fitness')),
              ]),
          if (state.loading) const LinearProgressIndicator(),
          if (state.error != null) ...[
            Text(state.error!),
            TextButton(
                onPressed: () => controller.load(),
                child: const Text('Retry workout summary')),
          ],
          if (report == null && state.error == null)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Loading synced workout activity…')),
          if (report != null) ...[
            if (report.fypSourceUnavailable)
              const Text('Partial · canonical backups only'),
            if (report.mixedSources || report.fictional)
              Text(report.fictional
                  ? 'FYP scenario observations.'
                  : 'Includes recorded FYP scenario observations.'),
            const SizedBox(height: 12),
            ReportMetricGrid(children: [
              for (final metric in <(String, String)>[
                (
                  '${report.totals.sessions}',
                  report.fictional
                      ? 'Scenario workout sessions'
                      : 'Saved workout sessions'
                ),
                (
                  '${report.coverage['membersWithActivity']}',
                  'Active workout members'
                ),
                (
                  '${report.totals.completedRoutineDays}',
                  'Completed workout attempts'
                ),
              ])
                SizedBox(
                    width: (220 *
                            MediaQuery.textScalerOf(context)
                                .scale(1)
                                .clamp(1.0, 1.5))
                        .toDouble(),
                    child: StatTile(metric.$1, metric.$2, compact: true)),
            ]),
            const SizedBox(height: 12),
            Text(report.totals.sessions + report.totals.routineAttempts == 0
                ? 'No synced workout activity in the selected dates.'
                : '${report.coverage['membersWithActivity']} of ${report.coverage['activeMembers']} current active members have recorded activity.'),
            const SizedBox(height: 4),
            const Text(
                'Completed attempts use saved routine outcomes, including manual and timed targets.'),
          ],
        ]));
      });
}

class CurrentAiExerciseUsage extends StatelessWidget {
  const CurrentAiExerciseUsage({super.key, required this.report});
  final AdminWorkoutReport report;

  @override
  Widget build(BuildContext context) {
    final byId = {
      for (final exercise in report.exercises) exercise.exerciseId: exercise
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Six AI tracking exercises',
          style: Theme.of(context).textTheme.titleMedium),
      const Text('Current supported variants · selected reporting dates'),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(columns: const [
            DataColumn(label: Text('Exercise')),
            DataColumn(label: Text('Sessions'), numeric: true),
            DataColumn(label: Text('Full reps'), numeric: true),
            DataColumn(label: Text('Partial reps'), numeric: true),
          ], rows: [
            for (final entry in currentAiReportExercises.entries)
              DataRow(cells: [
                DataCell(Text(entry.value)),
                DataCell(Text('${byId[entry.key]?.sessions ?? 0}')),
                DataCell(Text('${byId[entry.key]?.fullReps ?? 0}')),
                DataCell(Text('${byId[entry.key]?.partialReps ?? 0}')),
              ])
          ])),
      const Text(
          'Other and historical exercises remain in the exercise details and CSV.'),
    ]);
  }
}

class WorkoutScoreDistribution extends StatelessWidget {
  const WorkoutScoreDistribution({super.key, required this.group});
  final WorkoutFormGroup group;

  @override
  Widget build(BuildContext context) {
    final bands = group.scoreBands;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Estimated form score distribution',
          style: Theme.of(context).textTheme.titleMedium),
      Text(
          '${group.scoredSessions} scored sessions · selected compatible group'),
      if (bands == null)
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.blueGrey.shade400),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Score distribution unavailable.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155))),
                    const SizedBox(height: 2),
                    Text(
                        'This historical aggregate does not contain score-distribution data. Available score samples and trends can still be reviewed.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        )
      else
        SizedBox(
            height: 190,
            child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                primaryYAxis: NumericAxis(
                    minimum: 0,
                    decimalPlaces: 0,
                    interval:
                        bands.values.every((count) => count <= 5) ? 1 : null),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<MapEntry<String, int>, String>>[
                  BarSeries<MapEntry<String, int>, String>(
                      name: 'Scored sessions',
                      color: AppColors.primary,
                      dataSource: bands.entries.toList(),
                      xValueMapper: (band, _) =>
                          WorkoutFormGroup.scoreBandLabels[band.key]!,
                      yValueMapper: (band, _) => band.value,
                      dataLabelSettings:
                          const DataLabelSettings(isVisible: true)),
                ])),
    ]);
  }
}
