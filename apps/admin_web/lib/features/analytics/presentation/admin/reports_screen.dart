import '../../application/admin_check_in_reporting.dart';
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
import 'admin_workout_summary.dart';
import '../../application/admin_workout_reporting.dart';
import '../../application/business_dashboard_metrics.dart';

enum ReportsCategory {
  overview('Overview'),
  financial('Financial'),
  fitness('Fitness'),
  coaching('Coaching'),
  engagement('Engagement');

  const ReportsCategory(this.label);
  final String label;
}

class ReportsScreen extends StatefulWidget {
  final bool live;
  const ReportsScreen(
      {super.key,
      this.live = false,
      this.category = ReportsCategory.overview,
      this.active = true,
      this.now = DateTime.now,
      this.onCategoryChanged});
  final ReportsCategory category;
  final bool active;
  final DateTime Function() now;
  final ValueChanged<ReportsCategory>? onCategoryChanged;

  @override
  State<ReportsScreen> createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> {
  bool _operational = false;
  bool _exporting = false;
  static const _dateOptions = [null, 7, 30, 90];
  static const _dateLabels = {
    null: 'All recorded dates',
    7: '7 days',
    30: '30 days',
    90: '90 days'
  };

  int? _days;
  DateTimeRange? _customDates;
  String? _branch;
  AdminReportingCubit? _reportingCubit;
  AdminWorkoutReportingCubit? _workoutCubit;
  DateTime? _lastWorkoutRequestAt;
  final _scrollController = ScrollController();
  final _scrollOffsets = <ReportsCategory, double>{};
  final _visitedTabs = <ReportsCategory>{ReportsCategory.overview};
  final _sectionQueries = <ReportsCategory, AdminReportQuery>{};
  final _refreshTokens = <ReportsCategory, int>{};
  final _lastVisited = <ReportsCategory, DateTime>{};
  static const _tabFreshness = Duration(seconds: 30);
  AdminReportQuery? _query;

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

  ReportsCategory _tab = ReportsCategory.overview;

  @override
  void initState() {
    super.initState();
    _tab = widget.category;
    _visitedTabs
      ..clear()
      ..add(_tab);
  }

  @override
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category ||
        (!oldWidget.active && widget.active)) {
      selectCategory(widget.category, resume: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.live) {
      try {
        final gateway = context.watch<AdminReportingGateway>();
        if (identical(_reportingCubit?.gateway, gateway)) return;
        _reportingCubit?.close();
        _workoutCubit?.close();
        _workoutCubit = null;
        _lastWorkoutRequestAt = null;
        _visitedTabs
          ..clear()
          ..add(widget.category);
        _sectionQueries.clear();
        _refreshTokens.clear();
        _lastVisited.clear();
        _scrollOffsets.clear();
        _tab = widget.category;
        _operational = gateway is OperationalAdminReportingGateway;
        _query = _filterQuery();
        _lastVisited[_tab] = widget.now();
        if (gateway is AdminWorkoutReportingGateway) {
          _workoutCubit = AdminWorkoutReportingCubit(
              gateway: gateway as AdminWorkoutReportingGateway, query: _query!);
          if (_usesWorkoutReport) _ensureWorkouts();
        }
        _reportingCubit =
            AdminReportingCubit(gateway: gateway, initialQuery: _query);
        if (_usesBusinessReport) _reportingCubit!.load();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _reportingCubit?.close();
    _workoutCubit?.close();
    _scrollController.dispose();
    super.dispose();
  }

  AdminReportQuery _filterQuery() {
    if (_operational) {
      return operationalDateQuery(DateTime.now(),
          days: _days, calendarRange: _customDates);
    }
    final now = widget.now();
    final start = _days == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : now.subtract(Duration(days: _days!));
    return AdminReportQuery(
        range: DateTimeRange(start: start, end: now), branchId: _branch);
  }

  void _onFilterChanged() {
    _query = _filterQuery();
    _sectionQueries[_tab] = _query!;
    if (_usesBusinessReport) _reportingCubit?.load(_query);
    if (_usesWorkoutReport) _ensureWorkouts(force: true);
  }

  bool get _usesWorkoutReport =>
      _tab == ReportsCategory.overview || _tab == ReportsCategory.fitness;

  void _ensureWorkouts({bool force = false}) {
    final cubit = _workoutCubit;
    final query = _query;
    if (cubit == null || query == null) return;
    final lastRead = cubit.state.receivedAt ?? _lastWorkoutRequestAt;
    final fresh =
        lastRead != null && widget.now().difference(lastRead) < _tabFreshness;
    if (!force &&
        fresh &&
        cubit.state.query == query &&
        cubit.state.error == null &&
        (cubit.state.report != null || cubit.state.loading)) {
      assert(() {
        debugPrint('gainpath_report_cache_hit: workouts');
        return true;
      }());
      return;
    }
    _lastWorkoutRequestAt = widget.now();
    cubit.load(query);
  }

  void selectCategory(ReportsCategory tab, {bool resume = false}) {
    if (_tab == tab && !resume) return;
    if (widget.category != tab) widget.onCategoryChanged?.call(tab);
    if (_scrollController.hasClients) {
      _scrollOffsets[_tab] = _scrollController.offset;
    }
    final lastVisited = _lastVisited[tab];
    final gateway = _reportingCubit?.gateway;
    final accessChanged = gateway is AdminReportingSessionGuard &&
        !(gateway as AdminReportingSessionGuard).canRetainSnapshot;
    final expired = accessChanged ||
        lastVisited != null &&
            widget.now().difference(lastVisited) > _tabFreshness;
    setState(() {
      _tab = tab;
      _visitedTabs.add(tab);
      if (_query != null) _sectionQueries[tab] = _query!;
      if (expired) _refreshTokens[tab] = (_refreshTokens[tab] ?? 0) + 1;
      _lastVisited[tab] = widget.now();
    });
    if (_usesWorkoutReport) _ensureWorkouts(force: accessChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo((_scrollOffsets[tab] ?? 0)
          .clamp(0.0, _scrollController.position.maxScrollExtent));
    });
    if (_usesBusinessReport &&
        (expired ||
            _reportingCubit?.state.query != _query ||
            _reportingCubit?.state.snapshot == null)) {
      _reportingCubit?.load(_query);
    }
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
            ? reportMoney(ops == null
                ? null
                : ops.membershipMinor +
                    (snapshot?.unified?.membershipMinor ?? 0))
            : totalRev != null
                ? '${totalRev.currency} ${(totalRev.minorUnits / 100).toStringAsFixed(0)}'
                : '—')
        : 'RM 24,180';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          final gutter = constraints.maxWidth < 600 ? 12.0 : 20.0;
          final available = constraints.maxWidth - gutter * 2;
          final minimum =
              190 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
          final columns = available >= minimum * 5 + 56
              ? 5
              : available >= minimum * 3 + 28
                  ? 3
                  : available >= minimum * 2 + 14
                      ? 2
                      : 1;
          final kpiWidth = (available - (columns - 1) * 14) / columns;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(context),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_usesBusinessReport && reportingState != null)
                            AdminReportingFeedback(
                                state: reportingState,
                                onRetry: _reportingCubit!.refresh),
                          if (_tab == ReportsCategory.fitness &&
                              _workoutCubit != null)
                            BlocBuilder<AdminWorkoutReportingCubit,
                                    AdminWorkoutReportingState>(
                                bloc: _workoutCubit,
                                builder: (_, state) =>
                                    _toolbar(loading: state.loading))
                          else
                            _toolbar(
                                snapshot: _usesBusinessReport ? snapshot : null,
                                loading: _usesBusinessReport &&
                                    (reportingState?.isLoading ?? false)),
                          if (_usesBusinessReport && ops != null)
                            OriginalReportContext(snapshot: snapshot!),
                          const SizedBox(height: 14),
                          if (_visitedTabs.contains(ReportsCategory.overview))
                            _ReportTabBody(
                              key: const ValueKey(ReportsCategory.overview),
                              visible: _tab == ReportsCategory.overview,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      key: _overviewKey,
                                      child: const Eyebrow('Overview')),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: [
                                      SizedBox(
                                          width: kpiWidth,
                                          child: StatTile(
                                              membershipRevenue,
                                              _operational
                                                  ? 'Membership Revenue'
                                                  : 'Membership revenue / month')),
                                      SizedBox(
                                          width: kpiWidth,
                                          child: StatTile(
                                              _operational
                                                  ? reportMoney(ops == null
                                                      ? null
                                                      : ops.coachingMinor +
                                                          (snapshot?.unified
                                                                  ?.coachingMinor ??
                                                              0))
                                                  : widget.live
                                                      ? (completed.isEmpty
                                                          ? '—'
                                                          : 'RM ${coachingRevenue.toStringAsFixed(0)}')
                                                      : 'RM ${coachingRevenue.toStringAsFixed(0)}',
                                              _operational
                                                  ? 'Coaching Revenue'
                                                  : 'Coaching revenue, all completed sessions')),
                                      SizedBox(
                                          width: kpiWidth,
                                          child: StatTile(
                                              _operational
                                                  ? reportMoney(snapshot
                                                          ?.unified
                                                          ?.illustrativeMinor ??
                                                      totalRev?.minorUnits)
                                                  : widget.live
                                                      ? (completed.isEmpty
                                                          ? '—'
                                                          : 'RM ${avgSession.toStringAsFixed(0)}')
                                                      : 'RM ${avgSession.toStringAsFixed(0)}',
                                              _operational
                                                  ? snapshot?.unified == null
                                                      ? 'Confirmed Sandbox receipts'
                                                      : 'Recorded revenue'
                                                  : 'Avg. revenue per session')),
                                      SizedBox(
                                          width: kpiWidth,
                                          child: StatTile(
                                              _operational
                                                  ? (snapshot?.unified != null
                                                          ? BusinessDashboardMetrics(
                                                                  snapshot!,
                                                                  null)
                                                              .bookings
                                                              .toString()
                                                          : snapshot
                                                              ?.totalBookingsCount
                                                              ?.toString()) ??
                                                      '—'
                                                  : widget.live
                                                      ? (completed.isEmpty
                                                          ? '—'
                                                          : '${completed.length}')
                                                      : '${completed.length}',
                                              _operational
                                                  ? 'Booking Activity'
                                                  : 'Completed sessions tracked')),
                                      if (_operational)
                                        SizedBox(
                                          width: kpiWidth,
                                          child: StatTile(
                                              snapshot?.activeMembersCount
                                                      ?.toString() ??
                                                  '—',
                                              'Active members · current'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  if (_workoutCubit != null) ...[
                                    AdminWorkoutSummary(
                                      controller: _workoutCubit!,
                                      onDetails: () => selectCategory(
                                          ReportsCategory.fitness),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  if (ops != null) ...[
                                    const Eyebrow('Recent membership receipts'),
                                    Panel(
                                        child: OriginalReceiptTrend(
                                            snapshot: snapshot!,
                                            membershipOnly: true)),
                                    const SizedBox(height: 20),
                                    const Eyebrow('Insights & attention'),
                                    Panel(
                                        child: Column(children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                            Icons.event_busy_outlined),
                                        title: Text(
                                            '${snapshot.unified == null ? ops.statuses['cancelled'] : BusinessDashboardMetrics(snapshot, null).cancelled} cancelled bookings'),
                                        subtitle: const Text(
                                            'Current outcomes for bookings created in the selected period.'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () => selectCategory(
                                            ReportsCategory.coaching),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                            Icons.receipt_long_outlined,
                                            color: ops.reviewCount > 0
                                                ? AppColors.warning
                                                : AppColors.inkSoft),
                                        title: Text(ops.reviewCount == 0
                                            ? 'No payment records awaiting review'
                                            : '${ops.reviewCount} payment records awaiting review'),
                                        subtitle: const Text(
                                            'Payment states in the selected period.'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () => selectCategory(
                                            ReportsCategory.financial),
                                      ),
                                    ])),
                                  ],
                                ],
                              ),
                            ),
                          if (_visitedTabs.contains(ReportsCategory.financial))
                            _ReportTabBody(
                              key: const ValueKey(ReportsCategory.financial),
                              visible: _tab == ReportsCategory.financial,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  wide
                                      ? IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                  child: _branchColumn(context,
                                                      snapshot: snapshot)),
                                            ],
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            _salesColumn(
                                                context,
                                                topCoaches,
                                                revenueByCoach,
                                                sessionsByCoach,
                                                maxCoachRevenue,
                                                snapshot: snapshot),
                                            const SizedBox(height: 20),
                                            _branchColumn(context,
                                                snapshot: snapshot),
                                          ],
                                        ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 28),
                                  RevenueSection(
                                      anchorKey: _revenueKey,
                                      live: widget.live,
                                      snapshot: snapshot),
                                ],
                              ),
                            ),
                          if (_visitedTabs.contains(ReportsCategory.fitness))
                            _ReportTabBody(
                              key: const ValueKey(ReportsCategory.fitness),
                              visible: _tab == ReportsCategory.fitness,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_operational && _reportingCubit != null)
                                    AdminWorkoutAnalytics(
                                        controller: _workoutCubit,
                                        query: _sectionQueries[
                                                ReportsCategory.fitness] ??
                                            _query!,
                                        refreshToken: _refreshTokens[
                                                ReportsCategory.fitness] ??
                                            0,
                                        anchorKey: _workoutsKey),
                                  if (_operational && _reportingCubit != null)
                                    AdminPostureSection(
                                        controller: _workoutCubit,
                                        query: _sectionQueries[
                                                ReportsCategory.fitness] ??
                                            _query!,
                                        anchorKey: _postureKey,
                                        refreshToken: _refreshTokens[
                                                ReportsCategory.fitness] ??
                                            0)
                                  else
                                    PostureAccuracySection(
                                        anchorKey: _postureKey,
                                        live: widget.live),
                                ],
                              ),
                            ),
                          if (_visitedTabs.contains(ReportsCategory.coaching))
                            _ReportTabBody(
                              key: const ValueKey(ReportsCategory.coaching),
                              visible: _tab == ReportsCategory.coaching,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (snapshot?.commerce != null)
                                    AdminCoachActivitySection(
                                        anchorKey: _bookingKey,
                                        report: snapshot!.commerce!)
                                  else
                                    CoachBookingUtilizationSection(
                                        anchorKey: _bookingKey,
                                        filter: filter,
                                        live: widget.live,
                                        snapshot: snapshot),
                                  CoachPerformanceSection(
                                      anchorKey: _coachPerfKey,
                                      snapshot: snapshot,
                                      filter: filter,
                                      live: widget.live),
                                ],
                              ),
                            ),
                          if (_visitedTabs.contains(ReportsCategory.engagement))
                            _ReportTabBody(
                              key: const ValueKey(ReportsCategory.engagement),
                              visible: _tab == ReportsCategory.engagement,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_operational && _reportingCubit != null)
                                    AdminObservedSection(
                                        query: _sectionQueries[
                                                ReportsCategory.engagement] ??
                                            _query!,
                                        anchorKey: _usageKey,
                                        refreshToken: _refreshTokens[
                                                ReportsCategory.engagement] ??
                                            0)
                                  else
                                    UsageEngagementSection(
                                        anchorKey: _usageKey,
                                        filter: filter,
                                        live: widget.live),
                                  if (_operational && _reportingCubit != null)
                                    AdminObservedSection(
                                        query: _sectionQueries[
                                                ReportsCategory.engagement] ??
                                            _query!,
                                        anchorKey: _retentionKey,
                                        retention: true,
                                        refreshToken: _refreshTokens[
                                                ReportsCategory.engagement] ??
                                            0)
                                  else
                                    RetentionRiskSection(
                                        anchorKey: _retentionKey,
                                        live: widget.live),
                                  RewardsSection(
                                      anchorKey: _rewardsKey,
                                      live: widget.live,
                                      query: _operational
                                          ? (_sectionQueries[
                                                  ReportsCategory.engagement] ??
                                              _query)
                                          : null,
                                      refreshToken: _refreshTokens[
                                              ReportsCategory.engagement] ??
                                          0),
                                  GamificationSection(
                                      anchorKey: _gamificationKey,
                                      live: widget.live,
                                      query: _operational
                                          ? (_sectionQueries[
                                                  ReportsCategory.engagement] ??
                                              _query)
                                          : null,
                                      refreshToken: _refreshTokens[
                                              ReportsCategory.engagement] ??
                                          0),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _usesBusinessReport =>
      _tab != ReportsCategory.fitness && _tab != ReportsCategory.engagement;

  Widget _header(BuildContext context) => Text('${_tab.label} Analytics',
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w700));

  Future<void> _exportEngagement() async {
    final gateway = _reportingCubit?.gateway;
    final query = _query;
    if (gateway is! AdminCheckInReportingGateway || query == null) return;
    setState(() => _exporting = true);
    try {
      final report =
          await (gateway as AdminCheckInReportingGateway).loadCheckIns(query);
      if (mounted && _query == query && _tab == ReportsCategory.engagement) {
        downloadCsv('gainpath-engagement.csv', report.toCsv());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export unavailable. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    onSelected: (_) => setState(() {
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
                if (!_operational)
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
                      onPressed: () async {
                        final day = DateTime.now().toUtc().add(adminReportZone);
                        final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(1970),
                            lastDate: DateTime(day.year, day.month, day.day),
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
                              setState(() => _refreshTokens[_tab] =
                                  (_refreshTokens[_tab] ?? 0) + 1);
                              if (_usesWorkoutReport) {
                                _ensureWorkouts(force: true);
                              }
                              if (_usesBusinessReport) {
                                _reportingCubit?.refresh();
                              }
                            },
                      icon: const Icon(Icons.refresh_rounded, size: 18)),
                  TextButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: Text(_exporting ? 'Exporting…' : 'Export CSV'),
                      onPressed: loading || _exporting
                          ? null
                          : _tab == ReportsCategory.fitness
                              ? (_workoutCubit?.state.report == null
                                  ? null
                                  : () => downloadCsv(
                                      'gainpath-workout-activity.csv',
                                      _workoutCubit!.state.report!.toCsv()))
                              : _tab == ReportsCategory.engagement
                                  ? (_reportingCubit?.gateway
                                          is AdminCheckInReportingGateway
                                      ? _exportEngagement
                                      : null)
                                  : snapshot?.operations == null
                                      ? null
                                      : () => downloadCsv(
                                          'gainpath-operational-report.csv',
                                          snapshot!.unified != null
                                              ? BusinessDashboardMetrics(
                                                      snapshot, null)
                                                  .csv()
                                              : snapshot.operations!
                                                  .toCsv(snapshot))),
                ],
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
                    ? 'Recorded membership collections in the selected period'
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

class _ReportTabBody extends StatelessWidget {
  const _ReportTabBody({super.key, required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
      offstage: !visible, child: TickerMode(enabled: visible, child: child));
}
