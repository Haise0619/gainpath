import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession;

import '../../application/admin_reporting_cubit.dart';
import 'admin_reporting_feedback.dart';
import '../../application/admin_reporting_gateway.dart';

/// AD-M12.1 — View Admin Dashboard.
class AdminDashboardScreen extends StatefulWidget {
  /// Lets the shell jump straight to the Refunds sidebar page (and a
  /// specific claim within it) instead of pushing a screen — this
  /// dashboard has no way to change the shell's own selection itself.
  final VoidCallback? onOpenRefunds;
  final bool live;
  final AuthSession? liveSession;

  const AdminDashboardScreen({
    super.key,
    this.onOpenRefunds,
    this.live = false,
    this.liveSession,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _ranges = ['Today', 'This week', 'This month'];
  String _range = 'Today';
  AdminReportingCubit? _reportingCubit;

  static const _revenueTrend = [
    18200,
    19400,
    21000,
    20600,
    22800,
    23400,
    24180
  ];

  static const _activity = [
    [
      'Hafiz Aziz uploaded a certification document',
      '2h ago',
      Icons.workspace_premium_rounded,
      AppColors.warning
    ],
    [
      'Farid Zainal requested a refund on TXN-2041',
      '3h ago',
      Icons.receipt_long_rounded,
      AppColors.danger
    ],
    [
      'New booking — Priya Menon with Daniel Wong',
      '5h ago',
      Icons.event_available_rounded,
      AppColors.primary
    ],
    [
      'Voucher GP-4K7M-92XA redeemed at the desk',
      '6h ago',
      Icons.card_giftcard_rounded,
      AppColors.success
    ],
    [
      '12 members completed a tracked workout',
      '8h ago',
      Icons.fitness_center_rounded,
      AppColors.primary
    ],
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reportingCubit == null && widget.live) {
      try {
        final gateway = context.read<AdminReportingGateway>();
        _reportingCubit = AdminReportingCubit(
            gateway: gateway, initialQuery: _rangeQuery(_range))
          ..load();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _reportingCubit?.close();
    super.dispose();
  }

  AdminReportQuery _rangeQuery(String range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = range == 'Today'
        ? today
        : range == 'This week'
            ? today.subtract(Duration(days: now.weekday - 1))
            : DateTime(now.year, now.month, 1);
    return AdminReportQuery(range: DateTimeRange(start: start, end: now));
  }

  void _onRangeSelected(String value) {
    setState(() => _range = value);
    _reportingCubit?.load(_rangeQuery(value));
  }

  List<List<String>> _getKpis(AdminReportingSnapshot? snapshot) {
    if (!widget.live) {
      return context.read<AnalyticsRepository>().adminStats;
    }
    final totalRev = snapshot?.totalRevenue;
    final revenue = totalRev != null
        ? '${totalRev.currency} ${(totalRev.minorUnits / 100).toStringAsFixed(0)}'
        : 'RM —';
    final members = snapshot?.activeMembersCount != null
        ? '${snapshot!.activeMembersCount}'
        : '—';
    final bookings = snapshot?.totalBookingsCount != null
        ? '${snapshot!.totalBookingsCount}'
        : '—';
    final posture = snapshot?.avgPostureAccuracy != null
        ? '${(snapshot!.avgPostureAccuracy! * 100).round()}%'
        : '—';
    return [
      ['Total revenue', revenue, '—'],
      ['Active members', members, '—'],
      ['Bookings in range', bookings, '—'],
      ['Avg accuracy', posture, '—'],
    ];
  }

  List<int> _getHourlySessions(AdminReportingSnapshot? snapshot) {
    if (!widget.live) return context.read<AnalyticsRepository>().usageByHour;
    final series = snapshot?.hourlySessions;
    if (series == null || series.any((p) => p.value is! int || p.value < 0)) {
      return const [];
    }
    return series.map((point) => point.value.toInt()).toList();
  }

  List<int> _getRevenueTrend(AdminReportingSnapshot? snapshot) {
    if (!widget.live) {
      return _revenueTrend;
    }
    if (snapshot?.revenueTrend != null && snapshot!.revenueTrend!.length >= 2) {
      return snapshot.revenueTrend!.map((p) => p.value.toInt()).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    if (_reportingCubit != null) {
      return BlocBuilder<AdminReportingCubit, AdminReportingState>(
        bloc: _reportingCubit,
        builder: (context, reportingState) => _buildContent(
            context,
            reportingState.snapshot?.isAvailable == true
                ? reportingState.snapshot
                : null,
            reportingState: reportingState),
      );
    }
    return _buildContent(context, null);
  }

  Widget _buildContent(BuildContext context, AdminReportingSnapshot? snapshot,
      {AdminReportingState? reportingState}) {
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.live
                                ? (widget.liveSession?.organizationId
                                            .isNotEmpty ==
                                        true
                                    ? 'GainPath — ${widget.liveSession!.organizationId}'
                                    : 'GainPath Console')
                                : 'GainPath, Kulim',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.live
                                ? (widget.liveSession != null
                                    ? 'Connected as ${widget.liveSession!.displayName ?? widget.liveSession!.email}'
                                    : 'Live platform administration.')
                                : 'Here is how the platform is doing.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      offset: const Offset(0, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      onSelected: _onRangeSelected,
                      itemBuilder: (context) => _ranges
                          .map((r) => PopupMenuItem(value: r, child: Text(r)))
                          .toList(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 15, color: AppColors.inkSoft),
                            const SizedBox(width: 8),
                            Text(_range,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            const Icon(Icons.expand_more_rounded,
                                size: 17, color: AppColors.inkSoft),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: _getKpis(snapshot)
                      .map((s) =>
                          _KpiCard(label: s[0], value: s[1], delta: s[2]))
                      .toList(),
                ),
                const SizedBox(height: 24),
                wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 2, child: _leftColumn(context, snapshot)),
                          const SizedBox(width: 20),
                          Expanded(flex: 1, child: _rightColumn(context)),
                        ],
                      )
                    : Column(
                        children: [
                          _leftColumn(context, snapshot),
                          const SizedBox(height: 20),
                          _rightColumn(context),
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _leftColumn(BuildContext context, AdminReportingSnapshot? snapshot) {
    final hourlySessions = _getHourlySessions(snapshot);
    final trend = _getRevenueTrend(snapshot);
    final totalRev = snapshot?.totalRevenue;
    final displayRevenue = widget.live
        ? (totalRev != null
            ? '${totalRev.currency} ${(totalRev.minorUnits / 100).toStringAsFixed(0)}'
            : 'RM —')
        : 'RM ${_revenueTrend.last}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Sessions today, by hour'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(alignment: Alignment.center, children: [
                BarChart(hourlySessions, height: 150),
                if (widget.live && hourlySessions.isEmpty) const Text('—')
              ]),
              const SizedBox(height: 10),
              Text(
                widget.live
                    ? (hourlySessions.isNotEmpty
                        ? 'Tracked session volume for this reporting window.'
                        : 'Hourly session metrics are unavailable in this environment.')
                    : 'Peak demand sits between 5pm and 8pm on weekdays.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Eyebrow('Revenue trend'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    displayRevenue,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _DeltaTag(
                          delta: widget.live ? '—' : '+5% vs last month',
                          positive: !widget.live,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Stack(alignment: Alignment.center, children: [
                TrendChart(trend),
                if (widget.live && trend.isEmpty) const Text('—')
              ]),
              if (widget.live) ...[
                const SizedBox(height: 10),
                Text(
                  trend.isNotEmpty
                      ? 'Aggregate revenue for this reporting window.'
                      : 'Revenue tracking is unavailable in this environment.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Eyebrow('Recent activity'),
        Panel(
          padding: EdgeInsets.zero,
          child: (widget.live &&
                  (snapshot?.recentActivity == null ||
                      snapshot!.recentActivity!.isEmpty))
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  child: Center(
                    child: Text(
                      'No recent activity recorded for this period.',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(
                      widget.live && snapshot?.recentActivity != null
                          ? snapshot!.recentActivity!.length
                          : _activity.length, (i) {
                    final item = widget.live && snapshot?.recentActivity != null
                        ? snapshot!.recentActivity![i]
                        : null;
                    final title = item?.title ?? _activity[i][0] as String;
                    final subtitle =
                        item?.subtitle ?? _activity[i][1] as String;
                    final icon = item?.icon ?? _activity[i][2] as IconData;
                    final color = item?.color ?? _activity[i][3] as Color;
                    return Column(
                      children: [
                        if (i > 0) const Divider(height: 1, indent: 62),
                        ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(icon, size: 18, color: color),
                          ),
                          title: Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  )),
                          trailing: Text(subtitle,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.inkSoft)),
                        ),
                      ],
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _rightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Needs attention'),
        Panel(
          padding: EdgeInsets.zero,
          child: widget.live
              ? Column(
                  children: [
                    _alert(
                      context,
                      Icons.workspace_premium_rounded,
                      AppColors.warning,
                      'Coach verification',
                      'Review pending coach applications and certificates',
                      onTap: () =>
                          showToast(context, 'Navigate to Coaches in sidebar.'),
                    ),
                    const Divider(height: 1, indent: 62),
                    _alert(
                      context,
                      Icons.receipt_long_rounded,
                      AppColors.inkSoft,
                      'Refund requests',
                      'Dispute resolution is unavailable in this release',
                      onTap: widget.onOpenRefunds,
                    ),
                    const Divider(height: 1, indent: 62),
                    _alert(
                      context,
                      Icons.warning_amber_rounded,
                      AppColors.inkSoft,
                      'Risk monitoring',
                      'Posture score risk detection is unavailable in this release',
                    ),
                  ],
                )
              : Column(
                  children: [
                    _alert(
                        context,
                        Icons.workspace_premium_rounded,
                        AppColors.warning,
                        '1 coach awaiting verification',
                        'Hafiz Aziz uploaded a certificate 2 days ago'),
                    const Divider(height: 1, indent: 62),
                    _alert(
                        context,
                        Icons.receipt_long_rounded,
                        AppColors.danger,
                        '2 refund requests pending',
                        'Oldest submitted 3 days ago',
                        onTap: widget.onOpenRefunds),
                    const Divider(height: 1, indent: 62),
                    _alert(
                        context,
                        Icons.warning_amber_rounded,
                        AppColors.warning,
                        '3 members flagged at risk',
                        'Low form scores across recent sessions'),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        const Eyebrow('Quick actions'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _action(
                context,
                Icons.qr_code_scanner_rounded,
                'Process a voucher',
                widget.live
                    ? 'Voucher redemption is unavailable'
                    : 'Redeem a member reward at the desk',
                () {
                  if (widget.live) {
                    showToast(context,
                        'Voucher processing is unavailable in this environment.');
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProcessVoucherScreen()));
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
              const SizedBox(height: 12),
              Text(
                widget.live
                    ? 'Connected Organization'
                    : '9 coaches, 284 members',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.live
                    ? (widget.liveSession != null
                        ? 'Connected as ${widget.liveSession!.displayName ?? widget.liveSession!.email} (${widget.liveSession!.organizationId}). Live console governance active.'
                        : 'Facility is operating under connected organization governance.')
                    : 'Facility is trending 12% above last month\'s active member count.',
                style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _alert(BuildContext context, IconData icon, Color color, String title,
      String subtitle,
      {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color == AppColors.danger
              ? AppColors.dangerTint
              : AppColors.accentTint,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap ?? () => showToast(context, 'Opening item.'),
    );
  }

  Widget _action(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  const _KpiCard(
      {required this.label, required this.value, required this.delta});

  bool get _positive => delta.trim().startsWith('+');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 258,
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 8),
            _DeltaTag(delta: delta, positive: _positive),
          ],
        ),
      ),
    );
  }
}

class _DeltaTag extends StatelessWidget {
  final String delta;
  final bool positive;
  const _DeltaTag({required this.delta, required this.positive});

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.success : AppColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: positive ? AppColors.successTint : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (positive)
            const Icon(Icons.arrow_upward_rounded,
                size: 12, color: AppColors.success),
          if (positive) const SizedBox(width: 3),
          Flexible(
            child: Text(delta,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

/// AD-M11.5 — Process Reward Redemption Voucher.
class ProcessVoucherScreen extends StatefulWidget {
  const ProcessVoucherScreen({super.key});

  @override
  State<ProcessVoucherScreen> createState() => _ProcessVoucherScreenState();
}

class _ProcessVoucherScreenState extends State<ProcessVoucherScreen> {
  final _code = TextEditingController();
  bool _found = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Process voucher')),
      body: PageBody(
        children: [
          Text('Enter or scan the code the member is showing you.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Voucher code',
              hintText: 'GP-XXXX-XXXX',
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: () {
                  _code.text = 'GP-4K7M-92XA';
                  setState(() => _found = true);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              if (_code.text.trim().isEmpty) {
                showToast(context, 'Enter a code first.');
                return;
              }
              setState(() => _found = true);
            },
            child: const Text('Look up code'),
          ),
          if (_found) ...[
            const SizedBox(height: 24),
            Panel(
              background: AppColors.primaryTint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success),
                      const SizedBox(width: 10),
                      Text('Valid voucher',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const DetailRow('Member', 'ZhengYang'),
                  const Divider(height: 18),
                  const DetailRow('Reward', 'Protein Shake Voucher'),
                  const Divider(height: 18),
                  const DetailRow('Points used', '400'),
                  const Divider(height: 18),
                  const DetailRow('Issued', '2 days ago'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                showToast(context, 'Voucher redeemed. Hand over the reward.');
              },
              child: const Text('Confirm and hand over reward'),
            ),
          ],
        ],
      ),
    );
  }
}
