import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/admin_reporting_cubit.dart';
import '../../application/admin_workout_reporting.dart';
import '../../application/business_dashboard_metrics.dart';
import '../../application/unified_admin_summary.dart';
import 'admin_reporting_feedback.dart';

class BusinessDashboard extends StatefulWidget {
  const BusinessDashboard(
      {super.key,
      required this.state,
      required this.range,
      required this.ranges,
      required this.onRange,
      required this.onRefresh});
  final AdminReportingState state;
  final String range;
  final List<String> ranges;
  final ValueChanged<String> onRange;
  final VoidCallback onRefresh;
  @override
  State<BusinessDashboard> createState() => _BusinessDashboardState();
}

class _BusinessDashboardState extends State<BusinessDashboard> {
  AdminWorkoutReport? _workouts;
  AdminReportQuery? _query;
  int _generation = 0;
  bool _loading = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant BusinessDashboard old) {
    super.didUpdateWidget(old);
    if (old.state.query != widget.state.query) {
      _load(force: true);
    }
  }

  void _refresh() {
    _load(force: true);
    setState(() {});
    widget.onRefresh();
  }

  Future<void> _load({bool force = false}) async {
    final q = widget.state.query;
    if (!force && q == _query) return;
    _query = q;
    _workouts = null;
    _error = null;
    final generation = ++_generation;
    final gateway = context.read<AdminReportingGateway>();
    if (gateway is! AdminWorkoutReportingGateway) return;
    _loading = true;
    try {
      final r = await (gateway as AdminWorkoutReportingGateway).loadWorkouts(q);
      if (!mounted || generation != _generation) return;
      if (r.query != q ||
          gateway is AdminReportingSessionGuard &&
              !(gateway as AdminReportingSessionGuard).canRetainSnapshot) {
        throw StateError('Session changed');
      }
      setState(() {
        _workouts = r;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _workouts = null;
          _loading = false;
          _error = 'Workout activity is unavailable. Refresh to try again.';
        });
      }
    }
  }

  String money(int? value) =>
      value == null ? '—' : 'MYR ${(value / 100).toStringAsFixed(2)}';
  @override
  Widget build(BuildContext context) {
    final s = widget.state.snapshot;
    BusinessDashboardMetrics? m;
    final gateway = context.read<AdminReportingGateway>();
    final valid = gateway is! AdminReportingSessionGuard ||
        (gateway as AdminReportingSessionGuard).canRetainSnapshot;
    if (valid && s?.unified != null && s?.operations != null) {
      try {
        m = BusinessDashboardMetrics(s!, _workouts);
      } on FormatException {
        m = null;
      }
    }
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 940, mid = c.maxWidth >= 560, metric = m;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 16,
                    spacing: 24,
                    children: [
                      SizedBox(
                          width: wide ? c.maxWidth - 360 : c.maxWidth,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dashboard Overview',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text(
                                    "Monitor your fitness center's performance and activity.",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: AppColors.inkSoft))
                              ])),
                      PopupMenuButton<String>(
                          tooltip: 'Date range',
                          initialValue: widget.range,
                          onSelected: widget.onRange,
                          itemBuilder: (_) => widget.ranges
                              .map((r) =>
                                  PopupMenuItem(value: r, child: Text(r)))
                              .toList(),
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              decoration: _decoration(),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_outlined,
                                        size: 18, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Text(widget.range),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.expand_more, size: 18)
                                  ]))),
                      IconButton(
                          tooltip: 'Refresh dashboard',
                          onPressed: widget.state.isLoading ? null : _refresh,
                          icon: const Icon(Icons.refresh_rounded,
                              color: AppColors.primary)),
                    ]),
                const SizedBox(height: 24),
                AdminReportingFeedback(state: widget.state, onRetry: _refresh),
                if (valid && s != null && m == null && !widget.state.isLoading)
                  const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                          'Overview could not be validated. Refresh to try again.')),
                Wrap(spacing: 16, runSpacing: 16, children: [
                  _kpi(
                      'Active Members',
                      metric?.activeMembers,
                      Icons.people_outline,
                      'Current membership',
                      c.maxWidth,
                      wide,
                      mid),
                  _kpi(
                      'Active Coaches',
                      metric?.activeCoaches,
                      Icons.sports_outlined,
                      'Current coaching team',
                      c.maxWidth,
                      wide,
                      mid),
                  _kpi(
                      'Workout Sessions',
                      valid ? _workouts?.totals.sessions : null,
                      Icons.fitness_center,
                      'In selected period',
                      c.maxWidth,
                      wide,
                      mid),
                  _kpi(
                      'Bookings',
                      metric?.bookings,
                      Icons.event_available_outlined,
                      'Recorded appointment activity',
                      c.maxWidth,
                      wide,
                      mid),
                ]),
                const SizedBox(height: 24),
                _card('Revenue Overview', 'Membership and coaching performance',
                    trailing: IconButton(
                        tooltip: 'Export business overview',
                        onPressed: metric == null
                            ? null
                            : () => downloadCsv(
                                'gainpath-business-overview.csv', metric.csv()),
                        icon: const Icon(Icons.file_download_outlined)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 40, runSpacing: 18, children: [
                            _amount(
                                'Recorded revenue', money(metric?.revenueMinor),
                                large: true),
                            _amount('Membership Revenue',
                                money(metric?.membershipMinor)),
                            _amount('Coaching Revenue',
                                money(metric?.coachingMinor))
                          ]),
                          const SizedBox(height: 24),
                          if (metric != null)
                            wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                        Expanded(
                                            flex: 7,
                                            child: _revenueChart(metric)),
                                        const SizedBox(width: 32),
                                        Expanded(
                                            flex: 3, child: _breakdown(metric))
                                      ])
                                : Column(children: [
                                    _revenueChart(metric),
                                    _breakdown(metric)
                                  ])
                          else
                            const SizedBox(
                                height: 230,
                                child: Center(
                                    child:
                                        Text('Revenue data is unavailable.'))),
                          const SizedBox(height: 14),
                          const Text(BusinessDashboardMetrics.revenueDefinition,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                  height: 1.5)),
                        ])),
                const SizedBox(height: 24),
                Wrap(spacing: 24, runSpacing: 24, children: [
                  SizedBox(
                      width: wide ? (c.maxWidth - 24) / 2 : c.maxWidth,
                      child: _membership(metric)),
                  SizedBox(
                      width: wide ? (c.maxWidth - 24) / 2 : c.maxWidth,
                      child: _booking(metric)),
                ]),
                const SizedBox(height: 24),
                _workout(valid ? _workouts : null),
                const SizedBox(height: 24),
                _card('Membership Trends',
                    'Member registrations over the selected period',
                    child: metric == null || metric.summary.memberTrend.isEmpty
                        ? const Text('No registration activity in this period.')
                        : SizedBox(
                            height: 180,
                            child: SfCartesianChart(
                                primaryXAxis: const CategoryAxis(),
                                primaryYAxis:
                                    const NumericAxis(decimalPlaces: 0),
                                series: <CartesianSeries<UnifiedMemberDay,
                                    String>>[
                                  ColumnSeries<UnifiedMemberDay, String>(
                                      animationDuration: 0,
                                      dataSource: metric.summary.memberTrend,
                                      name: 'Member registrations',
                                      xValueMapper: (r, _) => r.date,
                                      yValueMapper: (r, _) =>
                                          r.existing + r.fyp,
                                      color: AppColors.primary)
                                ]))),
                const SizedBox(height: 20),
                Text(
                    'Current account and subscription counts are independent of the selected activity dates. Registration records do not establish attendance.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.inkSoft)),
              ]);
        }));
  }

  Widget _kpi(String label, int? count, IconData icon, String note,
          double width, bool wide, bool mid) =>
      Container(
          width: wide
              ? (width - 48) / 4
              : mid
                  ? (width - 16) / 2
                  : width,
          padding: const EdgeInsets.all(22),
          decoration: _decoration(),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600))),
              Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: AppColors.primary, size: 21))
            ]),
            const SizedBox(height: 16),
            Text(count?.toString() ?? '—',
                style: const TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w700, height: 1.1)),
            const SizedBox(height: 10),
            Text(note,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft))
          ]));
  Widget _amount(String title, String value, {bool large = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: large ? 30 : 22,
                fontWeight: FontWeight.w700,
                color: large ? AppColors.primary : AppColors.ink))
      ]);
  Widget _revenueChart(BusinessDashboardMetrics m) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Monthly Revenue Trend',
            style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(
            height: 245,
            child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                    majorGridLines: MajorGridLines(width: 0)),
                primaryYAxis: const NumericAxis(
                    title: AxisTitle(text: 'MYR'),
                    axisLine: AxisLine(width: 0)),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<UnifiedRevenueMonth, String>>[
                  SplineAreaSeries<UnifiedRevenueMonth, String>(
                      animationDuration: 0,
                      dataSource: m.monthly,
                      xValueMapper: (r, _) => r.month,
                      yValueMapper: (r, _) => r.minor / 100,
                      name: 'Recorded revenue',
                      color: AppColors.primary.withValues(alpha: .12),
                      borderColor: AppColors.primary,
                      borderWidth: 3,
                      markerSettings: const MarkerSettings(
                          isVisible: true, height: 5, width: 5))
                ]))
      ]);
  Widget _breakdown(BusinessDashboardMetrics m) {
    final rows = [
      _Slice('Membership', m.membershipMinor, AppColors.primary),
      _Slice(
          'Coaching', m.coachingMinor, AppColors.primary.withValues(alpha: .4))
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Revenue Breakdown',
          style: TextStyle(fontWeight: FontWeight.w600)),
      SizedBox(
          height: 165,
          child: SfCircularChart(
              margin: EdgeInsets.zero,
              series: <CircularSeries<_Slice, String>>[
                DoughnutSeries<_Slice, String>(
                    animationDuration: 0,
                    dataSource: rows,
                    xValueMapper: (r, _) => r.label,
                    yValueMapper: (r, _) => r.value,
                    pointColorMapper: (r, _) => r.color,
                    innerRadius: '78%',
                    radius: '90%')
              ])),
      for (final r in rows)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(Icons.circle, size: 9, color: r.color),
              const SizedBox(width: 8),
              Expanded(child: Text(r.label)),
              Text(money(r.value),
                  style: const TextStyle(fontWeight: FontWeight.w600))
            ]))
    ]);
  }

  Widget _membership(BusinessDashboardMetrics? m) => _card(
      'Membership Overview', 'Current subscriptions and plan distribution',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _amount(
            'Active Subscriptions', m?.activeSubscriptions?.toString() ?? '—'),
        const SizedBox(height: 20),
        const Text('Membership Distribution',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        if (m?.tiers != null)
          for (final e in m!.tiers!.entries)
            if (e.key != 'unknown' || e.value > 0)
              _bar(e.key[0].toUpperCase() + e.key.substring(1), e.value,
                  m.tiers!.values.fold<int>(0, (n, v) => n + v))
            else
              const SizedBox.shrink(),
        if (m?.tiers == null) const Text('Plan distribution is unavailable.'),
        const SizedBox(height: 14),
        Text(
            '${m?.expiredSubscriptions ?? '—'} expired · Active counts exclude expired and unknown plans. Distribution includes current recorded plan assignments.',
            style: const TextStyle(
                fontSize: 12, color: AppColors.inkSoft, height: 1.5)),
        const SizedBox(height: 16),
        Text(
            '${m?.publishedPrograms ?? '—'} published Programs · ${m?.publishedRoutines ?? '—'} Routine destinations',
            style: const TextStyle(color: AppColors.inkSoft))
      ]));
  Widget _booking(BusinessDashboardMetrics? m) => _card(
      'Booking Overview', 'Appointment outcomes and coaching activity',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _amount('Total Booking Activity', m?.bookings.toString() ?? '—'),
        const SizedBox(height: 18),
        _bar('Completed Appointments', m?.completed, m?.bookings),
        _bar('Cancelled Appointments', m?.cancelled, m?.bookings),
        const SizedBox(height: 18),
        Text('${m?.activeCoaches ?? '—'} active Coaches',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
            'Counts cover bookings created and appointment records dated in the selected period. Outcomes reflect current recorded status; availability and capacity are evaluated separately.',
            style:
                TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.5))
      ]));
  Widget _workout(AdminWorkoutReport? r) => _card(
      'Workout Overview', 'Session activity, exercises and performance',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) Text(_error!),
        Wrap(spacing: 32, runSpacing: 14, children: [
          _amount('Recorded sessions', r?.totals.sessions.toString() ?? '—'),
          _amount('Full repetitions', r?.totals.fullReps.toString() ?? '—'),
          _amount(
              'Partial repetitions', r?.totals.partialReps.toString() ?? '—')
        ]),
        const SizedBox(height: 20),
        const Text('Activity Trends',
            style: TextStyle(fontWeight: FontWeight.w600)),
        if (r != null && r.daily.isNotEmpty)
          SizedBox(
              height: 215,
              child: SfCartesianChart(
                  primaryXAxis: const CategoryAxis(),
                  primaryYAxis: const NumericAxis(decimalPlaces: 0),
                  series: <CartesianSeries<WorkoutReportDay, String>>[
                    ColumnSeries<WorkoutReportDay, String>(
                        animationDuration: 0,
                        dataSource: r.daily,
                        xValueMapper: (d, _) => d.date,
                        yValueMapper: (d, _) => d.sessions,
                        color: AppColors.primary,
                        name: 'Workout sessions')
                  ]))
        else
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No activity dates available.')),
        const SizedBox(height: 12),
        const Text('Exercise Statistics',
            style: TextStyle(fontWeight: FontWeight.w600)),
        if (r != null)
          for (final e in r.exercises.take(6))
            _bar(e.name, e.sessions, r.totals.sessions),
        const SizedBox(height: 18),
        const Text('Performance Metrics',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (r != null && r.forms.isNotEmpty)
          for (final f in r.forms)
            Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${r.exercises.where((e) => e.exerciseId == f.exerciseId).firstOrNull?.name ?? f.exerciseId} · ${f.average.toStringAsFixed(1)}% Estimated Form Score · ${f.scoredSessions} scored sessions'),
                      Text(f.label,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.inkSoft))
                    ]))
        else
          const Text('No compatible form scores in this period.'),
        const SizedBox(height: 10),
        const Text(
            'Recorded observations support activity review. Form scores are compared only within compatible exercise, scoring version, view and mode groups; they are not a clinical assessment.',
            style:
                TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.5))
      ]));
  Widget _bar(String label, int? value, int? total) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text(value?.toString() ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w600))
        ]),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
                value: value == null || total == null || total == 0
                    ? 0
                    : (value / total).clamp(0, 1),
                minHeight: 6,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withValues(alpha: .08)))
      ]));
  Widget _card(String title, String subtitle,
          {required Widget child, Widget? trailing}) =>
      Container(
          padding: const EdgeInsets.all(24),
          decoration: _decoration(),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.inkSoft))
                  ])),
              if (trailing != null) trailing
            ]),
            const SizedBox(height: 22),
            child
          ]));
  BoxDecoration _decoration() => BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: .025),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ]);
}

class _Slice {
  const _Slice(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}
