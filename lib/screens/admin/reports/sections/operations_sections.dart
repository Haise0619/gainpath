import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../../app/theme.dart';
import '../../../../data/mock_data.dart';
import '../../../../widgets/shared.dart';
import '../report_widgets.dart';

/// The three report sections genuinely derivable from `MockData.allBookings`
/// — each `Booking` carries a real `start` date and `branch`, so these are
/// the sections that actually react to the page's date/branch filter.

class _HourPoint {
  final String label;
  final int count;
  const _HourPoint(this.label, this.count);
}

class UsageEngagementSection extends StatelessWidget {
  final GlobalKey anchorKey;
  final ReportFilter filter;
  const UsageEngagementSection({super.key, required this.anchorKey, required this.filter});

  @override
  Widget build(BuildContext context) {
    final allDates = MockData.allBookings.map((b) => b.start).toList();
    var bookings = MockData.allBookings.toList();
    if (filter.branch != null) bookings = bookings.where((b) => b.branch == filter.branch).toList();
    bookings = bookings.where((b) => b.start.isAfter(filter.cutoff(allDates))).toList();

    final weekday = bookings.where((b) => b.start.weekday <= 5).length;
    final weekend = bookings.length - weekday;
    final weekendPct = bookings.isEmpty ? 0 : (weekend / bookings.length * 100).round();

    final hourData = List.generate(24, (h) => _HourPoint('$h', MockData.usageByHour[h]));

    return ReportSection(
      anchorKey: anchorKey,
      title: 'Platform Usage Pattern',
      subtitle: 'When members are actually training',
      live: false,
      exportFilename: 'usage_pattern.csv',
      exportRows: () => [
        ['Hour', 'Sessions'],
        ...hourData.map((h) => [h.label, h.count]),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sessions started, by hour — illustrative, all platform activity',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 10),
                SizedBox(
                  height: 190,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    primaryXAxis: const CategoryAxis(
                      majorGridLines: MajorGridLines(width: 0),
                      axisLine: AxisLine(width: 0),
                      interval: 3,
                      labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                    ),
                    primaryYAxis: const NumericAxis(
                      majorGridLines: MajorGridLines(width: 0.6, color: AppColors.hairline),
                      axisLine: AxisLine(width: 0),
                      labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                    ),
                    tooltipBehavior: TooltipBehavior(enable: true, header: '', format: 'point.x h  ·  point.y sessions'),
                    series: <CartesianSeries<_HourPoint, String>>[
                      ColumnSeries<_HourPoint, String>(
                        dataSource: hourData,
                        xValueMapper: (d, _) => d.label,
                        yValueMapper: (d, _) => d.count,
                        color: AppColors.primary,
                        width: 0.7,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: StatTile('${bookings.length}', 'Coaching sessions in this period',
                      valueColor: AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: StatTile('$weekendPct%', 'Fall on a weekend')),
            ],
          ),
        ],
      ),
    );
  }
}

class CoachBookingUtilizationSection extends StatelessWidget {
  final GlobalKey anchorKey;
  final ReportFilter filter;
  const CoachBookingUtilizationSection({super.key, required this.anchorKey, required this.filter});

  @override
  Widget build(BuildContext context) {
    final allDates = MockData.allBookings.map((b) => b.start).toList();
    final cutoff = filter.cutoff(allDates);
    final rangeDays = filter.rangeDays(allDates);
    var coaches = MockData.coaches.toList();
    if (filter.branch != null) coaches = coaches.where((c) => c.branch == filter.branch).toList();

    final rows = coaches.map((c) {
      final sessions = MockData.allBookings
          .where((b) => b.coachId == c.id && b.start.isAfter(cutoff) && b.status != 'Cancelled')
          .length;
      final capacity = MockData.dailyBookingCap * rangeDays;
      final utilization = capacity == 0 ? 0.0 : (sessions / capacity).clamp(0.0, 1.0);
      return (coach: c, sessions: sessions, utilization: utilization);
    }).toList();

    return ReportSection(
      anchorKey: anchorKey,
      title: 'Coach Booking Utilization',
      subtitle: 'How full the roster is',
      live: true,
      exportFilename: 'coach_booking_utilization.csv',
      exportRows: () => [
        ['Coach', 'Branch', 'Sessions', 'Utilization %'],
        ...rows.map((r) => [r.coach.name, r.coach.branch, r.sessions, (r.utilization * 100).round()]),
      ],
      child: rows.isEmpty
          ? const NoFilteredData(message: 'No coaches match this branch filter.')
          : Panel(
              child: Column(
                children: rows
                    .map((r) => ProgressRow(
                          r.coach.name,
                          r.utilization,
                          '${(r.utilization * 100).round()}%  ·  ${r.sessions} sessions',
                          color: r.utilization >= 0.75
                              ? AppColors.success
                              : r.utilization >= 0.4
                                  ? AppColors.warning
                                  : AppColors.danger,
                        ))
                    .toList(),
              ),
            ),
    );
  }
}

class CoachPerformanceSection extends StatelessWidget {
  final GlobalKey anchorKey;
  final ReportFilter filter;
  const CoachPerformanceSection({super.key, required this.anchorKey, required this.filter});

  @override
  Widget build(BuildContext context) {
    final allDates = MockData.allBookings.map((b) => b.start).toList();
    final cutoff = filter.cutoff(allDates);
    var coaches = MockData.coaches.toList();
    if (filter.branch != null) coaches = coaches.where((c) => c.branch == filter.branch).toList();

    final sessionsInPeriod = {
      for (final c in coaches)
        c.id: MockData.allBookings.where((b) => b.coachId == c.id && b.start.isAfter(cutoff)).length,
    };

    return ReportSection(
      anchorKey: anchorKey,
      title: 'Coach Performance Comparison',
      subtitle: 'Ratings across the roster',
      live: true,
      exportFilename: 'coach_performance.csv',
      exportRows: () => [
        ['Coach', 'Rating', 'Reviews', 'Sessions in period', 'Response time'],
        ...coaches.map((c) =>
            [c.name, c.rating, c.reviews, sessionsInPeriod[c.id], c.responseTime]),
      ],
      child: coaches.isEmpty
          ? const NoFilteredData(message: 'No coaches match this branch filter.')
          : Column(
              children: [
                Panel(
                  child: SizedBox(
                    height: 180,
                    child: SfCartesianChart(
                      plotAreaBorderWidth: 0,
                      primaryXAxis: const CategoryAxis(
                        majorGridLines: MajorGridLines(width: 0),
                        axisLine: AxisLine(width: 0),
                        labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                        labelIntersectAction: AxisLabelIntersectAction.wrap,
                      ),
                      primaryYAxis: const NumericAxis(
                        minimum: 0,
                        maximum: 5,
                        majorGridLines: MajorGridLines(width: 0.6, color: AppColors.hairline),
                        axisLine: AxisLine(width: 0),
                        labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                      ),
                      tooltipBehavior: TooltipBehavior(enable: true, header: '', format: 'point.x  ·  point.y ★'),
                      series: <CartesianSeries<Coach, String>>[
                        ColumnSeries<Coach, String>(
                          dataSource: coaches,
                          xValueMapper: (c, _) => c.name,
                          yValueMapper: (c, _) => c.rating,
                          color: AppColors.accent,
                          width: 0.55,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: List.generate(coaches.length, (i) {
                      final c = coaches[i];
                      return Column(
                        children: [
                          if (i > 0) const Divider(height: 1, indent: 16),
                          ListTile(
                            dense: true,
                            title: Text(c.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: Text('${c.reviews} reviews  ·  ${sessionsInPeriod[c.id]} sessions this period',
                                style: const TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                                const SizedBox(width: 3),
                                Text('${c.rating}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}
