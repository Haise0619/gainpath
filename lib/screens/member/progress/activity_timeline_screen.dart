import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M5.2 (Activity timeline) — a weekly session-frequency column chart
/// up top (this report's own characteristic: density over time, not
/// trend or proportion), then the full chronological log below.
class ActivityTimelineScreen extends StatelessWidget {
  const ActivityTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const counts = MockData.sessionsPerWeek;
    const labels = MockData.sessionWeekLabels;
    final data = List.generate(counts.length, (i) => _WeekCount(labels[i], counts[i]));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filter',
            onPressed: () => _filter(context),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export',
            onPressed: () => showToast(context, 'Report saved to your device.'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          const Eyebrow('Sessions per week'),
          Panel(
            child: SizedBox(
              height: 160,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                ),
                primaryYAxis: const NumericAxis(isVisible: false),
                series: <CartesianSeries<_WeekCount, String>>[
                  ColumnSeries<_WeekCount, String>(
                    dataSource: data,
                    xValueMapper: (d, _) => d.label,
                    yValueMapper: (d, _) => d.count,
                    color: AppColors.primarySoft,
                    width: 0.5,
                    borderRadius: BorderRadius.circular(5),
                    dataLabelSettings:
                        const DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Log'),
          ...MockData.history.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.fitness_center_rounded,
                            size: 19, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.exercise, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              '${_ago(r.date)}  ·  ${r.reps} reps  ·  ${r.durationMin} min',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${r.accuracy}%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: r.accuracy >= 80 ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  void _filter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Eyebrow('Date range'),
            Wrap(
              spacing: 8,
              children: const [
                Chip(label: Text('Last 7 days')),
                Chip(label: Text('Last 30 days')),
                Chip(label: Text('All time')),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                showToast(context, 'Filters applied.');
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCount {
  final String label;
  final int count;
  const _WeekCount(this.label, this.count);
}
