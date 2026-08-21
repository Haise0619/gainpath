import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../../app/theme.dart';
import '../../../../data/mock_data.dart';
import '../../../../widgets/shared.dart';
import '../report_widgets.dart';

/// Posture, Retention, and Gamification — the underlying mock data here
/// (`riskExercises`, `atRiskLeads`, the weekly-trend series) has no
/// date/branch dimension to genuinely filter, so these sections stay
/// illustrative and unaffected by the page's filter bar rather than
/// faking a control that wouldn't actually change anything.

class _WeekPoint {
  final String label;
  final int value;
  const _WeekPoint(this.label, this.value);
}

List<_WeekPoint> _weekSeries(List<int> values) =>
    List.generate(values.length, (i) => _WeekPoint('W${i + 1}', values[i]));

class PostureAccuracySection extends StatelessWidget {
  final GlobalKey anchorKey;
  const PostureAccuracySection({super.key, required this.anchorKey});

  @override
  Widget build(BuildContext context) {
    final trend = _weekSeries(MockData.postureWeeklyTrend);

    return ReportSection(
      anchorKey: anchorKey,
      title: 'Posture Accuracy Trend',
      subtitle: 'Which movements score worst',
      live: false,
      exportFilename: 'posture_accuracy.csv',
      exportRows: () => [
        ['Week', 'Avg form score %'],
        ...trend.map((p) => [p.label, p.value]),
        [],
        ['Exercise', 'Avg score', 'Category', 'Risk tier'],
        ...MockData.riskExercises
            .map((e) => [e[0], e[1], e[2], MockData.riskTierFor(int.parse(e[1].replaceAll('%', '')))]),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Average form score across all tracked movements, by week',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                SizedBox(
                  height: 170,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    primaryXAxis: const CategoryAxis(
                      majorGridLines: MajorGridLines(width: 0),
                      axisLine: AxisLine(width: 0),
                      labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                    ),
                    primaryYAxis: const NumericAxis(
                      minimum: 50,
                      maximum: 100,
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
                        color: AppColors.primary,
                        width: 2.4,
                        markerSettings: const MarkerSettings(isVisible: true, height: 6, width: 6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Eyebrow('Average form score by exercise'),
          Panel(
            child: Column(
              children: MockData.riskExercises.map((e) {
                final pct = int.parse(e[1].replaceAll('%', ''));
                final tier = MockData.riskTierFor(pct);
                return ProgressRow(
                  e[0],
                  pct / 100,
                  e[1],
                  color: tier == 'High'
                      ? AppColors.danger
                      : tier == 'Moderate'
                          ? AppColors.warning
                          : AppColors.success,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class RetentionRiskSection extends StatelessWidget {
  final GlobalKey anchorKey;
  const RetentionRiskSection({super.key, required this.anchorKey});

  static const _sliceColors = [AppColors.success, AppColors.warning, AppColors.danger];

  @override
  Widget build(BuildContext context) {
    return ReportSection(
      anchorKey: anchorKey,
      title: 'Member Retention & Dropout Risk',
      subtitle: 'Members going quiet',
      live: false,
      exportFilename: 'retention_risk.csv',
      exportRows: () => [
        ['Risk tier', 'Members'],
        ...MockData.retentionRiskMix.map((s) => [s.label, s.value.round()]),
        [],
        ['Member', 'Weakest movement', 'Score', 'Matched coach'],
        ...MockData.atRiskLeads.map((l) => [l.memberName, l.weakCategory, l.score, l.suggestion]),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Panel(
            child: SizedBox(
              height: 200,
              child: SfCircularChart(
                legend: const Legend(isVisible: true, position: LegendPosition.right, textStyle: TextStyle(fontSize: 12)),
                series: <CircularSeries<ChartSlice, String>>[
                  DoughnutSeries<ChartSlice, String>(
                    dataSource: MockData.retentionRiskMix,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    dataLabelMapper: (d, _) => '${d.value.round()}',
                    innerRadius: '68%',
                    cornerStyle: CornerStyle.bothCurve,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    pointColorMapper: (d, i) => _sliceColors[i % _sliceColors.length],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Eyebrow('Highest-priority members'),
          ...MockData.atRiskLeads.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.memberName, style: Theme.of(context).textTheme.titleMedium),
                            Text('Weakest: ${l.weakCategory}  ·  matched to ${l.suggestion}',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      statusPill('High'),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class GamificationSection extends StatelessWidget {
  final GlobalKey anchorKey;
  const GamificationSection({super.key, required this.anchorKey});

  static const _weeklyPoints = [12400, 13800, 12900, 15200, 16100, 15600, 17400];
  static const _badgesEarned = 418;
  static const _sliceColors = [AppColors.hairline, AppColors.accentTint, AppColors.accent, AppColors.success];

  @override
  Widget build(BuildContext context) {
    final points = _weekSeries(_weeklyPoints);
    final totalMembers = MockData.streakDistribution.fold<double>(0, (sum, s) => sum + s.value);
    final withStreak = MockData.streakDistribution
        .where((s) => s.label != '0-3 days')
        .fold<double>(0, (sum, s) => sum + s.value);
    final streakPct = totalMembers == 0 ? 0 : (withStreak / totalMembers * 100).round();

    return ReportSection(
      anchorKey: anchorKey,
      title: 'Gamification Engagement',
      subtitle: 'Points, badges, and streaks',
      live: false,
      exportFilename: 'gamification_engagement.csv',
      exportRows: () => [
        ['Week', 'Points earned'],
        ...points.map((p) => [p.label, p.value]),
        [],
        ['Streak bucket', 'Members'],
        ...MockData.streakDistribution.map((s) => [s.label, s.value.round()]),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: StatTile('$streakPct%', 'Members with a streak')),
              const SizedBox(width: 10),
              Expanded(child: StatTile('$_badgesEarned', 'Badges earned')),
            ],
          ),
          const SizedBox(height: 14),
          const Eyebrow('Points earned per week'),
          Panel(
            child: SizedBox(
              height: 160,
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
                tooltipBehavior: TooltipBehavior(enable: true, header: '', format: 'point.x  ·  point.y pts'),
                series: <CartesianSeries<_WeekPoint, String>>[
                  ColumnSeries<_WeekPoint, String>(
                    dataSource: points,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.value,
                    color: AppColors.accent,
                    width: 0.55,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Eyebrow('Streak length distribution'),
          Panel(
            child: SizedBox(
              height: 190,
              child: SfCircularChart(
                legend: const Legend(isVisible: true, position: LegendPosition.right, textStyle: TextStyle(fontSize: 12)),
                series: <CircularSeries<ChartSlice, String>>[
                  DoughnutSeries<ChartSlice, String>(
                    dataSource: MockData.streakDistribution,
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
