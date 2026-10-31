import 'admin_remaining_analytics.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'sections/commerce_sections.dart';
import 'sections/engagement_sections.dart';
import 'sections/operations_sections.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';

import '../../application/admin_reporting_cubit.dart';
import 'admin_reporting_feedback.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/admin_operational_metrics.dart';
import 'original_report_data_widgets.dart';
import 'admin_workout_analytics.dart';

/// AD-M12.1/M12.2 — Admin Dashboard & Reporting. One continuous analytics
/// page instead of eight separate pushed screens each showing a single
/// chart: a jump-nav strip at the top scrolls straight to any section (no
/// push, no back button), a real date/branch filter bar reacts live
/// across the sections whose data can honestly support it, and every
/// section carries multiple Syncfusion charts plus a real CSV export
/// instead of one lonely graph and a toast.
class ReportsScreen extends StatefulWidget {
  final bool live;
  const ReportsScreen({super.key, this.live = false});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _operational = false;
  static const _dateOptions = [null, 7, 30, 90];
  static const _dateLabels = {
    null: 'All time',
    7: '7 days',
    30: '30 days',
    90: '90 days'
  };

  int? _days;
  DateTimeRange? _customDates;
  String? _branch;
  AdminReportingCubit? _reportingCubit;
  int _workoutRefresh = 0;

  final _overviewKey = GlobalKey();
  final _usageKey = GlobalKey();
  final _workoutsKey = GlobalKey();
  final _postureKey = GlobalKey();
  final _bookingKey = GlobalKey();
  final _retentionKey = GlobalKey();
  final _rewardsKey = GlobalKey();
  final _revenueKey = GlobalKey();
  final _gamificationKey = GlobalKey();
  final _coachPerfKey = GlobalKey();

  late final _anchors = [
    ('Overview', _overviewKey),
    ('Workouts', _workoutsKey),
    ('Usage', _usageKey),
    ('Estimated form', _postureKey),
    ('Booking', _bookingKey),
    ('Engagement', _retentionKey),
    ('Rewards', _rewardsKey),
    ('Revenue', _revenueKey),
    ('Gamification', _gamificationKey),
    ('Coaches', _coachPerfKey),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reportingCubit == null && widget.live) {
      try {
        final gateway = context.read<AdminReportingGateway>();
        _operational = gateway is OperationalAdminReportingGateway;
        _reportingCubit =
            AdminReportingCubit(gateway: gateway, initialQuery: _filterQuery())
              ..load();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _reportingCubit?.close();
    super.dispose();
  }

  AdminReportQuery _filterQuery() {
    if (_operational) {
      return operationalDateQuery(DateTime.now(),
          days: _days, calendarRange: _customDates);
    }
    final now = DateTime.now();
    final start = _days == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : now.subtract(Duration(days: _days!));
    return AdminReportQuery(
        range: DateTimeRange(start: start, end: now), branchId: _branch);
  }

  void _onFilterChanged() => _reportingCubit?.load(_filterQuery());

  void _jumpTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.02);
  }

  @override
  Widget build(BuildContext context) {
    if (_reportingCubit != null) {
      return BlocBuilder<AdminReportingCubit, AdminReportingState>(
        bloc: _reportingCubit,
        builder: (context, reportingState) => _buildReport(
            context,
            reportingState.snapshot?.isAvailable == true
                ? reportingState.snapshot
                : null,
            reportingState: reportingState),
      );
    }
    return _buildReport(context, null);
  }

  Widget _buildReport(BuildContext context, AdminReportingSnapshot? snapshot,
      {AdminReportingState? reportingState}) {
    final filter = ReportFilter(days: _days, branch: _branch);

    final completed = context
        .read<BookingRepository>()
        .allBookings
        .where((b) => b.status == BookingStatus.completed)
        .toList();
    final coachingRevenue = completed.fold<double>(0, (sum, b) => sum + b.fee);
    final avgSession =
        completed.isEmpty ? 0.0 : coachingRevenue / completed.length;

    final revenueByCoach = <String, double>{};
    final sessionsByCoach = <String, int>{};
    for (final b in completed) {
      revenueByCoach[b.coachName] = (revenueByCoach[b.coachName] ?? 0) + b.fee;
      sessionsByCoach[b.coachName] = (sessionsByCoach[b.coachName] ?? 0) + 1;
    }
    final topCoaches = revenueByCoach.keys.toList()
      ..sort((a, b) => revenueByCoach[b]!.compareTo(revenueByCoach[a]!));
    final maxCoachRevenue =
        topCoaches.isEmpty ? 1.0 : revenueByCoach[topCoaches.first]!;

    final ops = snapshot?.operations;
    final totalRev = snapshot?.totalRevenue;
    final membershipRevenue = widget.live
        ? (_operational
            ? reportMoney(ops?.membershipMinor)
            : totalRev != null
                ? '${totalRev.currency} ${(totalRev.minorUnits / 100).toStringAsFixed(0)}'
                : '—')
        : 'RM 24,180';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reportingState != null)
                  AdminReportingFeedback(
                      state: reportingState, onRetry: _reportingCubit!.refresh),
                _header(context),
                const SizedBox(height: 20),
                _toolbar(
                    snapshot: snapshot,
                    loading: reportingState?.isLoading ?? false),
                if (ops != null) OriginalReportContext(snapshot: snapshot!),
                const SizedBox(height: 26),
                Container(key: _overviewKey, child: const Eyebrow('Overview')),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                        width: 220,
                        child: StatTile(
                            membershipRevenue,
                            _operational
                                ? 'Membership Sandbox receipts'
                                : 'Membership revenue / month')),
                    SizedBox(
                        width: 220,
                        child: StatTile(
                            _operational
                                ? reportMoney(ops?.coachingMinor)
                                : widget.live
                                    ? (completed.isEmpty
                                        ? '—'
                                        : 'RM ${coachingRevenue.toStringAsFixed(0)}')
                                    : 'RM ${coachingRevenue.toStringAsFixed(0)}',
                            _operational
                                ? 'Coaching Sandbox receipts'
                                : 'Coaching revenue, all completed sessions')),
                    SizedBox(
                        width: 220,
                        child: StatTile(
                            _operational
                                ? reportMoney(totalRev?.minorUnits)
                                : widget.live
                                    ? (completed.isEmpty
                                        ? '—'
                                        : 'RM ${avgSession.toStringAsFixed(0)}')
                                    : 'RM ${avgSession.toStringAsFixed(0)}',
                            _operational
                                ? 'Confirmed Sandbox receipts'
                                : 'Avg. revenue per session')),
                    SizedBox(
                        width: 220,
                        child: StatTile(
                            _operational
                                ? snapshot?.totalBookingsCount?.toString() ??
                                    '—'
                                : widget.live
                                    ? (completed.isEmpty
                                        ? '—'
                                        : '${completed.length}')
                                    : '${completed.length}',
                            _operational
                                ? 'Bookings created in range'
                                : 'Completed sessions tracked')),
                  ],
                ),
                const SizedBox(height: 20),
                wide
                    ? IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                flex: 3,
                                child: _salesColumn(
                                    context,
                                    topCoaches,
                                    revenueByCoach,
                                    sessionsByCoach,
                                    maxCoachRevenue,
                                    snapshot: snapshot)),
                            const SizedBox(width: 20),
                            Expanded(
                                flex: 2,
                                child:
                                    _branchColumn(context, snapshot: snapshot)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          _salesColumn(context, topCoaches, revenueByCoach,
                              sessionsByCoach, maxCoachRevenue,
                              snapshot: snapshot),
                          const SizedBox(height: 20),
                          _branchColumn(context, snapshot: snapshot),
                        ],
                      ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 28),
                if (_operational && _reportingCubit != null)
                  AdminWorkoutAnalytics(
                      query: _reportingCubit!.state.query,
                      refreshToken: _workoutRefresh,
                      anchorKey: _workoutsKey),
                if (_operational && _reportingCubit != null)
                  AdminObservedSection(
                      query: _reportingCubit!.state.query,
                      anchorKey: _usageKey,
                      refreshToken: _workoutRefresh)
                else
                  UsageEngagementSection(
                      anchorKey: _usageKey, filter: filter, live: widget.live),
                if (_operational && _reportingCubit != null)
                  AdminPostureSection(
                      query: _reportingCubit!.state.query,
                      anchorKey: _postureKey,
                      refreshToken: _workoutRefresh)
                else
                  PostureAccuracySection(
                      anchorKey: _postureKey, live: widget.live),
                if (snapshot?.commerce != null)
                  AdminCoachActivitySection(
                      anchorKey: _bookingKey, report: snapshot!.commerce!)
                else
                  CoachBookingUtilizationSection(
                      anchorKey: _bookingKey,
                      filter: filter,
                      live: widget.live,
                      snapshot: snapshot),
                if (_operational && _reportingCubit != null)
                  AdminObservedSection(
                      query: _reportingCubit!.state.query,
                      anchorKey: _retentionKey,
                      retention: true,
                      refreshToken: _workoutRefresh)
                else
                  RetentionRiskSection(
                      anchorKey: _retentionKey, live: widget.live),
                RewardsSection(
                    anchorKey: _rewardsKey,
                    live: widget.live,
                    query: _operational ? _reportingCubit?.state.query : null,
                    refreshToken: _workoutRefresh),
                RevenueSection(
                    anchorKey: _revenueKey,
                    live: widget.live,
                    snapshot: snapshot),
                GamificationSection(
                    anchorKey: _gamificationKey,
                    live: widget.live,
                    query: _operational ? _reportingCubit?.state.query : null,
                    refreshToken: _workoutRefresh),
                CoachPerformanceSection(
                    anchorKey: _coachPerfKey,
                    snapshot: snapshot,
                    filter: filter,
                    live: widget.live),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.query_stats_rounded,
              color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reports & analytics',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text(
                  widget.live
                      ? 'Connected account, booking and Sandbox receipt reports.'
                      : 'Sales, operations, and engagement — one page, always live.',
                  style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: widget.live ? AppColors.surfaceAlt : AppColors.successTint,
              borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.live ? Icons.info_outline_rounded : Icons.bolt_rounded,
                size: 13,
                color: widget.live ? AppColors.inkSoft : AppColors.success,
              ),
              const SizedBox(width: 4),
              Text(
                widget.live ? 'Live console' : 'Live data',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: widget.live ? AppColors.inkSoft : AppColors.success),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Filter controls and the anchor-jump chips used to sit in two
  /// separate floating rows; grouped into one bordered toolbar so the
  /// header reads as a single control surface instead of two unrelated
  /// pieces stacked on top of each other.
  Widget _toolbar({AdminReportingSnapshot? snapshot, bool loading = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Icon(Icons.tune_rounded,
                    size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 2),
                ..._dateOptions.map((d) {
                  final selected = _customDates == null && d == _days;
                  return ChoiceChip(
                    label: Text(_dateLabels[d]!),
                    selected: selected,
                    onSelected: loading
                        ? null
                        : (_) => setState(() {
                              _customDates = null;
                              _days = d;
                              _onFilterChanged();
                            }),
                    backgroundColor: AppColors.surfaceAlt,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.ink),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(color: AppColors.hairline)),
                  );
                }),
                Container(
                    width: 1,
                    height: 20,
                    color: AppColors.hairline,
                    margin: const EdgeInsets.symmetric(horizontal: 4)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _branch,
                    hint: const Text('All branches',
                        style: TextStyle(fontSize: 12.5)),
                    isDense: true,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All branches')),
                      ...context.read<UserAccountRepository>().branches.map(
                          (b) => DropdownMenuItem(
                              value: b.name, child: Text(b.name))),
                    ],
                    onChanged: _operational
                        ? null
                        : (v) => setState(() {
                              _branch = v;
                              _onFilterChanged();
                            }),
                  ),
                ),
                if (_operational) ...[
                  TextButton.icon(
                      icon: const Icon(Icons.date_range_outlined, size: 16),
                      label: const Text('Custom dates'),
                      onPressed: loading
                          ? null
                          : () async {
                              final day =
                                  DateTime.now().toUtc().add(adminReportZone);
                              final range = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(1970),
                                  lastDate:
                                      DateTime(day.year, day.month, day.day),
                                  initialDateRange: _customDates);
                              if (range != null && mounted) {
                                setState(() {
                                  _customDates = range;
                                  _onFilterChanged();
                                });
                              }
                            }),
                  IconButton(
                      tooltip: 'Refresh reports',
                      onPressed: loading
                          ? null
                          : () {
                              setState(() => _workoutRefresh++);
                              _reportingCubit?.refresh();
                            },
                      icon: const Icon(Icons.refresh_rounded, size: 18)),
                  TextButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text('Export overview CSV'),
                      onPressed: loading || snapshot?.operations == null
                          ? null
                          : () => downloadCsv('gainpath-operational-report.csv',
                              snapshot!.operations!.toCsv(snapshot))),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.explore_outlined,
                    size: 15, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _anchors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final (label, key) = _anchors[i];
                        return ActionChip(
                          label: Text(label),
                          onPressed: () => _jumpTo(key),
                          backgroundColor: AppColors.primaryTint,
                          labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesColumn(
      BuildContext context,
      List<String> topCoaches,
      Map<String, double> revenueByCoach,
      Map<String, int> sessionsByCoach,
      double maxCoachRevenue,
      {AdminReportingSnapshot? snapshot}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(_operational
            ? 'Membership receipt trend'
            : 'Membership revenue trend'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _operational
                    ? reportMoney(snapshot?.operations?.membershipMinor)
                    : widget.live
                        ? 'RM —'
                        : 'RM 24,180',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                _operational
                    ? 'Confirmed membership Sandbox clearances in the selected period'
                    : widget.live
                        ? 'Revenue history is unavailable'
                        : 'Last 7 months',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (snapshot?.operations != null)
                OriginalReceiptTrend(snapshot: snapshot!, membershipOnly: true)
              else if (widget.live)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Revenue trend is not connected to a live aggregate source.',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  ),
                )
              else
                const TrendChart(
                    [18200, 19400, 21000, 20600, 22800, 23400, 24180]),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Eyebrow(
            _operational ? 'Receipt breakdown' : 'Coaching revenue by coach'),
        Panel(
          child: snapshot?.operations != null
              ? OriginalReceiptBreakdown(snapshot: snapshot!)
              : topCoaches.isEmpty
                  ? Text(widget.live
                      ? 'No completed sessions recorded in this period.'
                      : 'No completed sessions yet.')
                  : Column(
                      children: topCoaches.map((name) {
                        final revenue = revenueByCoach[name]!;
                        final sessions = sessionsByCoach[name]!;
                        return ProgressRow(
                          name,
                          revenue / maxCoachRevenue,
                          'RM ${revenue.toStringAsFixed(0)} · $sessions sessions',
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _branchColumn(BuildContext context,
      {AdminReportingSnapshot? snapshot}) {
    final branches = context.read<UserAccountRepository>().branches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Current organization census'),
        if (snapshot?.operations != null) ...[
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Organization accounts',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: StatTile('${snapshot!.activeMembersCount}',
                          'Current active Members',
                          compact: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: StatTile('${snapshot.activeCoachesCount}',
                          'Current active Coaches',
                          compact: true)),
                ]),
                const SizedBox(height: 8),
                const Text(
                    'Organization-wide current census. Branch allocation is unavailable.'),
              ])),
          const SizedBox(height: 14),
        ],
        if (branches.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text('Primary Facility / Branch',
                              style: Theme.of(context).textTheme.titleMedium)),
                      statusPill('Unavailable'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('—', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text('Branch metrics are unavailable in this environment.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.inkSoft)),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Expanded(
                          child:
                              StatTile('—', 'Coaches assigned', compact: true)),
                      SizedBox(width: 8),
                      Expanded(
                          child: StatTile('—', 'Sessions completed',
                              compact: true)),
                      SizedBox(width: 8),
                      Expanded(
                          child: StatTile('—', 'Revenue generated',
                              compact: true)),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          ...branches.map((branch) {
            final branchCoaches = context
                .read<CoachRepository>()
                .coaches
                .where((c) => c.branch == branch.name)
                .toList();
            final branchBookings = context
                .read<BookingRepository>()
                .allBookings
                .where((b) =>
                    b.branch == branch.name &&
                    b.status == BookingStatus.completed)
                .toList();
            final branchRevenue =
                branchBookings.fold<double>(0, (sum, b) => sum + b.fee);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(branch.name,
                                style:
                                    Theme.of(context).textTheme.titleMedium)),
                        statusPill(branch.isActive ? 'Active' : 'Suspended'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(branch.address,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Text(branch.contactPhone,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                            child: StatTile(
                                '${branchCoaches.length}', 'Coaches assigned',
                                compact: true)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: StatTile('${branchBookings.length}',
                                'Sessions completed',
                                compact: true)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: StatTile(
                                'RM ${branchRevenue.toStringAsFixed(0)}',
                                'Revenue generated',
                                compact: true)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
