import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide CornerStyle;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M9.3 — View Performance Metrics Dashboard. Rating, reviews, and fill
/// rate are all computed from the live `coachRoster` / `currentCoach`
/// instead of fixed numbers, and the weekly trend + fill rate get the
/// same Syncfusion chart/gauge treatment already used in the member
/// Progress module — a coach reading their own performance deserves the
/// same quality of chart a member gets reading theirs.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  static const _weekLabels = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];
  // Illustrative weekly shape — the roster doesn't carry enough completed
  // sessions yet to derive a real 7-week earnings history from it.
  static const _weeklyEarnings = <int>[520, 610, 480, 720, 660, 590, 780];

  @override
  Widget build(BuildContext context) {
    final coach = MockData.currentCoach;
    final roster = MockData.coachRoster;
    final completed = roster.where((b) => b.status == 'Completed').toList();
    final totalEarned = completed.fold<double>(0, (sum, b) => sum + b.fee);
    final notCancelled = roster.where((b) => b.status != 'Cancelled').length;
    final fillRate = roster.isEmpty ? 0 : (notCancelled / roster.length * 100).round();

    final weekData =
        List.generate(_weeklyEarnings.length, (i) => _WeekPoint(_weekLabels[i], _weeklyEarnings[i]));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export statement',
            onPressed: () => showToast(context, 'Statement saved to your device.'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL EARNED',
                    style: TextStyle(
                        fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Colors.white70)),
                const SizedBox(height: 6),
                Text('RM ${totalEarned.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
                const SizedBox(height: 4),
                Text('${completed.length} sessions completed',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatTile('${coach.rating}', 'Avg rating', valueColor: AppColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: StatTile('${coach.reviews}', 'Reviews')),
              const SizedBox(width: 10),
              Expanded(child: StatTile('$fillRate%', 'Fill rate')),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Weekly earnings'),
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
                  majorGridLines: MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<_WeekPoint, String>>[
                  ColumnSeries<_WeekPoint, String>(
                    dataSource: weekData,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.amount,
                    color: AppColors.primary,
                    width: 0.55,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Booking fill rate'),
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
                        maximum: 100,
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
                            value: fillRate.toDouble(),
                            width: 0.16,
                            sizeUnit: GaugeSizeUnit.factor,
                            color: AppColors.primary,
                            cornerStyle: CornerStyle.bothCurve,
                          ),
                        ],
                        annotations: [
                          GaugeAnnotation(
                            positionFactor: 0,
                            widget: Text('$fillRate%',
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
                    '$notCancelled of ${roster.length} booked slots went ahead — the rest were '
                    'cancelled.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Recent sessions'),
          if (completed.isEmpty)
            Panel(
              child: Text('No completed sessions yet.', style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ...completed.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.memberName, style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                b.notes != null ? 'Notes published' : 'Completed session',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Text('RM ${b.fee.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success)),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 6),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Figures reflect completed and cleared sessions only. Payouts are settled '
                    'by the facility on their usual schedule.',
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

class _WeekPoint {
  final String label;
  final int amount;
  const _WeekPoint(this.label, this.amount);
}
