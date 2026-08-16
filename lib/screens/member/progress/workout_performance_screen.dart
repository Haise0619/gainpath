import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M5.2 (Workout performance) — weekly lifted volume as a column
/// chart, paired with a doughnut breakdown of muscle-group split. Column
/// and doughnut are the two chart shapes that best carry this report's
/// two questions: "how much, over time" and "what proportion, right now."
class WorkoutPerformanceScreen extends StatelessWidget {
  const WorkoutPerformanceScreen({super.key});

  static const _weekLabels = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];
  static const _sliceColors = [
    AppColors.primary,
    AppColors.primarySoft,
    AppColors.accent,
    AppColors.info,
  ];

  @override
  Widget build(BuildContext context) {
    const volume = MockData.volumeTrend;
    final data =
        List.generate(volume.length, (i) => _WeekPoint(_weekLabels[i], volume[i]));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export',
            onPressed: () => showToast(context, 'Report saved to your device.'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Row(
            children: const [
              Expanded(child: StatTile('3,400', 'kg lifted this week')),
              SizedBox(width: 10),
              Expanded(
                  child: StatTile('+13%', 'vs last week',
                      valueColor: AppColors.success)),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Weekly volume (kg)'),
          Panel(
            child: SizedBox(
              height: 220,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                ),
                primaryYAxis: const NumericAxis(
                  majorGridLines:
                      MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<_WeekPoint, String>>[
                  ColumnSeries<_WeekPoint, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    color: AppColors.primary,
                    width: 0.55,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Muscle group split'),
          Panel(
            child: SizedBox(
              height: 220,
              child: SfCircularChart(
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.right,
                  textStyle: TextStyle(fontSize: 12),
                ),
                series: <CircularSeries<MuscleGroupShare, String>>[
                  DoughnutSeries<MuscleGroupShare, String>(
                    dataSource: MockData.muscleGroupSplit,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.ratio,
                    dataLabelMapper: (d, _) => '${(d.ratio * 100).round()}%',
                    innerRadius: '68%',
                    cornerStyle: CornerStyle.bothCurve,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    pointColorMapper: (d, i) =>
                        _sliceColors[i % _sliceColors.length],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekPoint {
  final String label;
  final int value;
  const _WeekPoint(this.label, this.value);
}
