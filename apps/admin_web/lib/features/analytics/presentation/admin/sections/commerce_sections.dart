import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import '../../../application/admin_reporting_gateway.dart';
import '../original_report_data_widgets.dart';

class _WeekPoint {
  final String label;
  final int value;
  const _WeekPoint(this.label, this.value);
}

class RevenueSection extends StatelessWidget {
  final AdminReportingSnapshot? snapshot;
  final GlobalKey anchorKey;
  final bool live;
  const RevenueSection(
      {super.key, required this.anchorKey, this.live = false, this.snapshot});

  static const _tierSplit = [
    ChartSlice('Premium', 176),
    ChartSlice('Basic', 108)
  ];

  @override
  Widget build(BuildContext context) {
    final ops = snapshot?.operations;
    return ReportSection(
      anchorKey: anchorKey,
      title: 'Membership & Revenue',
      subtitle: ops == null
          ? 'Income and tier split'
          : 'Confirmed Sandbox receipts · original clearance dates',
      live: live,
      tagLabel: ops != null
          ? 'Sandbox · filtered'
          : live
              ? 'Unavailable'
              : null,
      exportFilename: 'membership_revenue.csv',
      exportEnabled: ops != null || !live,
      exportRows: ops != null
          ? () => ops.toCsv(snapshot!)
          : live
              ? null
              : () => [
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
            children: [
              Expanded(
                  child: StatTile(
                      ops != null
                          ? reportMoney(ops.membershipMinor)
                          : live
                              ? '—'
                              : 'RM 24,180',
                      ops != null ? 'Membership receipts' : 'This month')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile(
                      ops != null
                          ? reportMoney(ops.coachingMinor)
                          : live
                              ? '—'
                              : '284',
                      ops != null ? 'Coaching receipts' : 'Paying members')),
            ],
          ),
          const SizedBox(height: 14),
          const Eyebrow('Membership tier split'),
          Panel(
            child: SizedBox(
              height: 170,
              child: live
                  ? const NoFilteredData(
                      message:
                          'Membership tier split is unavailable in this release.')
                  : SfCircularChart(
                      legend: const Legend(
                          isVisible: true,
                          position: LegendPosition.right,
                          textStyle: TextStyle(fontSize: 12)),
                      series: <CircularSeries<ChartSlice, String>>[
                        PieSeries<ChartSlice, String>(
                          dataSource: _tierSplit,
                          xValueMapper: (d, _) => d.label,
                          yValueMapper: (d, _) => d.value,
                          dataLabelMapper: (d, _) => '${d.value.round()}',
                          pointColorMapper: (d, i) =>
                              i == 0 ? AppColors.primary : AppColors.accent,
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            labelPosition: ChartDataLabelPosition.outside,
                            textStyle: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
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
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ops != null
                        ? 'These are Sandbox receipts, not net revenue or payouts. Membership-tier and per-branch financial splits remain unavailable.'
                        : 'Per-coach and per-branch revenue is broken down in the Overview section above.',
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
  final bool live;
  const RewardsSection({super.key, required this.anchorKey, this.live = false});

  static const _sliceColors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.success,
    AppColors.info
  ];

  @override
  Widget build(BuildContext context) {
    final trend = List.generate(
        context.read<AnalyticsRepository>().rewardWeeklyRedemptions.length,
        (i) => _WeekPoint('W${i + 1}',
            context.read<AnalyticsRepository>().rewardWeeklyRedemptions[i]));

    return ReportSection(
      anchorKey: anchorKey,
      title: 'Reward Redemptions',
      subtitle: 'Voucher issue and clearance',
      live: live,
      tagLabel: live ? 'Unavailable' : null,
      exportFilename: 'reward_redemptions.csv',
      exportEnabled: !live,
      exportRows: live
          ? null
          : () => [
                ['Week', 'Redemptions'],
                ...trend.map((p) => [p.label, p.value]),
                [],
                ['Reward', 'Redeemed'],
                ...context
                    .read<AnalyticsRepository>()
                    .rewardRedemptionMix
                    .map((s) => [s.label, s.value.round()]),
              ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: StatTile(live ? '—' : '142', 'Vouchers issued')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(live ? '—' : '118', 'Redeemed')),
            ],
          ),
          const SizedBox(height: 14),
          const Eyebrow('Weekly redemptions'),
          Panel(
            child: SizedBox(
              height: 150,
              child: live || trend.isEmpty
                  ? const NoFilteredData(
                      message:
                          'Weekly redemptions reporting is unavailable in this release.')
                  : SfCartesianChart(
                      plotAreaBorderWidth: 0,
                      primaryXAxis: const CategoryAxis(
                        majorGridLines: MajorGridLines(width: 0),
                        axisLine: AxisLine(width: 0),
                        labelStyle:
                            TextStyle(fontSize: 10, color: AppColors.inkSoft),
                      ),
                      primaryYAxis: const NumericAxis(
                        majorGridLines: MajorGridLines(
                            width: 0.6, color: AppColors.hairline),
                        axisLine: AxisLine(width: 0),
                        labelStyle:
                            TextStyle(fontSize: 10, color: AppColors.inkSoft),
                      ),
                      trackballBehavior: TrackballBehavior(
                          enable: true,
                          activationMode: ActivationMode.singleTap),
                      series: <CartesianSeries<_WeekPoint, String>>[
                        SplineSeries<_WeekPoint, String>(
                          dataSource: trend,
                          xValueMapper: (d, _) => d.label,
                          yValueMapper: (d, _) => d.value,
                          color: AppColors.success,
                          width: 2.4,
                          markerSettings: const MarkerSettings(
                              isVisible: true, height: 6, width: 6),
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
              child: live ||
                      context
                          .read<AnalyticsRepository>()
                          .rewardRedemptionMix
                          .isEmpty
                  ? const NoFilteredData(
                      message:
                          'Reward redemption distribution is unavailable in this release.')
                  : SfCircularChart(
                      legend: const Legend(
                          isVisible: true,
                          position: LegendPosition.right,
                          textStyle: TextStyle(fontSize: 12)),
                      series: <CircularSeries<ChartSlice, String>>[
                        DoughnutSeries<ChartSlice, String>(
                          dataSource: context
                              .read<AnalyticsRepository>()
                              .rewardRedemptionMix,
                          xValueMapper: (d, _) => d.label,
                          yValueMapper: (d, _) => d.value,
                          innerRadius: '65%',
                          cornerStyle: CornerStyle.bothCurve,
                          pointColorMapper: (d, i) =>
                              _sliceColors[i % _sliceColors.length],
                          dataLabelSettings:
                              const DataLabelSettings(isVisible: false),
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
