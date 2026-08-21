import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../../app/theme.dart';
import '../../../../data/mock_data.dart';
import '../../../../widgets/shared.dart';
import '../report_widgets.dart';

class _WeekPoint {
  final String label;
  final int value;
  const _WeekPoint(this.label, this.value);
}

class RevenueSection extends StatelessWidget {
  final GlobalKey anchorKey;
  const RevenueSection({super.key, required this.anchorKey});

  static const _tierSplit = [ChartSlice('Premium', 176), ChartSlice('Basic', 108)];

  @override
  Widget build(BuildContext context) {
    return ReportSection(
      anchorKey: anchorKey,
      title: 'Membership & Revenue',
      subtitle: 'Income and tier split',
      live: false,
      exportFilename: 'membership_revenue.csv',
      exportRows: () => [
        ['Metric', 'Value'],
        ['Monthly revenue', 'RM 24,180'],
        ['Paying members', '284'],
        [],
        ['Tier', 'Members'],
        ..._tierSplit.map((s) => [s.label, s.value.round()]),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: StatTile('RM 24,180', 'This month')),
              SizedBox(width: 10),
              Expanded(child: StatTile('284', 'Paying members')),
            ],
          ),
          const SizedBox(height: 14),
          const Eyebrow('Membership tier split'),
          Panel(
            child: SizedBox(
              height: 170,
              child: SfCircularChart(
                legend: const Legend(isVisible: true, position: LegendPosition.right, textStyle: TextStyle(fontSize: 12)),
                series: <CircularSeries<ChartSlice, String>>[
                  PieSeries<ChartSlice, String>(
                    dataSource: _tierSplit,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    dataLabelMapper: (d, _) => '${d.value.round()}',
                    pointColorMapper: (d, i) => i == 0 ? AppColors.primary : AppColors.accent,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Per-coach and per-branch revenue is broken down in the Overview section above.',
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

class RewardsSection extends StatelessWidget {
  final GlobalKey anchorKey;
  const RewardsSection({super.key, required this.anchorKey});

  static const _sliceColors = [AppColors.primary, AppColors.accent, AppColors.success, AppColors.info];

  @override
  Widget build(BuildContext context) {
    final trend = List.generate(MockData.rewardWeeklyRedemptions.length,
        (i) => _WeekPoint('W${i + 1}', MockData.rewardWeeklyRedemptions[i]));

    return ReportSection(
      anchorKey: anchorKey,
      title: 'Reward Redemptions',
      subtitle: 'Voucher issue and clearance',
      live: false,
      exportFilename: 'reward_redemptions.csv',
      exportRows: () => [
        ['Week', 'Redemptions'],
        ...trend.map((p) => [p.label, p.value]),
        [],
        ['Reward', 'Redeemed'],
        ...MockData.rewardRedemptionMix.map((s) => [s.label, s.value.round()]),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: StatTile('142', 'Vouchers issued')),
              SizedBox(width: 10),
              Expanded(child: StatTile('118', 'Redeemed')),
            ],
          ),
          const SizedBox(height: 14),
          const Eyebrow('Weekly redemptions'),
          Panel(
            child: SizedBox(
              height: 150,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                primaryYAxis: const NumericAxis(
                  majorGridLines: MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                trackballBehavior: TrackballBehavior(enable: true, activationMode: ActivationMode.singleTap),
                series: <CartesianSeries<_WeekPoint, String>>[
                  SplineSeries<_WeekPoint, String>(
                    dataSource: trend,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    color: AppColors.success,
                    width: 2.4,
                    markerSettings: const MarkerSettings(isVisible: true, height: 6, width: 6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Eyebrow('Most claimed rewards'),
          Panel(
            child: SizedBox(
              height: 190,
              child: SfCircularChart(
                legend: const Legend(isVisible: true, position: LegendPosition.right, textStyle: TextStyle(fontSize: 12)),
                series: <CircularSeries<ChartSlice, String>>[
                  DoughnutSeries<ChartSlice, String>(
                    dataSource: MockData.rewardRedemptionMix,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    innerRadius: '65%',
                    cornerStyle: CornerStyle.bothCurve,
                    pointColorMapper: (d, i) => _sliceColors[i % _sliceColors.length],
                    dataLabelSettings: const DataLabelSettings(isVisible: false),
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
