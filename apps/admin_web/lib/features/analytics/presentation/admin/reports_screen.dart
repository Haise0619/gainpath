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
import '../../application/business_dashboard_metrics.dart';

enum _ReportsTab {
  overview('Overview'),
  financial('Financial'),
  fitness('Fitness'),
  coaching('Coaching'),
  engagement('Engagement');

  const _ReportsTab(this.label);
  final String label;
}

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
    null: 'All recorded dates',
    7: '7 days',
    30: '30 days',
    90: '90 days'
  };

  int? _days;
  DateTimeRange? _customDates;
  String? _branch;
  AdminReportingCubit? _reportingCubit;
  final _scrollController = ScrollController();
  final _scrollOffsets = <_ReportsTab, double>{};
  final _visitedTabs = <_ReportsTab>{_ReportsTab.overview};
  final _sectionQueries = <_ReportsTab, AdminReportQuery>{};
  final _refreshTokens = <_ReportsTab, int>{};
  final _lastVisited = <_ReportsTab, DateTime>{};
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

  _ReportsTab _tab = _ReportsTab.overview;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.live) {
      try {
        final gateway = context.watch<AdminReportingGateway>();
        if (identical(_reportingCubit?.gateway, gateway)) return;
        _reportingCubit?.close();
        _visitedTabs
          ..clear()
          ..add(_ReportsTab.overview);
        _sectionQueries.clear();
        _refreshTokens.clear();
        _lastVisited.clear();
        _scrollOffsets.clear();
        _tab = _ReportsTab.overview;
        _operational = gateway is OperationalAdminReportingGateway;
        _query = _filterQuery();
        _lastVisited[_ReportsTab.overview] = DateTime.now();
        _reportingCubit =
            AdminReportingCubit(gateway: gateway, initialQuery: _query)..load();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _reportingCubit?.close();
    _scrollController.dispose();
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

  void _onFilterChanged() {
    _query = _filterQuery();
    _sectionQueries[_tab] = _query!;
    if (_usesBusinessReport) _reportingCubit?.load(_query);
  }

  void _selectTab(_ReportsTab tab) {
    if (_tab == tab) return;
    if (_scrollController.hasClients) {
      _scrollOffsets[_tab] = _scrollController.offset;
    }
    final lastVisited = _lastVisited[tab];
    final gateway = _reportingCubit?.gateway;
    final accessChanged = gateway is AdminReportingSessionGuard &&
        !(gateway as AdminReportingSessionGuard).canRetainSnapshot;
    final expired = accessChanged ||
        lastVisited != null &&
            DateTime.now().difference(lastVisited) > _tabFreshness;
    setState(() {
      _tab = tab;
      _visitedTabs.add(tab);
      if (_query != null) _sectionQueries[tab] = _query!;
      if (expired) _refreshTokens[tab] = (_refreshTokens[tab] ?? 0) + 1;
      _lastVisited[tab] = DateTime.now();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo((_scrollOffsets[tab] ?? 0)
          .clamp(0.0, _scrollController.position.maxScrollExtent));
    });
    if (_usesBusinessReport &&
        (expired || _reportingCubit?.state.query != _query)) {
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
          final kpiWidth =
              (220 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5))
                  .clamp(0.0, constraints.maxWidth - 24)
                  .toDouble();
          final gutter = constraints.maxWidth < 600 ? 12.0 : 24.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(context),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tab in _ReportsTab.values)
                              ChoiceChip(
                                label: Text(tab.label),
                                selected: _tab == tab,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                    color: _tab == tab
                                        ? Colors.white
                                        : AppColors.ink,
                                    fontWeight: FontWeight.w600),
                                onSelected: (_) => _selectTab(tab),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
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
                          _toolbar(
                              snapshot: _usesBusinessReport ? snapshot : null,
                              loading: _usesBusinessReport &&
                                  (reportingState?.isLoading ?? false)),
                          if (_usesBusinessReport && snapshot?.unified != null)
                            const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                    BusinessDashboardMetrics.revenueDefinition,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.inkSoft))),
                          if (_usesBusinessReport && ops != null)
                            OriginalReportContext(snapshot: snapshot!),
                          const SizedBox(height: 26),
                          if (_visitedTabs.contains(_ReportsTab.overview))
                            Offstage(
                              key: const ValueKey(_ReportsTab.overview),
                              offstage: _tab != _ReportsTab.overview,
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
                                  if (ops != null) ...[
                                    const Eyebrow('Recent membership receipts'),
                                    Panel(
                                        child: OriginalReceiptTrend(
                                            snapshot: snapshot!,
                                            membershipOnly: true)),
                                    const SizedBox(height: 20),
                                    const Eyebrow('Insights & attention'),
                                    Panel(
                                        child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading:
                                          const Icon(Icons.event_busy_outlined),
                                      title: Text(
                                          '${snapshot.unified == null ? ops.statuses['cancelled'] : BusinessDashboardMetrics(snapshot, null).cancelled} cancelled bookings'),
                                      subtitle: const Text(
                                          'Current outcomes for bookings created in the selected period.'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () =>
                                          _selectTab(_ReportsTab.coaching),
                                    )),
                                  ],
                                ],
                              ),
                            ),
                          if (_visitedTabs.contains(_ReportsTab.financial))
                            Offstage(
                              key: const ValueKey(_ReportsTab.financial),
                              offstage: _tab != _ReportsTab.financial,
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
                          if (_visitedTabs.contains(_ReportsTab.fitness))
                            Offstage(
                              key: const ValueKey(_ReportsTab.fitness),
                              offstage: _tab != _ReportsTab.fitness,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_operational && _reportingCubit != null)
                                    AdminWorkoutAnalytics(
                                        query: _sectionQueries[
                                                _ReportsTab.fitness] ??
                                            _query!,
                                        refreshToken: _refreshTokens[
                                                _ReportsTab.fitness] ??
                                            0,
                                        anchorKey: _workoutsKey),
                                  if (_operational && _reportingCubit != null)
                                    AdminPostureSection(
                                        query: _sectionQueries[
                                                _ReportsTab.fitness] ??
                                            _query!,
                                        anchorKey: _postureKey,
                                        refreshToken: _refreshTokens[
                                                _ReportsTab.fitness] ??
                                            0)
                                  else
                                    PostureAccuracySection(
                                        anchorKey: _postureKey,
                                        live: widget.live),
                                ],
                              ),
                            ),
                          if (_visitedTabs.contains(_ReportsTab.coaching))
                            Offstage(
                              key: const ValueKey(_ReportsTab.coaching),
                              offstage: _tab != _ReportsTab.coaching,
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
                          if (_visitedTabs.contains(_ReportsTab.engagement))
                            Offstage(
                              key: const ValueKey(_ReportsTab.engagement),
                              offstage: _tab != _ReportsTab.engagement,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_operational && _reportingCubit != null)
                                    AdminObservedSection(
                                        query: _sectionQueries[
                                                _ReportsTab.engagement] ??
                                            _query!,
                                        anchorKey: _usageKey,
                                        refreshToken: _refreshTokens[
                                                _ReportsTab.engagement] ??
                                            0)
                                  else
                                    UsageEngagementSection(
                                        anchorKey: _usageKey,
                                        filter: filter,
                                        live: widget.live),
                                  if (_operational && _reportingCubit != null)
                                    AdminObservedSection(
                                        query: _sectionQueries[
                                                _ReportsTab.engagement] ??
                                            _query!,
                                        anchorKey: _retentionKey,
                                        retention: true,
                                        refreshToken: _refreshTokens[
                                                _ReportsTab.engagement] ??
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
                                                  _ReportsTab.engagement] ??
                                              _query)
                                          : null,
                                      refreshToken: _refreshTokens[
                                              _ReportsTab.engagement] ??
                                          0),
                                  GamificationSection(
                                      anchorKey: _gamificationKey,
                                      live: widget.live,
                                      query: _operational
                                          ? (_sectionQueries[
                                                  _ReportsTab.engagement] ??
                                              _query)
                                          : null,
                                      refreshToken: _refreshTokens[
                                              _ReportsTab.engagement] ??
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
      _tab != _ReportsTab.fitness && _tab != _ReportsTab.engagement;

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
              Text('Membership, coaching, fitness and member engagement.',
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
                              if (_usesBusinessReport) {
                                _reportingCubit?.refresh();
                              }
                            },
                      icon: const Icon(Icons.refresh_rounded, size: 18)),
                  TextButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text('Export overview CSV'),
                      onPressed: loading || snapshot?.operations == null
                          ? null
                          : () => downloadCsv(
                              'gainpath-operational-report.csv',
                              snapshot!.unified != null
                                  ? BusinessDashboardMetrics(snapshot, null)
                                      .csv()
                                  : snapshot.operations!.toCsv(snapshot))),
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
