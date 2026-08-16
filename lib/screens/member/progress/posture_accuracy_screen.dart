import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M5.2 (Posture accuracy) — a smoothed trend area answers "is form
/// improving over time"; a horizontal bar ranking answers "which exercise
/// needs work right now." Two different questions get two different
/// chart shapes rather than reusing one chart for both.
class PostureAccuracyScreen extends StatelessWidget {
  const PostureAccuracyScreen({super.key});

  static const _sessionLabels = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7'];

  static const _byExercise = <_ExerciseAccuracy>[
    _ExerciseAccuracy('Dumbbell Row', 88),
    _ExerciseAccuracy('Barbell Squat', 84),
    _ExerciseAccuracy('Overhead Press', 79),
    _ExerciseAccuracy('Romanian Deadlift', 71),
  ];

  @override
  Widget build(BuildContext context) {
    const trend = MockData.postureTrend;
    final data =
        List.generate(trend.length, (i) => _SessionPoint(_sessionLabels[i], trend[i]));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posture accuracy'),
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
                      labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
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
                        markerSettings:
                            const MarkerSettings(isVisible: true, height: 6, width: 6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Up ${trend.last - trend.first} points over the last ${trend.length} sessions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('By exercise'),
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
                primaryYAxis: const NumericAxis(isVisible: false, minimum: 0, maximum: 100),
                series: <CartesianSeries<_ExerciseAccuracy, String>>[
                  BarSeries<_ExerciseAccuracy, String>(
                    dataSource: _byExercise,
                    xValueMapper: (d, _) => d.name,
                    yValueMapper: (d, _) => d.accuracy,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelAlignment: ChartDataLabelAlignment.outer,
                      textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    pointColorMapper: (d, _) =>
                        d.accuracy >= 80 ? AppColors.success : AppColors.warning,
                    borderRadius: BorderRadius.circular(6),
                    width: 0.6,
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
