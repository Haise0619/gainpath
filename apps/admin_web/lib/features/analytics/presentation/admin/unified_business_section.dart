import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/business_dashboard_metrics.dart';
import '../../application/unified_admin_summary.dart';

/// Business presentation; provenance remains in validated source contracts.
class UnifiedBusinessSection extends StatelessWidget {
  const UnifiedBusinessSection(
      {super.key, required this.snapshot, this.anchorKey});
  final AdminReportingSnapshot snapshot;
  final GlobalKey? anchorKey;
  @override
  Widget build(BuildContext context) {
    if (snapshot.unified == null) return const SizedBox.shrink();
    final m = BusinessDashboardMetrics(snapshot, null);
    String money(int n) => 'MYR ${(n / 100).toStringAsFixed(2)}';
    return ReportSection(
        anchorKey: anchorKey ?? GlobalKey(),
        title: 'Revenue Overview',
        subtitle: 'Recorded membership and coaching value',
        live: true,
        tagLabel: 'Business activity',
        exportFilename: 'gainpath-business-overview.csv',
        exportEnabled: true,
        exportRows: m.csv,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: 190,
                child: StatTile(money(m.revenueMinor), 'Recorded revenue')),
            SizedBox(
                width: 190,
                child:
                    StatTile(money(m.membershipMinor), 'Membership Revenue')),
            SizedBox(
                width: 190,
                child: StatTile(money(m.coachingMinor), 'Coaching Revenue')),
          ]),
          const SizedBox(height: 20),
          const Text('Monthly Revenue Trend',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(
              height: 230,
              child: SfCartesianChart(
                  primaryXAxis: const CategoryAxis(
                      labelIntersectAction: AxisLabelIntersectAction.hide),
                  tooltipBehavior: TooltipBehavior(
                      enable: true, format: 'point.x · MYR point.y'),
                  primaryYAxis:
                      const NumericAxis(title: AxisTitle(text: 'MYR')),
                  series: <CartesianSeries<UnifiedRevenueMonth, String>>[
                    LineSeries<UnifiedRevenueMonth, String>(
                        animationDuration: 0,
                        dataSource: m.monthly,
                        xValueMapper: (r, _) => r.month,
                        yValueMapper: (r, _) => r.minor / 100,
                        color: AppColors.primary,
                        name: 'Recorded revenue')
                  ])),
          const Text(BusinessDashboardMetrics.revenueDefinition),
          const SizedBox(height: 20),
          Wrap(spacing: 24, runSpacing: 12, children: [
            Text('Active Subscriptions: ${m.activeSubscriptions ?? '—'}'),
            Text('Booking activity: ${m.bookings}'),
            Text('Completed: ${m.completed}'),
            Text('Cancelled: ${m.cancelled}')
          ]),
          if (m.tiers != null) ...[
            const SizedBox(height: 12),
            const Text('Plan distribution'),
            Wrap(spacing: 16, runSpacing: 8, children: [
              for (final e in m.tiers!.entries) Text('${e.key}: ${e.value}'),
            ]),
          ],
          const SizedBox(height: 10),
          const Text(
              'Plan distribution includes expired FYP scenario subscriptions and unknown canonical plans. Active subscriptions count recognized canonical plans and active FYP scenario subscriptions. Appointment outcomes use current recorded status for bookings created in this period.'),
        ]));
  }
}
