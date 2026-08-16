import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// New Progress sub-report on body composition: a weight trend line (the
/// natural chart shape for "one number over time") and a BMI range
/// gauge, whose coloured clinical bands are a shape none of the other
/// reports need.
class BodyMetricsScreen extends StatelessWidget {
  const BodyMetricsScreen({super.key});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final history = MockData.weightHistory;
    final current = history.last.weightKg;
    const heightM = MockData.heightCm / 100;
    final bmi = current / (heightM * heightM);
    final weights = history.map((e) => e.weightKg).toList();
    final points = history.map((e) => _WeightPoint(_shortDate(e.date), e.weightKg)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Body metrics')),
      body: PageBody(
        children: [
          Row(
            children: [
              Expanded(child: StatTile('${current.toStringAsFixed(1)} kg', 'Current weight')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(bmi.toStringAsFixed(1), 'BMI')),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Weight trend (last 7 weeks)'),
          Panel(
            child: SizedBox(
              height: 190,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 9.5, color: AppColors.inkSoft),
                ),
                primaryYAxis: NumericAxis(
                  minimum: (weights.reduce((a, b) => a < b ? a : b) - 1).floorToDouble(),
                  maximum: (weights.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble(),
                  majorGridLines:
                      const MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: const AxisLine(width: 0),
                  labelStyle: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                trackballBehavior:
                    TrackballBehavior(enable: true, activationMode: ActivationMode.singleTap),
                series: <CartesianSeries<_WeightPoint, String>>[
                  SplineSeries<_WeightPoint, String>(
                    dataSource: points,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.weightKg,
                    color: AppColors.primary,
                    width: 2.4,
                    markerSettings:
                        const MarkerSettings(isVisible: true, height: 6, width: 6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('BMI range'),
          Panel(
            child: Column(
              children: [
                SizedBox(
                  height: 90,
                  child: SfLinearGauge(
                    minimum: 15,
                    maximum: 35,
                    showLabels: true,
                    showTicks: false,
                    axisTrackStyle: const LinearAxisTrackStyle(thickness: 14),
                    ranges: const [
                      LinearGaugeRange(
                          startValue: 15, endValue: 18.5, color: AppColors.info,
                          startWidth: 14, endWidth: 14),
                      LinearGaugeRange(
                          startValue: 18.5, endValue: 25, color: AppColors.success,
                          startWidth: 14, endWidth: 14),
                      LinearGaugeRange(
                          startValue: 25, endValue: 30, color: AppColors.warning,
                          startWidth: 14, endWidth: 14),
                      LinearGaugeRange(
                          startValue: 30, endValue: 35, color: AppColors.danger,
                          startWidth: 14, endWidth: 14),
                    ],
                    markerPointers: [
                      LinearShapePointer(
                        // `num.clamp()` returns `num`, not `double` — Dart
                        // won't implicitly downcast that into a `double`
                        // parameter.
                        value: bmi.clamp(15, 35).toDouble(),
                        shapeType: LinearShapePointerType.invertedTriangle,
                        color: AppColors.ink,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${bmi.toStringAsFixed(1)} falls in the ${_bmiLabel(bmi)} range.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'underweight';
    if (bmi < 25) return 'normal';
    if (bmi < 30) return 'overweight';
    return 'obese';
  }
}

class _WeightPoint {
  final String label;
  final double weightKg;
  const _WeightPoint(this.label, this.weightKg);
}
