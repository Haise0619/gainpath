import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// UC-9.5 — View Client Posture History. Uses the same Syncfusion chart
/// language already established in the member-facing Progress module
/// (spline-area trend + a ranked bar breakdown) so a coach reviewing a
/// client's form sees the same trustworthy chart type the member sees on
/// their own progress screen — not a different, less capable widget.
class ClientPostureScreen extends StatelessWidget {
  final String name;
  const ClientPostureScreen({super.key, required this.name});

  static const _sessionLabels = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7'];

  static const _byMovement = <_MovementAccuracy>[
    _MovementAccuracy('Dumbbell Row', 88),
    _MovementAccuracy('Barbell Squat', 84),
    _MovementAccuracy('Overhead Press', 79),
    _MovementAccuracy('Romanian Deadlift', 71),
  ];

  @override
  Widget build(BuildContext context) {
    const trend = MockData.postureTrend;
    final data = List.generate(trend.length, (i) => _SessionPoint(_sessionLabels[i], trend[i]));
    final weakest = _byMovement.reduce((a, b) => a.accuracy < b.accuracy ? a : b);
    final atRisk = weakest.accuracy < 75;

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: PageBody(
        children: [
          const Eyebrow('Form accuracy trend'),
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
                      majorGridLines: MajorGridLines(width: 0.6, color: AppColors.hairline),
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
                        markerSettings: const MarkerSettings(isVisible: true, height: 6, width: 6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Improving steadily over the last ${trend.length} sessions.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('By movement'),
          Panel(
            child: SizedBox(
              height: 200,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 11),
                ),
                primaryYAxis: const NumericAxis(isVisible: false, minimum: 0, maximum: 100),
                series: <CartesianSeries<_MovementAccuracy, String>>[
                  BarSeries<_MovementAccuracy, String>(
                    dataSource: _byMovement,
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
          const SizedBox(height: 18),
          if (atRisk)
            Panel(
              background: AppColors.dangerTint,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Watch ${weakest.name}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 3),
                        Text(
                          'Accuracy on this movement is below the safe-form threshold. Worth '
                          'reviewing setup cues next session.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
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

class _MovementAccuracy {
  final String name;
  final int accuracy;
  const _MovementAccuracy(this.name, this.accuracy);
}
