import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'analytics_shared_components.dart';

class BranchReportDialog extends StatefulWidget {
  const BranchReportDialog({
    super.key,
    required this.request,
    required this.range,
    this.fixedScope,
    this.embedded = false,
    this.category,
    this.onSelectScope,
  });

  final BranchRequest request;
  final DateTimeRange range;
  final String? fixedScope;
  final bool embedded;
  final String? category;
  final ValueChanged<String>? onSelectScope;

  @override
  State<BranchReportDialog> createState() => _BranchReportDialogState();
}

class _BranchReportDialogState extends State<BranchReportDialog> {
  int _dailyLimit = 15;
  late final Future<List<Map<String, dynamic>>> _branches =
      loadReportBranches(widget.request);
  late String? _branch = widget.fixedScope;
  late Future<Map<String, dynamic>>? _report =
      _branch == null ? null : _loadReport(_branch!);

  @override
  void didUpdateWidget(covariant BranchReportDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fixedScope != oldWidget.fixedScope) _branch = widget.fixedScope;
    if (widget.range != oldWidget.range ||
        widget.fixedScope != oldWidget.fixedScope) {
      _dailyLimit = 15;
      _report = _branch == null ? null : _loadReport(_branch!);
    }
  }

  Future<Map<String, dynamic>> _loadReport(String branch) => widget.request({
        'action': 'branchReport',
        if (branch == 'unassigned' || branch == 'all')
          'scope': branch
        else
          'branchId': branch.substring('branch:'.length),
        'startAtMillis': widget.range.start.millisecondsSinceEpoch,
        'endAtMillis': widget.range.end.millisecondsSinceEpoch,
      });

  List<(String, Object?)> _metrics(Map<String, dynamic> result) => [
        if (_branch == 'all')
          ('Active branches · current', result['activeBranches']),
        ('Home branch members · current', result['homeMembers']),
        ('Assigned coaches · current', result['assignedCoaches']),
        if (_branch != 'unassigned' && _branch != 'all') ...[
          ('Equipment units · current', result['equipmentUnits']),
          ('Usable units · current', result['usableUnits']),
          ('Maintenance units · current', result['maintenanceUnits']),
        ],
        ('Bookings created', result['bookingsCreated']),
        ('Completed sessions · appointment date', result['completedSessions']),
        ('Cancelled sessions · appointment date', result['cancelledSessions']),
        (
          'Confirmed sandbox coaching receipts · RM',
          switch (result['coachingMinor']) {
            final num value => (value / 100).toStringAsFixed(2),
            _ => null,
          }
        ),
        ('Actual coaching revenue · RM', _value(result, 'actualCoachingMinor')),
        if (_branch != 'unassigned') ...[
          ('Recorded gym visits', result['gymVisits']),
          ('Unique visiting members', result['uniqueVisitors']),
          ('Members with multiple visits', result['repeatVisitors']),
          (
            'Peak recorded hours · MYT',
            (result['peakHours'] as List? ?? [])
                .map((hour) => '${hour.toString().padLeft(2, '0')}:00')
                .join(' · ')
          ),
        ],
      ];

  String _myt(DateTime dt) => dt
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 16)
      .replaceFirst('T', ' ');

  List<(String, String)> get _dailyColumns => switch (widget.category) {
        'Financial' => [('coachingMinor', 'Coaching receipts (RM)')],
        'Fitness' => [('workouts', 'Accepted workouts')],
        'Coaching' => [
            ('bookings', 'Bookings'),
            ('completed', 'Completed'),
            ('cancelled', 'Cancelled')
          ],
        'Engagement' => [('visits', 'Recorded visits')],
        _ => [
            ('visits', 'Recorded visits'),
            ('bookings', 'Bookings'),
            ('completed', 'Completed'),
            ('cancelled', 'Cancelled'),
            ('coachingMinor', 'Confirmed sandbox receipts (RM)')
          ],
      };

  num? _value(Map row, String field) {
    final value = row[field];
    return value is num
        ? (field == 'coachingMinor' ? value / 100 : value)
        : null;
  }

  Widget? _scopeChart(Map<String, dynamic> result) {
    final metrics = switch (widget.category) {
      'Engagement' => [
          ('Recorded visits', 'gymVisits'),
          ('Unique visitors', 'uniqueVisitors'),
          ('Returning visitors', 'repeatVisitors')
        ],
      'Overview' || 'Coaching' => [
          ('Completed', 'completedSessions'),
          ('Cancelled', 'cancelledSessions')
        ],
      _ => const <(String, String)>[],
    };
    if (_branch == 'unassigned' && widget.category == 'Engagement') return null;
    if (metrics.isEmpty || metrics.any((entry) => result[entry.$2] is! num)) {
      return null;
    }
    final maximum = metrics.fold<num>(0, (max, entry) {
      final value = result[entry.$2] as num;
      return value > max ? value : max;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, key) in metrics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label · ${result[key]}'),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: maximum == 0 ? 0 : (result[key] as num) / maximum,
              ),
            ]),
          ),
      ],
    );
  }

  static const _comparisonColumns = [
    ('homeMembers', 'Home branch members'),
    ('assignedCoaches', 'Assigned coaches'),
    ('gymVisits', 'Recorded gym visits'),
    ('bookingsCreated', 'Coach bookings'),
    ('completedSessions', 'Completed sessions'),
    ('coachingMinor', 'Confirmed sandbox receipts (RM)'),
  ];

  List<Object?> _comparisonValues(Map row) => [
        row['branchName'],
        row['status'],
        for (final (metric, _) in _comparisonColumns) _value(row, metric),
      ];

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    IconData? icon,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildKpiRow({
    required List<Widget> cards,
    required int desktopColumns,
  }) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final int cols;
      if (width >= 1024) {
        cols = desktopColumns;
      } else if (width >= 640) {
        cols = math.min(desktopColumns, 2);
      } else {
        cols = 1;
      }
      const spacing = 14.0;
      final itemWidth = (width - (cols - 1) * spacing) / cols;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final card in cards)
            SizedBox(
              width: itemWidth,
              child: card,
            ),
        ],
      );
    });
  }

  Widget _branchStatusBadge(dynamic status) {
    final s = status?.toString().toLowerCase() ?? 'active';
    final isActive = s == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successTint : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.hairline,
        ),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.success : AppColors.inkSoft,
        ),
      ),
    );
  }

  Widget _buildOverviewSection(Map<String, dynamic> result) {
    final hasEquipment = _branch != 'unassigned' &&
        _branch != 'all' &&
        (result['equipmentUnits'] != null ||
            result['usableUnits'] != null ||
            result['maintenanceUnits'] != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Branch Overview',
          subtitle:
              'Current operational facility census, member registrations, and assigned coaches.',
          icon: Icons.storefront_rounded,
        ),
        _buildKpiRow(
          desktopColumns: 3,
          cards: [
            if (_branch == 'all')
              AnalyticsMetricCard(
                label: 'Active branches · current',
                value: result['activeBranches']?.toString() ?? '0',
                icon: Icons.storefront_rounded,
                contextNote: 'Operational gym facilities',
                highlighted: true,
              )
            else
              const AnalyticsMetricCard(
                label: 'Active branches · current',
                value: '1',
                icon: Icons.storefront_rounded,
                contextNote: 'Selected gym facility',
                highlighted: true,
              ),
            AnalyticsMetricCard(
              label: 'Home branch members · current',
              value: result['homeMembers']?.toString() ?? '0',
              icon: Icons.people_alt_outlined,
              contextNote: 'Registered home facility members',
            ),
            AnalyticsMetricCard(
              label: 'Assigned coaches · current',
              value: result['assignedCoaches']?.toString() ?? '0',
              icon: Icons.sports_rounded,
              contextNote: 'Active coach assignments',
            ),
          ],
        ),
        if (hasEquipment) ...[
          const SizedBox(height: 14),
          _buildKpiRow(
            desktopColumns: 3,
            cards: [
              AnalyticsMetricCard(
                label: 'Equipment units · current',
                value: result['equipmentUnits']?.toString() ?? '—',
                icon: Icons.fitness_center_outlined,
                contextNote: 'Total equipment inventory units',
              ),
              AnalyticsMetricCard(
                label: 'Usable units · current',
                value: result['usableUnits']?.toString() ?? '—',
                icon: Icons.check_circle_outline_rounded,
                contextNote: 'Ready for member training',
              ),
              AnalyticsMetricCard(
                label: 'Maintenance units · current',
                value: result['maintenanceUnits']?.toString() ?? '—',
                icon: Icons.build_circle_outlined,
                contextNote: 'Units under maintenance',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _comparison(List<Map> rows) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: const Center(
          child: Text(
            'No branch statistics available for comparison.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
        ),
      );
    }

    final chartConfigs = [
      (
        'homeMembers',
        'Home Branch Members',
        'Registered home facility members by gym location',
        AppColors.primary,
        false,
        'members',
      ),
      (
        'gymVisits',
        'Recorded Gym Visits',
        'Physical check-in scan volume across branches',
        const Color(0xFF6366F1),
        false,
        'visits',
      ),
      (
        'bookingsCreated',
        'Coach Bookings',
        'Total appointments scheduled at each branch',
        const Color(0xFF3B82F6),
        false,
        'bookings',
      ),
      (
        'coachingMinor',
        'Confirmed Sandbox Receipts (RM)',
        'Simulated UAT coaching collections in MYR',
        const Color(0xFF10B981),
        true,
        'MYR',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Location Performance & Benchmarks',
          subtitle:
              'Comparative cross-branch metrics for members, footfall, appointments, and collections.',
          icon: Icons.bar_chart_rounded,
        ),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          final cardWidth =
              isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final (metric, title, subtitle, color, isCurrency, unit)
                  in chartConfigs)
                if (rows.any((row) => _value(row, metric) != null))
                  SizedBox(
                    width: cardWidth,
                    child: AnalyticsChartCard(
                      title: title,
                      subtitle: subtitle,
                      child: SizedBox(
                        height: 230,
                        child: SfCartesianChart(
                          plotAreaBorderWidth: 0,
                          margin: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                          primaryXAxis: CategoryAxis(
                            isInversed: true,
                            majorGridLines: const MajorGridLines(width: 0),
                            axisLine: const AxisLine(width: 0),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                          primaryYAxis: NumericAxis(
                            minimum: 0,
                            decimalPlaces: isCurrency ? 2 : 0,
                            majorGridLines: const MajorGridLines(
                              width: 0.6,
                              color: AppColors.hairline,
                            ),
                            axisLine: const AxisLine(width: 0),
                            labelStyle: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          tooltipBehavior: TooltipBehavior(
                            enable: true,
                            header: '',
                            canShowMarker: false,
                            format: isCurrency
                                ? 'point.x: RM point.y'
                                : 'point.x: point.y $unit',
                          ),
                          series: <CartesianSeries<Map, String>>[
                            BarSeries<Map, String>(
                              name: title,
                              color: color,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(4),
                              ),
                              dataSource: rows
                                  .where((row) => _value(row, metric) != null)
                                  .toList(),
                              xValueMapper: (row, _) =>
                                  row['branchName'] as String? ?? 'Branch',
                              yValueMapper: (row, _) => _value(row, metric),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          );
        }),
        const SizedBox(height: 24),
        _sectionHeader(
          title: 'Branch Comparison Table',
          subtitle:
              'Granular operational audit comparing memberships, staffing, sessions, and revenue.',
          icon: Icons.table_chart_rounded,
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
                headingTextStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.ink,
                ),
                dividerThickness: 0.6,
                columns: [
                  const DataColumn(label: Text('Branch')),
                  const DataColumn(label: Text('Status')),
                  for (final (_, label) in _comparisonColumns)
                    DataColumn(label: Text(label), numeric: true),
                  const DataColumn(label: Text('Action')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.storefront_outlined,
                                size: 15, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              row['branchName']?.toString() ?? 'Branch',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(_branchStatusBadge(row['status'])),
                      for (final (metric, _) in _comparisonColumns)
                        DataCell(
                          metric == 'coachingMinor'
                              ? Text(
                                  _value(row, metric) != null
                                      ? 'RM ${(_value(row, metric)!).toStringAsFixed(2)}'
                                      : '—',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : Text(
                                  _value(row, metric)?.toString() ?? 'Unavailable',
                                ),
                        ),
                      DataCell(
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => widget.onSelectScope?.call(
                              row['branchId'] == 'unassigned'
                                  ? 'unassigned'
                                  : 'branch:${row['branchId']}'),
                          child: const Text(
                            'View details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingActivitySection(Map<String, dynamic> result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Booking Activity',
          subtitle:
              'Coach appointment volume, completed sessions, and client cancellations.',
          icon: Icons.calendar_month_outlined,
        ),
        _buildKpiRow(
          desktopColumns: 3,
          cards: [
            AnalyticsMetricCard(
              label: 'Bookings created',
              value: result['bookingsCreated']?.toString() ?? '0',
              icon: Icons.calendar_today_outlined,
              contextNote: 'Appointments created in period',
            ),
            AnalyticsMetricCard(
              label: 'Completed sessions · appointment date',
              value: result['completedSessions']?.toString() ?? '0',
              icon: Icons.task_alt_rounded,
              contextNote: 'Sessions completed as scheduled',
            ),
            AnalyticsMetricCard(
              label: 'Cancelled sessions · appointment date',
              value: result['cancelledSessions']?.toString() ?? '0',
              icon: Icons.event_busy_outlined,
              contextNote: 'Client or coach cancellations',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGymVisitsSection(Map<String, dynamic> result) {
    final peakHours = (result['peakHours'] as List? ?? [])
        .map((h) => '${h.toString().padLeft(2, '0')}:00')
        .join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Gym Visit Insights',
          subtitle:
              'Facility footfall, unique visitor attendance, and peak visit hours.',
          icon: Icons.qr_code_scanner_rounded,
        ),
        _buildKpiRow(
          desktopColumns: 4,
          cards: [
            AnalyticsMetricCard(
              label: 'Recorded gym visits',
              value: result['gymVisits']?.toString() ?? '0',
              icon: Icons.qr_code_scanner_rounded,
              contextNote: 'Total facility check-in scans',
            ),
            AnalyticsMetricCard(
              label: 'Unique visiting members',
              value: result['uniqueVisitors']?.toString() ?? '0',
              icon: Icons.person_pin_circle_outlined,
              contextNote: 'Distinct members checked in',
            ),
            AnalyticsMetricCard(
              label: 'Members with multiple visits',
              value: result['repeatVisitors']?.toString() ?? '0',
              icon: Icons.repeat_rounded,
              contextNote: 'Members visiting more than once',
            ),
            AnalyticsMetricCard(
              label: 'Peak recorded hours · MYT',
              value: peakHours.isEmpty ? '—' : peakHours,
              icon: Icons.access_time_rounded,
              contextNote: 'Highest traffic attendance hours',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialSection(Map<String, dynamic> result) {
    final minor = result['coachingMinor'];
    final receiptVal = minor is num ? (minor / 100).toStringAsFixed(2) : '0.00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Financial Coverage',
          subtitle:
              'Sandbox coaching fee receipts and transaction clearance reporting.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final cardWidth =
              isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              AnalyticsMetricCard(
                width: cardWidth,
                label: 'Confirmed sandbox coaching receipts · RM',
                value: 'RM $receiptVal',
                icon: Icons.receipt_long_outlined,
                contextNote: 'Simulated UAT coaching collections (MYR)',
                highlighted: true,
              ),
              Container(
                width: cardWidth,
                constraints: const BoxConstraints(minHeight: 116),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Actual coaching revenue · RM',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: const Text(
                            'Unavailable',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unavailable',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Actual coaching payment settlement is not integrated into this sandbox environment. Confirmed receipts reflect synthetic sandbox test transactions.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.inkSoft,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 10),
        Row(
          children: const [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.inkSoft),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Membership revenue remains in the organization-wide report.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dailyTrend(List<Map> rows) {
    final columns = _dailyColumns
        .where((column) => rows.any((row) => _value(row, column.$1) != null))
        .toList();
    if (columns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: const Center(
          child: Text(
            'No daily activity recorded for this period.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
        ),
      );
    }
    final trends = columns.where((column) =>
        const {'visits', 'bookings', 'coachingMinor'}.contains(column.$1));
    final first = DateTime.parse(rows.first['date'] as String);
    final last = DateTime.parse(rows.last['date'] as String);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (metric, label) in trends) ...[
          AnalyticsChartCard(
            title: label,
            subtitle: 'Daily $label tracking in Malaysia Time',
            child: SizedBox(
              height: 220,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                margin: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                primaryXAxis: DateTimeAxis(
                  intervalType: DateTimeIntervalType.days,
                  minimum: first == last
                      ? first.subtract(const Duration(days: 1))
                      : first,
                  maximum:
                      first == last ? last.add(const Duration(days: 1)) : last,
                  rangePadding: ChartRangePadding.none,
                  majorGridLines: const MajorGridLines(width: 0),
                  axisLine: const AxisLine(width: 0),
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkSoft,
                  ),
                ),
                primaryYAxis: NumericAxis(
                  minimum: 0,
                  decimalPlaces: metric == 'coachingMinor' ? 2 : 0,
                  majorGridLines: const MajorGridLines(
                    width: 0.6,
                    color: AppColors.hairline,
                  ),
                  axisLine: const AxisLine(width: 0),
                  labelStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkSoft,
                  ),
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  header: '',
                  canShowMarker: false,
                  format: metric == 'coachingMinor'
                      ? 'point.x: RM point.y'
                      : 'point.x: point.y',
                ),
                series: <CartesianSeries<Map, DateTime>>[
                  LineSeries<Map, DateTime>(
                    dataSource: rows,
                    name: label,
                    color: metric == 'coachingMinor'
                        ? const Color(0xFF10B981)
                        : (metric == 'visits'
                            ? const Color(0xFF6366F1)
                            : AppColors.primary),
                    width: 2.5,
                    xValueMapper: (row, _) =>
                        DateTime.parse(row['date'] as String),
                    yValueMapper: (row, _) => _value(row, metric),
                    markerSettings: const MarkerSettings(
                      isVisible: true,
                      height: 6,
                      width: 6,
                      shape: DataMarkerType.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.table_chart_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Daily Activity Log',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Showing ${math.min(_dailyLimit, rows.length)} of ${rows.length} dates',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.hairline),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AppColors.surfaceAlt),
                  headingTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                  dataTextStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.ink,
                  ),
                  dividerThickness: 0.6,
                  columns: [
                    const DataColumn(label: Text('Date (MYT)')),
                    for (final (_, label) in columns)
                      DataColumn(label: Text(label), numeric: true),
                  ],
                  rows: [
                    for (final row in rows.reversed.take(_dailyLimit))
                      DataRow(cells: [
                        DataCell(Text(
                          row['date'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        for (final (key, _) in columns)
                          DataCell(Text(
                            key == 'coachingMinor' && _value(row, key) != null
                                ? 'RM ${(_value(row, key)!).toStringAsFixed(2)}'
                                : (_value(row, key)?.toString() ?? '—'),
                          )),
                      ]),
                  ],
                ),
              ),
              if (rows.length > _dailyLimit) ...[
                const Divider(height: 1, color: AppColors.hairline),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.expand_more_rounded, size: 16),
                      onPressed: () => setState(() => _dailyLimit += 15),
                      label: const Text('Show more dates'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCoverageDisclosure(Map<String, dynamic> result) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 8),
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
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              const Text(
                'Multi-Branch Reporting & Attribution Definitions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Text(
                  'Malaysia Time · UTC+08:00',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
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
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 14, color: AppColors.inkSoft),
                      const SizedBox(width: 6),
                      Text(
                        'Timezone: Malaysia Time (UTC+08:00) · Active range: ${_myt(widget.range.start)} – ${_myt(widget.range.end)} MYT',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Current snapshot: Home branch members, coach assignments, equipment inventory, and branch status reflect current snapshots independent of date filters.\n'
                    '• Date-scoped activity: Visits, coach bookings, completed sessions, and receipts are bounded by the selected date range.\n'
                    '• Financial amounts: Confirmed sandbox receipts in MYR. Actual revenue unavailable in sandbox mode. Membership revenue remains in the organization-wide financial report.\n'
                    '• Coach attribution: Coaches may be assigned to multiple branches; organization-level assigned coach totals represent distinct active coaches, not a naive sum of branch rows.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkSoft,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportCsv(
      Map<String, dynamic> result, List<Map> branches, List<Map> daily) {
    downloadCsv('gainpath-branch-report.csv', [
      ['Branch scope', _spreadsheetText(result['branchName'])],
      ['Start MYT', _myt(widget.range.start)],
      ['End MYT (exclusive)', _myt(widget.range.end)],
      [
        'Current snapshot',
        'Home branch members, coach assignments, inventory and branch status'
      ],
      [
        'Date-scoped activity',
        'Visits, bookings, coaching sessions and receipts'
      ],
      [
        'Financial amounts',
        'Confirmed sandbox receipts in MYR. Actual revenue unavailable.'
      ],
      ['Metric', 'Value'],
      for (final (label, value) in _metrics(result))
        [label, value],
      if (branches.isNotEmpty) ...[
        [],
        [
          'Branch',
          'Status',
          for (final (_, label) in _comparisonColumns) label
        ],
        for (final row in branches)
          [
            _spreadsheetText(row['branchName']),
            ..._comparisonValues(row).skip(1)
          ],
      ],
      if (daily.isNotEmpty) ...[
        [],
        [
          'Date (MYT)',
          for (final (_, label) in _dailyColumns) label
        ],
        for (final row in daily)
          [
            row['date'],
            for (final (key, _) in _dailyColumns)
              _value(row, key)
          ],
      ],
    ]);
  }

  Widget _buildTopActionBar(
      Map<String, dynamic> result, List<Map> branches, List<Map> daily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${_myt(widget.range.start)} – ${_myt(widget.range.end)} MYT',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text(
              'Export branch CSV',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () => _exportCsv(result, branches, daily),
          ),
        ],
      ),
    );
  }

  String _branchDisplayName(Map<String, dynamic> result) {
    if (_branch == 'all') return 'All Branches';
    if (_branch == 'unassigned') return 'Unassigned Records';
    return result['branchName']?.toString() ?? 'Selected Branch';
  }

  Widget _buildEmbeddedDashboard(
    BuildContext context,
    Map<String, dynamic> result,
    List<Map> branches,
    List<Map> daily,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopActionBar(result, branches, daily),
        const SizedBox(height: 12),
        if (_scopeChart(result) case final Widget chart) ...[
          chart,
          const SizedBox(height: 12),
        ],
        _buildOverviewSection(result),
        if (_branch == 'all' && branches.isNotEmpty)
          _comparison(branches),
        _buildBookingActivitySection(result),
        if (_branch != 'unassigned')
          _buildGymVisitsSection(result),
        _buildFinancialSection(result),
        if (_branch != 'all') ...[
          const SizedBox(height: 24),
          _sectionHeader(
            title: 'Daily Activity Trends',
            subtitle:
                'Day-by-day activity tracking for ${_branchDisplayName(result)}.',
            icon: Icons.timeline_rounded,
          ),
          _dailyTrend(daily),
        ],
        _buildCoverageDisclosure(result),
      ],
    );
  }

  Widget _buildDialog(BuildContext context) {
    final contents = <Widget>[
      Text('${_myt(widget.range.start)} – ${_myt(widget.range.end)} MYT'),
      const SizedBox(height: 12),
      if (widget.fixedScope == null)
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _branches,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Branches could not be loaded.');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Branch scope'),
              items: [
                const DropdownMenuItem(
                    value: 'unassigned', child: Text('Unassigned records')),
                for (final row in snapshot.data!)
                  DropdownMenuItem(
                      value: 'branch:${row['branchId']}',
                      child: Text(
                          '${row['displayName']}${row['status'] == 'inactive' ? ' (inactive)' : ''}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _branch = value;
                    _report = _loadReport(value);
                  });
                }
              },
            );
          },
        ),
      if (_report != null)
        FutureBuilder<Map<String, dynamic>>(
          future: _report,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return TextButton(
                onPressed: () =>
                    setState(() => _report = _loadReport(_branch!)),
                child: const Text('Branch report unavailable · Retry'),
              );
            }
            final result = snapshot.data!;
            final daily = (result['daily'] as List? ?? const [])
                .whereType<Map>()
                .where((row) =>
                    row['date'] is String &&
                    DateTime.tryParse(row['date'] as String) != null)
                .toList();
            final branches = (result['branches'] as List? ?? const [])
                .whereType<Map>()
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Export branch CSV'),
                  onPressed: () => _exportCsv(result, branches, daily),
                ),
                if (_scopeChart(result) case final Widget chart) chart,
                for (final (label, value) in _metrics(result))
                  ListTile(
                    dense: true,
                    title: Text(label),
                    trailing: Text(value == null || value == ''
                        ? '—'
                        : value.toString()),
                  ),
                if (_branch == 'all')
                  _comparison(branches)
                else
                  _dailyTrend(daily),
                const Text(
                    'Membership revenue remains in the organization-wide report.'),
              ],
            );
          },
        ),
    ];
    return AlertDialog(
      title: const Text('Branch report'),
      content: SizedBox(
          width: 550, height: 520, child: ListView(children: contents)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.embedded) {
      return _buildDialog(context);
    }

    if (_report == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.hairline),
        ),
        child: const Center(
          child: Text(
            'Select a branch to view reporting data.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 32, color: AppColors.warning),
                  const SizedBox(height: 12),
                  const Text(
                    'Branch report unavailable',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The report data could not be retrieved from the server.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        setState(() => _report = _loadReport(_branch!)),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final result = snapshot.data!;
        final daily = (result['daily'] as List? ?? const [])
            .whereType<Map>()
            .where((row) =>
                row['date'] is String &&
                DateTime.tryParse(row['date'] as String) != null)
            .toList();
        final branches = (result['branches'] as List? ?? const [])
            .whereType<Map>()
            .toList();

        return _buildEmbeddedDashboard(context, result, branches, daily);
      },
    );
  }
}

Future<List<Map<String, dynamic>>> loadReportBranches(
    BranchRequest request) async {
  final results = <Map<String, dynamic>>[];
  final seen = <String>{};
  String? cursor;
  do {
    final result = await request(
        {'action': 'list', if (cursor != null) 'afterId': cursor});
    results.addAll((result['records'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map)));
    cursor = result['nextAfterId'] as String?;
    if (cursor != null && !seen.add(cursor)) {
      throw StateError('Branch pagination did not advance.');
    }
  } while (cursor != null);
  return results;
}

String _spreadsheetText(Object? raw) {
  final value = raw?.toString() ?? '';
  return RegExp(r'^\s*[=+@-]').hasMatch(value) ? "'$value" : value;
}
