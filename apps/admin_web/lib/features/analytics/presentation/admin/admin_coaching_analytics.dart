import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../application/admin_commerce_report.dart';
import '../../application/admin_reporting_gateway.dart';
import 'analytics_shared_components.dart';

enum CoachingTab {
  overview('Overview', Icons.dashboard_outlined),
  coachComparison('Coach Comparison', Icons.people_outline_rounded);

  const CoachingTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum CoachSortOption {
  bookingsDesc('Most bookings'),
  bookingsAsc('Least bookings'),
  completedDesc('Most completed'),
  consultationsDesc('Most consultations'),
  reviewsDesc('Most reviews'),
  nameAsc('Name (A–Z)');

  const CoachSortOption(this.label);
  final String label;
}

/// Comprehensive Coaching Performance Dashboard.
///
/// Provides a high-density, professional analytics workspace for coach booking activity,
/// consultation outcomes, review metrics, and comparative roster performance.
class AdminCoachingAnalytics extends StatefulWidget {
  const AdminCoachingAnalytics({
    super.key,
    required this.snapshot,
    required this.filter,
    this.live = false,
    this.anchorKey,
    this.coachPerfKey,
    this.compact = false,
  });

  final AdminReportingSnapshot? snapshot;
  final ReportFilter filter;
  final bool live;
  final GlobalKey? anchorKey;
  final GlobalKey? coachPerfKey;
  final bool compact;

  @override
  State<AdminCoachingAnalytics> createState() => _AdminCoachingAnalyticsState();
}

class _AdminCoachingAnalyticsState extends State<AdminCoachingAnalytics> {
  CoachingTab _selectedTab = CoachingTab.overview;
  String? _selectedCoachId;
  String _searchQuery = '';
  CoachSortOption _sortOption = CoachSortOption.bookingsDesc;
  final GlobalKey _fallbackAnchor = GlobalKey();

  CoachRepository? get _coachRepo {
    try {
      return context.read<CoachRepository>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.snapshot?.commerce;

    // Fallback if commerce report is unavailable
    if (report == null) {
      return _buildLegacyFallback(context);
    }

    if (widget.compact) {
      return _buildCompactView(context, report);
    }

    return ReportSection(
      anchorKey: widget.anchorKey ?? _fallbackAnchor,
      title: 'Coach Booking Activity',
      subtitle:
          'Recorded coach booking activity and session outcomes · organization-wide',
      live: true,
      tagLabel: 'Coaching activity',
      exportFilename: 'coach_performance.csv',
      exportEnabled: true,
      exportRows: () => report.csv(coach: true, filter: _selectedCoachId),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildTabBar(),
              _buildExportActions(report),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedTab == CoachingTab.overview)
            _buildOverviewWorkspace(context, report)
          else
            _buildCoachComparisonWorkspace(context, report),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: CoachingTab.values.map((tab) {
          final isSelected = _selectedTab == tab;
          return InkWell(
            onTap: () => setState(() => _selectedTab = tab),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: 16,
                    color: isSelected ? AppColors.primary : AppColors.inkSoft,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExportActions(AdminCommerceReport report) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(
          label: Text('${report.coaches.length} Coaches recorded'),
          visualDensity: VisualDensity.compact,
          backgroundColor: AppColors.surfaceAlt,
          side: const BorderSide(color: AppColors.hairline),
        ),
        IconButton(
          tooltip: 'Export Coach Performance CSV',
          onPressed: () => downloadCsv(
            'coach_performance.csv',
            report.csv(coach: true, filter: _selectedCoachId),
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: OVERVIEW WORKSPACE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverviewWorkspace(
      BuildContext context, AdminCommerceReport report) {
    final coaches = report.coaches;
    final totalBookings = coaches.fold<int>(0, (sum, c) => sum + c['bookings']);
    final totalConsultations =
        coaches.fold<int>(0, (sum, c) => sum + c['consultations']);
    final totalCompleted =
        coaches.fold<int>(0, (sum, c) => sum + c['completed']);
    final totalReviews =
        coaches.fold<int>(0, (sum, c) => sum + c['reviewCount']);
    final totalRatingSum =
        coaches.fold<int>(0, (sum, c) => sum + c['ratingSum']);
    final totalScheduledStarts =
        coaches.fold<int>(0, (sum, c) => sum + c['scheduledStarts']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Cards Row
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 900
                ? (constraints.maxWidth - 48) / 5
                : constraints.maxWidth > 600
                    ? (constraints.maxWidth - 24) / 3
                    : (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AnalyticsMetricCard(
                  width: cardWidth,
                  label: 'Bookings created',
                  value: '$totalBookings',
                  icon: Icons.event_available_outlined,
                  contextNote: 'Created in selected period',
                  highlighted: true,
                ),
                AnalyticsMetricCard(
                  width: cardWidth,
                  label: 'Published consultations',
                  value: '$totalConsultations',
                  icon: Icons.rate_review_outlined,
                  contextNote: 'Published in selected period',
                ),
                AnalyticsMetricCard(
                  width: cardWidth,
                  label: 'Review samples',
                  value: '$totalReviews',
                  icon: Icons.star_outline_rounded,
                  contextNote: totalReviews == 0
                      ? 'No reviews recorded'
                      : 'Average ${(totalRatingSum / totalReviews).toStringAsFixed(1)} ★',
                ),
                AnalyticsMetricCard(
                  width: cardWidth,
                  label: 'Completed outcomes',
                  value: '$totalCompleted',
                  icon: Icons.task_alt_outlined,
                  contextNote: totalBookings > 0
                      ? '${(totalCompleted / totalBookings * 100).toStringAsFixed(1)}% of created bookings'
                      : 'No bookings recorded',
                ),
                AnalyticsMetricCard(
                  width: cardWidth,
                  label: 'Scheduled starts',
                  value: '$totalScheduledStarts',
                  icon: Icons.calendar_today_outlined,
                  contextNote: 'Appointment time · may be upcoming',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),

        // 2-Column Section: Time-series Activity + Outcome Status Breakdown
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final leftWidth = wide ? (constraints.maxWidth - 20) * 0.62 : constraints.maxWidth;
            final rightWidth = wide ? (constraints.maxWidth - 20) * 0.38 : constraints.maxWidth;

            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: leftWidth,
                        child: _buildCoachingActivityTrendCard(coaches),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: rightWidth,
                        child: _buildBookingOutcomesCard(coaches, totalBookings, totalScheduledStarts),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildCoachingActivityTrendCard(coaches),
                      const SizedBox(height: 16),
                      _buildBookingOutcomesCard(coaches, totalBookings, totalScheduledStarts),
                    ],
                  );
          },
        ),
        const SizedBox(height: 20),

        // Horizontal Bar Chart: Bookings by Coach
        _buildBookingsByCoachCard(coaches),
        const SizedBox(height: 20),

        // Capacity Utilization Notice
        _buildCapacityUtilizationNotice(),
        const SizedBox(height: 14),

        // Methodology & Data Scope Disclosure
        _buildMethodologyDisclosure(report),
      ],
    );
  }

  Widget _buildCoachingActivityTrendCard(List<CommerceRow> coaches) {
    final dateMap = <String, Map<String, dynamic>>{};
    for (final row in coaches) {
      for (final day in row.daily) {
        final d = day['date'] as String;
        final target = dateMap.putIfAbsent(
          d,
          () => {
            'date': DateTime.parse('${d}T00:00:00Z'),
            'dateStr': d,
            'bookings': 0,
            'consultations': 0,
          },
        );
        target['bookings'] =
            (target['bookings'] as int) + (day['bookings'] as int? ?? 0);
        target['consultations'] = (target['consultations'] as int) +
            (day['consultations'] as int? ?? 0);
      }
    }
    final days = dateMap.values.toList()
      ..sort((a, b) =>
          (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return AnalyticsChartCard(
      title: 'Coaching activity over time',
      subtitle:
          'Daily created bookings and published consultations · Event timestamps',
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'UTC+08:00',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
      footer: const Text(
        'Bookings use creation time; consultations use publication time. Missing dates have no recorded events.',
        style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
      ),
      child: days.isEmpty
          ? const SizedBox(
              height: 240,
              child: Center(
                child: Text(
                  'No activity records in this reporting period.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              ),
            )
          : SizedBox(
              height: 250,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                margin: EdgeInsets.zero,
                primaryXAxis: const DateTimeAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelStyle:
                      TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                primaryYAxis: const NumericAxis(
                  minimum: 0,
                  decimalPlaces: 0,
                  majorGridLines: MajorGridLines(
                    width: 0.6,
                    color: AppColors.hairline,
                  ),
                  axisLine: AxisLine(width: 0),
                  labelStyle:
                      TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                legend: const Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<Map<String, dynamic>, DateTime>>[
                  ColumnSeries<Map<String, dynamic>, DateTime>(
                    name: 'Bookings created',
                    color: AppColors.primary,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                    dataSource: days,
                    xValueMapper: (d, _) => d['date'] as DateTime,
                    yValueMapper: (d, _) => d['bookings'] as int,
                  ),
                  ColumnSeries<Map<String, dynamic>, DateTime>(
                    name: 'Consultations published',
                    color: const Color(0xFFE5A044),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                    dataSource: days,
                    xValueMapper: (d, _) => d['date'] as DateTime,
                    yValueMapper: (d, _) => d['consultations'] as int,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBookingOutcomesCard(
      List<CommerceRow> coaches, int totalBookings, int totalScheduledStarts) {
    final confirmed = coaches.fold<int>(0, (s, c) => s + c['confirmed']);
    final completed = coaches.fold<int>(0, (s, c) => s + c['completed']);
    final pendingHold = coaches.fold<int>(0, (s, c) => s + c['pendingHold']);
    final cancelled = coaches.fold<int>(0, (s, c) => s + c['cancelled']);
    final expired = coaches.fold<int>(0, (s, c) => s + c['expired']);
    final refunded = coaches.fold<int>(0, (s, c) => s + c['refunded']);
    final missingConsultations =
        coaches.fold<int>(0, (s, c) => s + c['missingConsultations']);

    final counts = {
      'confirmed': confirmed,
      'completed': completed,
      'pendingHold': pendingHold,
      'cancelled': cancelled,
      'expired': expired,
      'refunded': refunded,
    };

    String pct(int count) => totalBookings > 0
        ? ' (${(count / totalBookings * 100).toStringAsFixed(1)}%)'
        : '';

    return AnalyticsChartCard(
      title: 'Booking outcomes',
      subtitle: 'Status breakdown of created bookings',
      footer: const Text(
        'Scheduled starts use appointment time; booking outcomes reflect current lifecycle status of bookings created within range.',
        style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Horizontal Progress Bar
          _buildOutcomeSegmentedBar(totalBookings, counts),
          const SizedBox(height: 16),

          // Outcome Detail Rows
          _buildOutcomeRow('Confirmed', confirmed, const Color(0xFF369363), pct(confirmed)),
          _buildOutcomeRow('Completed', completed, AppColors.primary, pct(completed)),
          _buildOutcomeRow('Pending hold', pendingHold, const Color(0xFFF59E0B), pct(pendingHold)),
          _buildOutcomeRow('Cancelled', cancelled, const Color(0xFF94A3B8), pct(cancelled)),
          _buildOutcomeRow('Expired', expired, const Color(0xFFEF4444), pct(expired)),
          _buildOutcomeRow('Refunded', refunded, const Color(0xFFF97316), pct(refunded)),

          const Divider(height: 20, color: AppColors.hairline),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completed w/o consultation',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              Text(
                '$missingConsultations',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scheduled starts in range',
                style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              Text(
                '$totalScheduledStarts',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeSegmentedBar(int total, Map<String, int> counts) {
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.hairline,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (counts['confirmed']! > 0)
              Expanded(
                flex: counts['confirmed']!,
                child: Container(color: const Color(0xFF369363)),
              ),
            if (counts['completed']! > 0)
              Expanded(
                flex: counts['completed']!,
                child: Container(color: AppColors.primary),
              ),
            if (counts['pendingHold']! > 0)
              Expanded(
                flex: counts['pendingHold']!,
                child: Container(color: const Color(0xFFF59E0B)),
              ),
            if (counts['cancelled']! > 0)
              Expanded(
                flex: counts['cancelled']!,
                child: Container(color: const Color(0xFF94A3B8)),
              ),
            if (counts['expired']! > 0)
              Expanded(
                flex: counts['expired']!,
                child: Container(color: const Color(0xFFEF4444)),
              ),
            if (counts['refunded']! > 0)
              Expanded(
                flex: counts['refunded']!,
                child: Container(color: const Color(0xFFF97316)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutcomeRow(
      String label, int count, Color color, String percentStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            '$count$percentStr',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsByCoachCard(List<CommerceRow> coaches) {
    final sorted = [...coaches]..sort((a, b) {
        final bCount = b['bookings'];
        final aCount = a['bookings'];
        if (bCount != aCount) return bCount.compareTo(aCount);
        return _resolveName(a).compareTo(_resolveName(b));
      });

    return AnalyticsChartCard(
      title: 'Bookings by coach',
      subtitle: 'Recorded booking activity by coach · Horizontal ranking',
      trailing: TextButton.icon(
        onPressed: () => setState(() => _selectedTab = CoachingTab.coachComparison),
        icon: const Icon(Icons.table_chart_outlined, size: 16),
        label: const Text('View Comparison Table'),
      ),
      footer: const Text(
        'Created bookings reflect scheduling demand; they do not measure completed attendance, teaching quality, or available capacity.',
        style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
      ),
      child: sorted.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No coach activity records available.'),
              ),
            )
          : SizedBox(
              height: math.max(200.0, math.min(420.0, sorted.length * 40.0 + 40.0)),
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                margin: EdgeInsets.zero,
                primaryXAxis: CategoryAxis(
                  isInversed: true,
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                  labelIntersectAction: AxisLabelIntersectAction.wrap,
                ),
                primaryYAxis: const NumericAxis(
                  minimum: 0,
                  decimalPlaces: 0,
                  majorGridLines: MajorGridLines(
                    width: 0.6,
                    color: AppColors.hairline,
                  ),
                  axisLine: AxisLine(width: 0),
                  labelStyle:
                      TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<CommerceRow, String>>[
                  BarSeries<CommerceRow, String>(
                    name: 'Bookings created',
                    color: AppColors.primary,
                    borderRadius:
                        const BorderRadius.horizontal(right: Radius.circular(4)),
                    dataSource: sorted,
                    xValueMapper: (c, _) =>
                        _truncate(_resolveName(c), 18),
                    yValueMapper: (c, _) => c['bookings'],
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCapacityUtilizationNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: Color(0xFF64748B)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach utilization unavailable',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Historical available-time capacity is not available for this reporting period. Capacity-based utilization percentages are not derived without recorded availability evidence.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodologyDisclosure(AdminCommerceReport report) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: const Icon(
            Icons.help_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          title: const Text(
            'Reporting Methodology & Data Coverage Disclosures',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          subtitle: Text(
            'Malaysia Time (UTC+08:00) · Bounded reads · Event timestamps',
            style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• Bookings are counted using booking creation timestamps.\n'
                    '• Scheduled starts use appointment start timestamps and may include upcoming sessions.\n'
                    '• Published consultations use consultation creation timestamps.\n'
                    '• Current coach rosters and weekly schedules are not applied retroactively.\n'
                    '• Review ratings reflect actual customer submissions; small sample sizes are preserved as counts.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                      height: 1.45,
                    ),
                  ),
                  const Divider(height: 18, color: AppColors.hairline),
                  const Text(
                    'Advanced Data Diagnostics:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      for (final entry in report.coverage.entries)
                        Text(
                          '${entry.key}: ${entry.value}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.inkSoft,
                          ),
                        ),
                      Text(
                        'As of: ${report.asOf.toUtc().toIso8601String()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: COACH COMPARISON WORKSPACE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCoachComparisonWorkspace(
      BuildContext context, AdminCommerceReport report) {
    final coaches = report.coaches;

    // Filter by search query
    var filtered = coaches.where((c) {
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final name = _resolveName(c).toLowerCase();
      final id = c.id.toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();

    // Sort coaches
    filtered.sort((a, b) {
      switch (_sortOption) {
        case CoachSortOption.bookingsDesc:
          return b['bookings'].compareTo(a['bookings']);
        case CoachSortOption.bookingsAsc:
          return a['bookings'].compareTo(b['bookings']);
        case CoachSortOption.completedDesc:
          return b['completed'].compareTo(a['completed']);
        case CoachSortOption.consultationsDesc:
          return b['consultations'].compareTo(a['consultations']);
        case CoachSortOption.reviewsDesc:
          return b['reviewCount'].compareTo(a['reviewCount']);
        case CoachSortOption.nameAsc:
          return _resolveName(a).compareTo(_resolveName(b));
      }
    });

    final selectedCoach = _selectedCoachId == null
        ? null
        : coaches.where((c) => c.id == _selectedCoachId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Filter Toolbar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              // Search input
              SizedBox(
                width: 260,
                height: 38,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search coaches by name…',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.hairline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Coach Dropdown Selector
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedCoachId,
                    hint: const Text(
                      'All Coaches',
                      style: TextStyle(fontSize: 13, color: AppColors.ink),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'All Coaches',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      ...coaches.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(
                            _resolveName(c),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedCoachId = val),
                  ),
                ),
              ),

              // Sort Option Dropdown
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CoachSortOption>(
                    value: _sortOption,
                    items: CoachSortOption.values.map((opt) {
                      return DropdownMenuItem<CoachSortOption>(
                        value: opt,
                        child: Text(
                          opt.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _sortOption = val);
                    },
                  ),
                ),
              ),

              if (_selectedCoachId != null)
                TextButton.icon(
                  onPressed: () => setState(() => _selectedCoachId = null),
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Clear Filter'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // If a specific coach is selected, show focused summary
        if (selectedCoach != null) ...[
          _buildIndividualCoachFocus(selectedCoach),
          const SizedBox(height: 20),
        ],

        // Detailed Comparison Table
        _buildComparisonTable(filtered),
        const SizedBox(height: 20),

        // Capacity Utilization Notice
        _buildCapacityUtilizationNotice(),
        const SizedBox(height: 14),

        // Methodology & Data Scope Disclosure
        _buildMethodologyDisclosure(report),
      ],
    );
  }

  Widget _buildIndividualCoachFocus(CommerceRow coach) {
    final name = _resolveName(coach);
    final bookings = coach['bookings'];
    final completed = coach['completed'];
    final consultations = coach['consultations'];
    final reviews = coach['reviewCount'];
    final ratingSum = coach['ratingSum'];
    final scheduledStarts = coach['scheduledStarts'];
    final cancelled = coach['cancelled'];

    final coachEntity = _findCoachEntity(coach.id);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryTint,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          if (_isTestFixture(coach)) ...[
                            const SizedBox(width: 8),
                            _buildTestBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${coach.id}${coachEntity?.branch != null ? ' · ${coachEntity!.branch}' : ''}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedCoachId = null),
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Close Focus'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildMiniMetric('Bookings', '$bookings', Icons.event_available_outlined),
              _buildMiniMetric('Completed', '$completed', Icons.task_alt_outlined),
              _buildMiniMetric('Consultations', '$consultations', Icons.rate_review_outlined),
              _buildMiniMetric(
                'Reviews',
                reviews == 0 ? '0' : '$reviews (${(ratingSum / reviews).toStringAsFixed(1)} ★)',
                Icons.star_outline_rounded,
              ),
              _buildMiniMetric('Scheduled Starts', '$scheduledStarts', Icons.calendar_today_outlined),
              _buildMiniMetric(
                'Cancellation Rate',
                bookings == 0 ? '—' : '${(cancelled / bookings * 100).toStringAsFixed(1)}%',
                Icons.cancel_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(List<CommerceRow> coaches) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Coach Directory & Performance Comparison',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  '${coaches.length} Coaches',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          if (coaches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No coaches match your search criteria.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 22,
                horizontalMargin: 16,
                headingRowColor: WidgetStateProperty.all(
                  AppColors.surfaceAlt.withValues(alpha: 0.6),
                ),
                dividerThickness: 0.6,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('Coach')),
                  DataColumn(label: Text('Bookings'), numeric: true),
                  DataColumn(label: Text('Completed'), numeric: true),
                  DataColumn(label: Text('Consultations'), numeric: true),
                  DataColumn(label: Text('Reviews'), numeric: true),
                  DataColumn(label: Text('Starts'), numeric: true),
                  DataColumn(label: Text('Cancellation'), numeric: true),
                  DataColumn(label: Text('Action')),
                ],
                rows: coaches.map((c) {
                  final name = _resolveName(c);
                  final isTest = _isTestFixture(c);
                  final isSelected = _selectedCoachId == c.id;
                  final bookings = c['bookings'];
                  final reviews = c['reviewCount'];
                  final ratingSum = c['ratingSum'];
                  final cancelled = c['cancelled'];

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (_) => setState(() {
                      _selectedCoachId = isSelected ? null : c.id;
                    }),
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primaryTint,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _truncate(name, 22),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    if (isTest) ...[
                                      const SizedBox(width: 6),
                                      _buildTestBadge(),
                                    ],
                                  ],
                                ),
                                Text(
                                  _truncate(c.id, 16),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.inkSoft,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text('$bookings',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text('${c['completed']}')),
                      DataCell(Text('${c['consultations']}')),
                      DataCell(Text(reviews == 0
                          ? '0'
                          : '$reviews (${(ratingSum / reviews).toStringAsFixed(1)} ★)')),
                      DataCell(Text('${c['scheduledStarts']}')),
                      DataCell(Text(bookings == 0
                          ? '—'
                          : '${(cancelled / bookings * 100).toStringAsFixed(1)}%')),
                      DataCell(
                        TextButton(
                          onPressed: () => setState(() {
                            _selectedCoachId = isSelected ? null : c.id;
                          }),
                          child: Text(isSelected ? 'Selected' : 'View Focus'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMPACT & LEGACY FALLBACK VIEWS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCompactView(BuildContext context, AdminCommerceReport report) {
    final totalBookings =
        report.coaches.fold<int>(0, (sum, c) => sum + c['bookings']);
    final totalConsultations =
        report.coaches.fold<int>(0, (sum, c) => sum + c['consultations']);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Coach Booking Activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Chip(
                label: Text('${report.coaches.length} Coaches'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile('$totalBookings', 'Created bookings'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile('$totalConsultations', 'Consultations published'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyFallback(BuildContext context) {
    final snapshot = widget.snapshot;
    final ops = snapshot?.operations;

    if (ops != null) {
      final total = snapshot!.totalBookingsCount ?? 0;
      return ReportSection(
        anchorKey: widget.anchorKey ?? _fallbackAnchor,
        title: 'Coach booking activity',
        subtitle:
            'Recorded booking activity · capacity-based utilization remains unavailable',
        live: true,
        tagLabel: 'Booking activity',
        exportFilename: 'coach_booking_activity.csv',
        exportRows: () => [
          ['GainPath booking activity', 'Not capacity utilization'],
          [
            'Start inclusive UTC',
            snapshot.query.range.start.toUtc().toIso8601String()
          ],
          [
            'End exclusive UTC',
            snapshot.query.range.end.toUtc().toIso8601String()
          ],
          ['Timezone', 'Asia/Kuala_Lumpur'],
          ['Bookings created in range', total],
          ['Confirmed/completed scheduled starts', ops.scheduledStarts],
          ['Current status of bookings created in range', 'Count'],
          for (final e in ops.statuses.entries) [e.key, e.value],
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: StatTile('$total', 'Bookings created in range')),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    '${ops.scheduledStarts}',
                    'Confirmed/completed starts in range',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                children: [
                  for (final e in ops.statuses.entries)
                    ProgressRow(
                      e.key.replaceAll('_', ' '),
                      total == 0 ? 0 : e.value / total,
                      '${e.value} bookings',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildCapacityUtilizationNotice(),
          ],
        ),
      );
    }

    return ReportSection(
      anchorKey: widget.anchorKey ?? _fallbackAnchor,
      title: 'Coaching Analytics',
      subtitle: 'Coach comparison awaits a compatible reporting service.',
      live: false,
      tagLabel: 'Unavailable',
      exportFilename: 'coach_performance.csv',
      exportEnabled: false,
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('Coaching analytics data is currently unavailable.'),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _resolveName(CommerceRow row) {
    final repo = _coachRepo;
    if (repo != null) {
      try {
        final match = repo.coaches.where((c) => c.id == row.id).firstOrNull;
        if (match != null && match.name.trim().isNotEmpty) {
          return match.name.trim();
        }
      } catch (_) {}
    }
    if (row.name.trim().isNotEmpty &&
        !row.name.startsWith('Coach ') &&
        row.name != row.id) {
      return row.name.trim();
    }
    if (row.name.trim().isNotEmpty) {
      return row.name.trim();
    }
    return 'Coach (${row.id.length > 8 ? '${row.id.substring(0, 8)}…' : row.id})';
  }

  Coach? _findCoachEntity(String coachId) {
    final repo = _coachRepo;
    if (repo == null) return null;
    try {
      return repo.coaches.where((c) => c.id == coachId).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  bool _isTestFixture(CommerceRow row) {
    final n = row.name.toUpperCase();
    return n.contains('[DISPOSABLE') ||
        n.contains('SYNTHETIC UAT') ||
        n.contains('TEST FIXTURE') ||
        n.contains('[DISPOSABLE SANDBOX]');
  }

  Widget _buildTestBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Text(
        'TEST',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  String _truncate(String str, int maxLen) {
    if (str.length <= maxLen) return str;
    return '${str.substring(0, maxLen)}…';
  }
}
