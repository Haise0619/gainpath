import '../../application/admin_check_in_reporting.dart';
import 'branch_report_dialog.dart';
import 'admin_remaining_analytics.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'sections/commerce_sections.dart';
import 'sections/engagement_sections.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../application/admin_reporting_cubit.dart';
import 'admin_reporting_feedback.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/admin_operational_metrics.dart';
import 'original_report_data_widgets.dart';
import 'admin_workout_analytics.dart';
import 'admin_coaching_analytics.dart';
import 'admin_engagement_analytics.dart';
import '../../application/admin_workout_reporting.dart';
import '../../application/business_dashboard_metrics.dart';
import '../../application/unified_admin_summary.dart';
import 'analytics_shared_components.dart';

enum ReportsCategory {
  overview('Overview'),
  financial('Financial'),
  fitness('Fitness'),
  coaching('Coaching'),
  engagement('Engagement'),
  branches('Branches');

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
      this.onCategoryChanged,
      this.initialBranchId,
      this.initialDate,
      this.branchRequest});
  final ReportsCategory category;
  final bool active;
  final DateTime Function() now;
  final ValueChanged<ReportsCategory>? onCategoryChanged;
  final BranchRequest? branchRequest;
  final String? initialBranchId;
  final DateTime? initialDate;

  @override
  State<ReportsScreen> createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> {
  bool _operational = false;
  bool _exporting = false;

  int? _days;
  DateTimeRange? _customDates;
  String? _reportScope;
  final int _branchRefresh = 0;
  Future<List<Map<String, dynamic>>>? _reportBranches;
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
    if (widget.initialBranchId != null) {
      _reportScope = 'branch:${widget.initialBranchId}';
    }
    _tab = widget.category;
    _applyInitialDate();
    _visitedTabs
      ..clear()
      ..add(_tab);
  }

  @override
  void didUpdateWidget(covariant ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.branchRequest == null) != (widget.branchRequest == null)) {
      _reportBranches = null;
      _reportScope = null;
    }
    final dateChanged = oldWidget.initialDate != widget.initialDate;
    if (oldWidget.initialBranchId != widget.initialBranchId ||
        (dateChanged && widget.initialDate != null)) {
      _reportScope = widget.initialBranchId == null
          ? null
          : 'branch:${widget.initialBranchId}';
    }
    if (dateChanged) {
      _applyInitialDate();
      _query = _filterQuery();
    }
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

  void _applyInitialDate() {
    final day = widget.initialDate;
    _customDates = day == null ? null : DateTimeRange(start: day, end: day);
    _days = day == null ? _days : null;
  }

  AdminReportQuery _filterQuery() {
    if (_operational || _tab == ReportsCategory.branches) {
      return operationalDateQuery(widget.now(),
          days: _days, calendarRange: _customDates);
    }
    final now = widget.now();
    final start = _days == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : now.subtract(Duration(days: _days!));
    return AdminReportQuery(
        range: DateTimeRange(start: start, end: now), branchId: null);
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
    if (_tab == ReportsCategory.branches) return _buildBranchAnalytics();
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
    final filter = ReportFilter(days: _days);

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
                        _header(context,
                            snapshot: _usesBusinessReport ? snapshot : null,
                            loading: _usesBusinessReport &&
                                (reportingState?.isLoading ?? false)),
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
                          const SizedBox(height: 14),
                          if (_usesBusinessReport && ops != null)
                            AnalyticsDataScope(snapshot: snapshot!),
                          if (_visitedTabs.contains(ReportsCategory.overview))
                            _ReportTabBody(
                              key: const ValueKey(ReportsCategory.overview),
                              visible: _tab == ReportsCategory.overview,
                              child: _buildOverviewTab(
                                context,
                                snapshot,
                                kpiWidth: kpiWidth,
                                wide: wide,
                                completed: completed,
                                coachingRevenue: coachingRevenue,
                                avgSession: avgSession,
                              ),
                            ),
                          if (_visitedTabs.contains(ReportsCategory.financial))
                            _ReportTabBody(
                              key: const ValueKey(ReportsCategory.financial),
                              visible: _tab == ReportsCategory.financial,
                              child: _buildFinancialTab(
                                context,
                                snapshot,
                                wide: wide,
                                topCoaches: topCoaches,
                                revenueByCoach: revenueByCoach,
                                sessionsByCoach: sessionsByCoach,
                                maxCoachRevenue: maxCoachRevenue,
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
                                        anchorKey: _workoutsKey,
                                        postureSection: AdminPostureSection(
                                            controller: _workoutCubit,
                                            query: _sectionQueries[
                                                    ReportsCategory.fitness] ??
                                                _query!,
                                            anchorKey: _postureKey,
                                            refreshToken: _refreshTokens[
                                                    ReportsCategory.fitness] ??
                                                0))
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
                              child: AdminCoachingAnalytics(
                                snapshot: snapshot,
                                filter: filter,
                                live: widget.live,
                                anchorKey: _bookingKey,
                                coachPerfKey: _coachPerfKey,
                              ),
                            ),
                          if (_visitedTabs.contains(ReportsCategory.engagement))
                            _ReportTabBody(
                              key: const ValueKey(ReportsCategory.engagement),
                              visible: _tab == ReportsCategory.engagement,
                              child: AdminEngagementAnalytics(
                                query: _sectionQueries[
                                        ReportsCategory.engagement] ??
                                    _query!,
                                refreshToken: _refreshTokens[
                                        ReportsCategory.engagement] ??
                                    0,
                                live: widget.live,
                                operational:
                                    _operational && _reportingCubit != null,
                                filter: filter,
                                usageKey: _usageKey,
                                retentionKey: _retentionKey,
                                rewardsKey: _rewardsKey,
                                gamificationKey: _gamificationKey,
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

  Widget _buildBranchAnalytics() {
    final request = widget.branchRequest;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _header(context, loading: false),
          const SizedBox(height: 12),
          _toolbar(),
          const SizedBox(height: 14),
          if (request == null)
            const Text('Branch analytics is unavailable for this session.')
          else
            BranchReportDialog(
              key: ValueKey(_branchRefresh),
              request: request,
              range: (_query ??= _filterQuery()).range,
              fixedScope: _reportScope ?? 'all',
              embedded: true,
              onSelectScope: (scope) => setState(() => _reportScope = scope),
            ),
        ],
      ),
    );
  }

  bool get _usesBusinessReport =>
      _tab == ReportsCategory.overview ||
      _tab == ReportsCategory.financial ||
      _tab == ReportsCategory.coaching;

  Widget _branchSelector() => FutureBuilder<List<Map<String, dynamic>>>(
        future: _reportBranches ??= loadReportBranches(widget.branchRequest!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => setState(() => _reportBranches = null),
              child: const Text('Branches unavailable · Retry'),
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              width: 80,
              height: 20,
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.hairline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reportScope == 'unassigned' ||
                        snapshot.data!.any((branch) =>
                            'branch:${branch['branchId']}' == _reportScope)
                    ? _reportScope
                    : '',
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: AppColors.inkSoft),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                isDense: true,
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('All branches')),
                  const DropdownMenuItem(
                      value: 'unassigned', child: Text('Unassigned records')),
                  for (final branch in snapshot.data!)
                    DropdownMenuItem(
                      value: 'branch:${branch['branchId']}',
                      child: Text(
                          '${branch['displayName']}${branch['status'] == 'inactive' ? ' (inactive)' : ''}'),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _reportScope = value == '' ? null : value;
                  _query ??= _filterQuery();
                }),
              ),
            ),
          );
        },
      );

  Widget _header(BuildContext context,
      {AdminReportingSnapshot? snapshot, bool loading = false}) {
    String subtitle;
    switch (_tab) {
      case ReportsCategory.overview:
        subtitle =
            'High-level fitness center performance, revenue summary, member activity, and operational alerts.';
        break;
      case ReportsCategory.financial:
        subtitle =
            'Revenue trends, membership vs coaching composition, payment clearance breakdowns, and plan distribution.';
        break;
      case ReportsCategory.fitness:
        subtitle =
            'Workout activity, exercise performance and AI form estimates.';
        break;
      case ReportsCategory.coaching:
        subtitle = 'Booking activity, session outcomes and coach insights.';
        break;
      case ReportsCategory.engagement:
        subtitle = 'Recorded member engagement, rewards and activity insights.';
        break;
      case ReportsCategory.branches:
        subtitle =
            'Multi-location facility capacity, assigned equipment, and branch performance.';
        break;
    }

    final canExport = _tab != ReportsCategory.branches &&
        (_tab == ReportsCategory.fitness
            ? _workoutCubit?.state.report != null
            : _tab == ReportsCategory.engagement
                ? _reportingCubit?.gateway is AdminCheckInReportingGateway
                : _tab == ReportsCategory.coaching
                    ? (snapshot?.commerce != null ||
                        snapshot?.operations != null)
                    : snapshot?.operations != null);

    return AnalyticsPageHeader(
      title: _tab == ReportsCategory.branches
          ? 'Branch Analytics'
          : '${_tab.label} Analytics',
      subtitle: subtitle,
      loading: loading,
      exporting: _exporting,
      exportEnabled: canExport,
      onRefresh: loading
          ? null
          : () {
              setState(
                  () => _refreshTokens[_tab] = (_refreshTokens[_tab] ?? 0) + 1);
              if (_usesWorkoutReport) _ensureWorkouts(force: true);
              if (_usesBusinessReport) _reportingCubit?.refresh();
            },
      onExport: _tab == ReportsCategory.branches
          ? null
          : () {
              final snap = snapshot;
              if (_tab == ReportsCategory.fitness) {
                if (_workoutCubit?.state.report != null) {
                  downloadCsv('gainpath-workout-activity.csv',
                      _workoutCubit!.state.report!.toCsv());
                }
              } else if (_tab == ReportsCategory.engagement) {
                if (_reportingCubit?.gateway is AdminCheckInReportingGateway) {
                  _exportEngagement();
                }
              } else if (_tab == ReportsCategory.coaching) {
                if (snap?.commerce != null) {
                  downloadCsv(
                    'coach_performance.csv',
                    snap!.commerce!.csv(coach: true),
                  );
                } else if (snap?.operations != null) {
                  downloadCsv(
                    'coach_booking_activity.csv',
                    [
                      ['GainPath booking activity', 'Not capacity utilization'],
                      [
                        'Start inclusive UTC',
                        snap!.query.range.start.toUtc().toIso8601String()
                      ],
                      [
                        'End exclusive UTC',
                        snap.query.range.end.toUtc().toIso8601String()
                      ],
                      ['Timezone', 'Asia/Kuala_Lumpur'],
                      [
                        'Bookings created in range',
                        snap.totalBookingsCount ?? 0
                      ],
                      [
                        'Confirmed/completed scheduled starts',
                        snap.operations!.scheduledStarts
                      ],
                      ['Current status of bookings created in range', 'Count'],
                      for (final e in snap.operations!.statuses.entries)
                        [e.key, e.value],
                    ],
                  );
                }
              } else {
                if (snap?.operations != null) {
                  final filename = _tab == ReportsCategory.financial
                      ? 'gainpath-financial-analytics.csv'
                      : 'gainpath-overview-analytics.csv';
                  downloadCsv(
                    filename,
                    snap!.unified != null
                        ? BusinessDashboardMetrics(snap, null).csv()
                        : snap.operations!.toCsv(snap),
                  );
                }
              }
            },
    );
  }

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
    return AnalyticsDateRangeToolbar(
      selectedDays: _days,
      customRange: _customDates,
      loading: loading,
      branchSelector:
          (_tab == ReportsCategory.branches && widget.branchRequest != null)
              ? _branchSelector()
              : null,
      onSelectDays: (days) => setState(() {
        _customDates = null;
        _days = days;
        _onFilterChanged();
      }),
      onPickCustomDates: () async {
        final day = DateTime.now().toUtc().add(adminReportZone);
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(1970),
          lastDate: DateTime(day.year, day.month, day.day),
          initialDateRange: _customDates,
        );
        if (range != null && mounted) {
          setState(() {
            _customDates = range;
            _onFilterChanged();
          });
        }
      },
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    AdminReportingSnapshot? snapshot, {
    required double kpiWidth,
    required bool wide,
    required List<Booking> completed,
    required double coachingRevenue,
    required double avgSession,
  }) {
    final ops = snapshot?.operations;
    final totalRev = snapshot?.totalRevenue;
    BusinessDashboardMetrics? m;
    if (snapshot?.unified != null && ops != null && snapshot!.isAvailable) {
      try {
        m = BusinessDashboardMetrics(snapshot, _workoutCubit?.state.report);
      } catch (_) {}
    }

    final String revValue = _operational
        ? reportMoney(snapshot?.unified?.illustrativeMinor ??
            totalRev?.minorUnits ??
            (ops != null ? ops.membershipMinor + ops.coachingMinor : null))
        : (totalRev != null
            ? '${totalRev.currency} ${(totalRev.minorUnits / 100).toStringAsFixed(0)}'
            : 'RM 24,180');

    final String membershipRevValue = _operational
        ? reportMoney(ops == null
            ? null
            : ops.membershipMinor + (snapshot?.unified?.membershipMinor ?? 0))
        : (totalRev != null
            ? '${totalRev.currency} ${(totalRev.minorUnits / 100).toStringAsFixed(0)}'
            : 'RM 24,180');

    final String coachingRevValue = _operational
        ? reportMoney(ops == null
            ? null
            : ops.coachingMinor + (snapshot?.unified?.coachingMinor ?? 0))
        : (widget.live
            ? (completed.isEmpty
                ? '—'
                : 'RM ${coachingRevenue.toStringAsFixed(0)}')
            : 'RM ${coachingRevenue.toStringAsFixed(0)}');

    final String bookingVal = _operational
        ? ((snapshot?.unified != null
                ? BusinessDashboardMetrics(snapshot!, null).bookings.toString()
                : snapshot?.totalBookingsCount?.toString()) ??
            '—')
        : (widget.live
            ? (completed.isEmpty ? '—' : '${completed.length}')
            : '${completed.length}');

    final String membersVal = snapshot?.activeMembersCount?.toString() ?? '—';

    final int cancelledBookings = snapshot?.unified == null
        ? (ops?.statuses['cancelled'] ?? 0)
        : (m?.cancelled ?? 0);
    final int reviewCount = ops?.reviewCount ?? 0;
    final int reviewMinor = ops?.reviewMinor ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(key: _overviewKey, child: const SizedBox.shrink()),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            AnalyticsMetricCard(
              width: kpiWidth,
              highlighted: true,
              label: _operational
                  ? (snapshot?.unified != null
                      ? 'Recorded revenue'
                      : 'Confirmed Sandbox receipts')
                  : 'Recorded revenue',
              value: revValue,
              icon: Icons.payments_outlined,
              contextNote: snapshot?.unified != null
                  ? 'Includes non-cash scenario value'
                  : 'Cleared sandbox receipts',
            ),
            AnalyticsMetricCard(
              width: kpiWidth,
              label: _operational
                  ? 'Membership Revenue'
                  : 'Membership revenue / month',
              value: membershipRevValue,
              icon: Icons.card_membership_outlined,
              contextNote: 'Subscriptions & platform access',
            ),
            AnalyticsMetricCard(
              width: kpiWidth,
              label: _operational
                  ? 'Coaching Revenue'
                  : 'Coaching revenue, all completed sessions',
              value: coachingRevValue,
              icon: Icons.sports_outlined,
              contextNote: 'Completed trainer appointments',
            ),
            AnalyticsMetricCard(
              width: kpiWidth,
              label: 'Active members · current',
              value: membersVal,
              icon: Icons.people_outline_rounded,
              contextNote: 'Organization current census',
            ),
            AnalyticsMetricCard(
              width: kpiWidth,
              label: _operational
                  ? 'Booking Activity'
                  : 'Completed sessions tracked',
              value: bookingVal,
              icon: Icons.event_available_outlined,
              contextNote: 'Recorded appointments in period',
            ),
          ],
        ),
        const SizedBox(height: 20),
        wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildOverviewRevenueCard(context, snapshot, m, ops),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: _buildOverviewWorkoutCard(context, snapshot),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildOverviewRevenueCard(context, snapshot, m, ops),
                  const SizedBox(height: 20),
                  _buildOverviewWorkoutCard(context, snapshot),
                ],
              ),
        const SizedBox(height: 20),
        wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildOverviewBookingCard(context, snapshot, m, ops),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: AnalyticsAttentionPanel(
                      cancelledCount: cancelledBookings,
                      reviewCount: reviewCount,
                      reviewMinor: reviewMinor,
                      onOpenCoaching: () =>
                          selectCategory(ReportsCategory.coaching),
                      onOpenFinancial: () =>
                          selectCategory(ReportsCategory.financial),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildOverviewBookingCard(context, snapshot, m, ops),
                  const SizedBox(height: 20),
                  AnalyticsAttentionPanel(
                    cancelledCount: cancelledBookings,
                    reviewCount: reviewCount,
                    reviewMinor: reviewMinor,
                    onOpenCoaching: () =>
                        selectCategory(ReportsCategory.coaching),
                    onOpenFinancial: () =>
                        selectCategory(ReportsCategory.financial),
                  ),
                ],
              ),
        const SizedBox(height: 20),
        AnalyticsQuickLinks(
          onOpenFinancial: () => selectCategory(ReportsCategory.financial),
          onOpenFitness: () => selectCategory(ReportsCategory.fitness),
          onOpenCoaching: () => selectCategory(ReportsCategory.coaching),
          onOpenEngagement: () => selectCategory(ReportsCategory.engagement),
        ),
      ],
    );
  }

  Widget _buildOverviewRevenueCard(
    BuildContext context,
    AdminReportingSnapshot? snapshot,
    BusinessDashboardMetrics? m,
    AdminOperationalMetrics? ops,
  ) {
    if (m != null) {
      return AnalyticsChartCard(
        title: 'Revenue & Trend Overview',
        subtitle:
            'Recorded revenue trajectory and membership vs coaching ratio',
        badge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Text(
            'Scenario-inclusive',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        footer: const Text(
          BusinessDashboardMetrics.revenueDefinition,
          style: TextStyle(
            fontSize: 11.5,
            color: AppColors.inkSoft,
            height: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: _buildMonthlySplineChart(m.monthly),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 16),
            _buildRevenueBreakdownDonut(m),
          ],
        ),
      );
    }

    if (ops != null) {
      return AnalyticsChartCard(
        title: 'Recent Membership Receipts',
        subtitle: 'Confirmed Sandbox collections · original clearance dates',
        badge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.hairline),
          ),
          child: const Text(
            'Sandbox · Cleared',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OriginalReceiptTrend(snapshot: snapshot!, membershipOnly: true),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: 14),
            OriginalReceiptBreakdown(snapshot: snapshot),
          ],
        ),
      );
    }

    return const AnalyticsChartCard(
      title: 'Revenue History',
      subtitle: 'Simulated baseline revenue history',
      child: TrendChart([18200, 19400, 21000, 20600, 22800, 23400, 24180]),
    );
  }

  Widget _buildOverviewWorkoutCard(
    BuildContext context,
    AdminReportingSnapshot? snapshot,
  ) {
    final cubit = _workoutCubit;
    if (cubit == null) {
      return const AnalyticsChartCard(
        title: 'Workout Activity Summary',
        subtitle: 'AI computer vision exercises and form metrics',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Workout reporting service is not connected.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ),
        ),
      );
    }

    return BlocBuilder<AdminWorkoutReportingCubit, AdminWorkoutReportingState>(
      bloc: cubit,
      builder: (context, state) {
        final report = state.report;
        return AnalyticsChartCard(
          title: 'Workout Activity Summary',
          subtitle: 'AI camera exercises and active member coverage',
          trailing: TextButton.icon(
            onPressed: () => selectCategory(ReportsCategory.fitness),
            icon: const Icon(Icons.arrow_forward_rounded, size: 15),
            label: const Text(
              'View Fitness',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                  ),
                ),
              if (state.error != null) ...[
                Text(
                  state.error!,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger),
                ),
                TextButton(
                  onPressed: () => cubit.load(),
                  child: const Text('Retry workout summary'),
                ),
              ] else if (report == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Loading synced workout activity…',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  ),
                )
              else ...[
                if (report.fypSourceUnavailable)
                  const Text('Partial · canonical backups only'),
                if (report.mixedSources || report.fictional) ...[
                  Text(
                    report.fictional
                        ? 'FYP scenario observations.'
                        : 'Includes recorded FYP scenario observations.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                MemberWorkoutCoverageRing(
                  membersWithActivity:
                      report.coverage['membersWithActivity'] ?? 0,
                  totalActiveMembers: report.coverage['activeMembers'] ??
                      snapshot?.activeMembersCount ??
                      0,
                  isLoading: state.loading,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCompactWorkoutTile(
                      '${report.totals.sessions}',
                      report.fictional
                          ? 'Scenario workout sessions'
                          : (report.mixedSources
                              ? 'Workout observations'
                              : 'Saved workout sessions'),
                      Icons.fitness_center_outlined,
                    ),
                    _buildCompactWorkoutTile(
                      '${report.coverage['membersWithActivity'] ?? 0}',
                      'Active workout members',
                      Icons.people_outline_rounded,
                    ),
                    _buildCompactWorkoutTile(
                      '${report.totals.completedRoutineDays}',
                      'Completed workout attempts',
                      Icons.task_alt_rounded,
                    ),
                    _buildCompactWorkoutTile(
                      '${report.totals.fullReps}',
                      'Full repetitions',
                      Icons.repeat_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Completed attempts use saved routine outcomes, including manual and timed targets.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.inkSoft,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewBookingCard(
    BuildContext context,
    AdminReportingSnapshot? snapshot,
    BusinessDashboardMetrics? m,
    AdminOperationalMetrics? ops,
  ) {
    final int bookingsCount = m?.bookings ??
        snapshot?.totalBookingsCount ??
        (snapshot?.operations?.daily
                .fold<int>(0, (sum, d) => sum + d.bookingsCreated) ??
            0);
    final int completedCount =
        m?.completed ?? (ops?.statuses['completed'] ?? 0);
    final int cancelledCount =
        m?.cancelled ?? (ops?.statuses['cancelled'] ?? 0);
    final int activeCoaches =
        m?.activeCoaches ?? snapshot?.activeCoachesCount ?? 0;

    return AnalyticsChartCard(
      title: 'Appointment Outcomes',
      subtitle: 'Booking volume and completion status for selected dates',
      footer: const Text(
        'Counts cover appointments created and dated in the selected period. Outcomes reflect recorded status.',
        style: TextStyle(fontSize: 11, color: AppColors.inkSoft, height: 1.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total Booking Activity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                bookingsCount > 0 ? '$bookingsCount' : '—',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildOutcomeBar('Completed Appointments', completedCount,
              bookingsCount, AppColors.success),
          const SizedBox(height: 8),
          _buildOutcomeBar('Cancelled Appointments', cancelledCount,
              bookingsCount, AppColors.warning),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Active Coaching Team',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$activeCoaches active Coaches',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTab(
    BuildContext context,
    AdminReportingSnapshot? snapshot, {
    required bool wide,
    required List<String> topCoaches,
    required Map<String, double> revenueByCoach,
    required Map<String, int> sessionsByCoach,
    required double maxCoachRevenue,
  }) {
    final ops = snapshot?.operations;
    BusinessDashboardMetrics? m;
    if (snapshot?.unified != null && ops != null && snapshot!.isAvailable) {
      try {
        m = BusinessDashboardMetrics(snapshot, _workoutCubit?.state.report);
      } catch (_) {}
    }

    if (m != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Recorded Business Value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: const [
                Icon(Icons.auto_graph_rounded,
                    size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Recorded Business Value · Includes FYP Scenario Data',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Not settled cash, net income or payouts.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              AnalyticsMetricCard(
                width: wide ? 310 : null,
                highlighted: true,
                label: 'Recorded revenue',
                value: reportMoney(m.revenueMinor),
                icon: Icons.payments_outlined,
                contextNote: 'Includes non-cash scenario value',
              ),
              AnalyticsMetricCard(
                width: wide ? 310 : null,
                label: 'Membership Revenue',
                value: reportMoney(m.membershipMinor),
                icon: Icons.card_membership_outlined,
                contextNote: 'Subscription plans & recurring access',
              ),
              AnalyticsMetricCard(
                width: wide ? 310 : null,
                label: 'Coaching Revenue',
                value: reportMoney(m.coachingMinor),
                icon: Icons.sports_outlined,
                contextNote: 'Completed trainer appointments',
              ),
            ],
          ),
          const SizedBox(height: 20),
          wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: AnalyticsChartCard(
                        title: 'Monthly Recorded Revenue Trend',
                        subtitle:
                            'Monthly revenue trajectory across reporting dates',
                        child: SizedBox(
                          height: 240,
                          child: _buildMonthlySplineChart(m.monthly),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: AnalyticsChartCard(
                        title: 'Revenue Composition',
                        subtitle: 'Membership vs Coaching proportion',
                        child: _buildRevenueBreakdownDonut(m),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    AnalyticsChartCard(
                      title: 'Monthly Recorded Revenue Trend',
                      subtitle:
                          'Monthly revenue trajectory across reporting dates',
                      child: SizedBox(
                        height: 240,
                        child: _buildMonthlySplineChart(m.monthly),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnalyticsChartCard(
                      title: 'Revenue Composition',
                      subtitle: 'Membership vs Coaching proportion',
                      child: _buildRevenueBreakdownDonut(m),
                    ),
                  ],
                ),
          const SizedBox(height: 20),
          AnalyticsChartCard(
            title: 'Membership Plan Distribution',
            subtitle:
                'Active tier assignments and expired subscriptions overview',
            child: MembershipPlanDistribution(
              tiers: m.tiers,
              activeSubscriptions: m.activeSubscriptions,
              expiredSubscriptions: m.expiredSubscriptions,
            ),
          ),
          const SizedBox(height: 28),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 24),

          // Section 2: Recorded Collections (Cleared Sandbox Receipts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              children: const [
                Icon(Icons.receipt_long_outlined,
                    size: 16, color: AppColors.inkSoft),
                SizedBox(width: 8),
                Text(
                  'Recorded Collections · Cleared Sandbox Receipts',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Clearance date based · Review and refund cases excluded.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              AnalyticsMetricCard(
                width: wide ? 310 : null,
                label: 'Membership Collections',
                value: reportMoney(ops?.membershipMinor),
                icon: Icons.receipt_long_outlined,
                contextNote: 'Cleared membership payments',
              ),
              AnalyticsMetricCard(
                width: wide ? 310 : null,
                label: 'Coaching Collections',
                value: reportMoney(ops?.coachingMinor),
                icon: Icons.receipt_outlined,
                contextNote: 'Cleared coaching payments',
              ),
              AnalyticsMetricCard(
                width: wide ? 310 : null,
                label: 'Confirmed Sandbox Receipts',
                value: reportMoney(snapshot?.totalRevenue?.minorUnits ??
                    (ops != null
                        ? ops.membershipMinor + ops.coachingMinor
                        : null)),
                icon: Icons.verified_outlined,
                contextNote: 'Total cleared collections in period',
              ),
            ],
          ),
          const SizedBox(height: 20),
          wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: AnalyticsChartCard(
                        title: 'Membership Receipt Trend',
                        subtitle:
                            'Daily cleared collections across the reporting period',
                        child: OriginalReceiptTrend(
                            snapshot: snapshot!, membershipOnly: true),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: AnalyticsChartCard(
                        title: 'Collections & Clearance Breakdown',
                        subtitle: 'Review states and integrity details',
                        child: OriginalReceiptBreakdown(snapshot: snapshot),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    AnalyticsChartCard(
                      title: 'Membership Receipt Trend',
                      subtitle:
                          'Daily cleared collections across the reporting period',
                      child: OriginalReceiptTrend(
                          snapshot: snapshot!, membershipOnly: true),
                    ),
                    const SizedBox(height: 20),
                    AnalyticsChartCard(
                      title: 'Collections & Clearance Breakdown',
                      subtitle: 'Review states and integrity details',
                      child: OriginalReceiptBreakdown(snapshot: snapshot),
                    ),
                  ],
                ),
          const SizedBox(height: 28),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 24),

          // Section 3: Organization Census & Facility Availability
          wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildCensusCard(context, snapshot),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: _buildFacilityCard(context, snapshot),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildCensusCard(context, snapshot),
                    const SizedBox(height: 20),
                    _buildFacilityCard(context, snapshot),
                  ],
                ),
          const SizedBox(height: 24),
          RevenueSection(
            anchorKey: _revenueKey,
            live: widget.live,
            snapshot: snapshot,
          ),
        ],
      );
    }

    // Fallback when snapshot.unified == null
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            AnalyticsMetricCard(
              width: wide ? 310 : null,
              label: 'Membership Collections',
              value: reportMoney(ops?.membershipMinor),
              icon: Icons.card_membership_outlined,
              contextNote: 'Cleared membership payments',
            ),
            AnalyticsMetricCard(
              width: wide ? 310 : null,
              label: 'Coaching Collections',
              value: reportMoney(ops?.coachingMinor),
              icon: Icons.sports_outlined,
              contextNote: 'Cleared coaching payments',
            ),
            AnalyticsMetricCard(
              width: wide ? 310 : null,
              label: 'Confirmed Sandbox Receipts',
              value: reportMoney(snapshot?.totalRevenue?.minorUnits ??
                  (ops != null
                      ? ops.membershipMinor + ops.coachingMinor
                      : null)),
              icon: Icons.payments_outlined,
              contextNote: 'Total cleared collections',
            ),
          ],
        ),
        const SizedBox(height: 20),
        wide
            ? Row(
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
                      snapshot: snapshot,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: _branchColumn(context, snapshot: snapshot),
                  ),
                ],
              )
            : Column(
                children: [
                  _salesColumn(
                    context,
                    topCoaches,
                    revenueByCoach,
                    sessionsByCoach,
                    maxCoachRevenue,
                    snapshot: snapshot,
                  ),
                  const SizedBox(height: 20),
                  _branchColumn(context, snapshot: snapshot),
                ],
              ),
        const SizedBox(height: 20),
        RevenueSection(
          anchorKey: _revenueKey,
          live: widget.live,
          snapshot: snapshot,
        ),
      ],
    );
  }

  Widget _buildMonthlySplineChart(List<UnifiedRevenueMonth> data) {
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      margin: EdgeInsets.zero,
      primaryXAxis: const CategoryAxis(
        majorGridLines: MajorGridLines(width: 0),
        labelStyle: TextStyle(fontSize: 11, color: AppColors.inkSoft),
        axisLine: AxisLine(color: AppColors.hairline),
      ),
      primaryYAxis: const NumericAxis(
        title: AxisTitle(
          text: 'MYR',
          textStyle: TextStyle(fontSize: 11, color: AppColors.inkSoft),
        ),
        axisLine: AxisLine(width: 0),
        majorGridLines: MajorGridLines(color: AppColors.hairline, width: 1),
        labelStyle: TextStyle(fontSize: 11, color: AppColors.inkSoft),
      ),
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x · MYR point.y',
      ),
      series: <CartesianSeries<UnifiedRevenueMonth, String>>[
        SplineAreaSeries<UnifiedRevenueMonth, String>(
          animationDuration: 0,
          dataSource: data,
          xValueMapper: (r, _) => r.month,
          yValueMapper: (r, _) => r.minor / 100,
          name: 'Recorded revenue',
          color: AppColors.primary.withValues(alpha: 0.12),
          borderColor: AppColors.primary,
          borderWidth: 2.5,
          markerSettings: const MarkerSettings(
            isVisible: true,
            height: 6,
            width: 6,
            color: AppColors.primary,
            borderColor: Colors.white,
            borderWidth: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueBreakdownDonut(BusinessDashboardMetrics m) {
    final slices = [
      _RevenueSlice('Membership', m.membershipMinor, AppColors.primary),
      _RevenueSlice('Coaching', m.coachingMinor, AppColors.primarySoft),
    ];
    final total = m.membershipMinor + m.coachingMinor;

    return Column(
      children: [
        SizedBox(
          height: 165,
          child: SfCircularChart(
            margin: EdgeInsets.zero,
            series: <CircularSeries<_RevenueSlice, String>>[
              DoughnutSeries<_RevenueSlice, String>(
                animationDuration: 0,
                dataSource: slices,
                xValueMapper: (s, _) => s.label,
                yValueMapper: (s, _) => s.value,
                pointColorMapper: (s, _) => s.color,
                innerRadius: '72%',
                radius: '90%',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  reportMoney(s.value),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                if (total > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${(s.value / total * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCompactWorkoutTile(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.6),
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
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeBar(String label, int value, int total, Color color) {
    final ratio = total > 0 ? (value / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.ink),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value ${total > 0 ? '(${(ratio * 100).toStringAsFixed(0)}%)' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCensusCard(
      BuildContext context, AdminReportingSnapshot? snapshot) {
    return AnalyticsChartCard(
      title: 'Current Organization Census',
      subtitle: 'Organization-wide current accounts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AnalyticsMetricCard(
                  label: 'Active Members',
                  value: '${snapshot?.activeMembersCount ?? '—'}',
                  icon: Icons.people_outline_rounded,
                  contextNote: 'Registered accounts',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnalyticsMetricCard(
                  label: 'Active Coaches',
                  value: '${snapshot?.activeCoachesCount ?? '—'}',
                  icon: Icons.sports_outlined,
                  contextNote: 'Coaching staff',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Organization-wide current census. Account census is independent of date-scoped revenue and activity.',
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors.inkSoft,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityCard(
      BuildContext context, AdminReportingSnapshot? snapshot) {
    final branches = context.read<UserAccountRepository>().branches;
    return AnalyticsChartCard(
      title: 'Facility & Multi-Branch Availability',
      subtitle: 'Physical gym branch assignment and financial metrics',
      child: branches.isEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: const Icon(
                      Icons.location_off_outlined,
                      size: 22,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Branch Metrics Unavailable',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'All recorded metrics belong to primary organization level. Branch-specific breakdown is not configured for this environment.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkSoft,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: branches.take(2).map((b) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        b.isActive ? 'Active' : 'Suspended',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: b.isActive
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
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

class _RevenueSlice {
  const _RevenueSlice(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}
