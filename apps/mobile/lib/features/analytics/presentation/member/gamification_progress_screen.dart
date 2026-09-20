import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide CornerStyle;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gamification.dart';

/// New Progress sub-report tying into the Gamification module: points
/// earned per week as a filled area trend, plus the current streak read
/// as a "how full is the tank toward my longest streak" radial gauge.
class GamificationProgressScreen extends StatelessWidget {
  const GamificationProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pts = context.read<AnalyticsRepository>().pointsHistory;
    final labels = context.read<AnalyticsRepository>().pointsWeekLabels;
    final data = List.generate(pts.length, (i) => _WeekPoints(labels[i], pts[i]));

    return Scaffold(
      appBar: AppBar(title: const Text('Points & streak')),
      body: PageBody(
        children: [
          Row(
            children: [
              Expanded(child: StatTile('${context.read<GamificationRepository>().points}', 'Total points')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile('${context.read<GamificationRepository>().streak}', 'Day streak',
                      valueColor: AppColors.accentDark)),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Points earned per week'),
          Panel(
            child: SizedBox(
              height: 190,
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
                series: <CartesianSeries<_WeekPoints, String>>[
                  AreaSeries<_WeekPoints, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.points,
                    color: AppColors.accent.withValues(alpha: 0.28),
                    borderColor: AppColors.accentDark,
                    borderWidth: 2.2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Streak progress'),
          Panel(
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: SfRadialGauge(
                    axes: [
                      RadialAxis(
                        minimum: 0,
                        maximum: context.read<GamificationRepository>().longestStreak.toDouble(),
                        showLabels: false,
                        showTicks: false,
                        startAngle: 270,
                        endAngle: 270,
                        radiusFactor: 0.9,
                        axisLineStyle: const AxisLineStyle(
                          thickness: 0.16,
                          thicknessUnit: GaugeSizeUnit.factor,
                          color: AppColors.surfaceAlt,
                        ),
                        pointers: [
                          RangePointer(
                            value: context.read<GamificationRepository>().streak.toDouble(),
                            width: 0.16,
                            sizeUnit: GaugeSizeUnit.factor,
                            color: AppColors.accentDark,
                            cornerStyle: CornerStyle.bothCurve,
                          ),
                        ],
                        annotations: [
                          GaugeAnnotation(
                            positionFactor: 0,
                            widget: Text('${context.read<GamificationRepository>().streak}d',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Your current streak is ${context.read<GamificationRepository>().streak} days — '
                    '${context.read<GamificationRepository>().longestStreak - context.read<GamificationRepository>().streak} days from your personal '
                    'best of ${context.read<GamificationRepository>().longestStreak}.',
                    style: Theme.of(context).textTheme.bodyMedium,
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

class _WeekPoints {
  final String label;
  final int points;
  const _WeekPoints(this.label, this.points);
}
