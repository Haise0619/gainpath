import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/admin_check_in_reporting.dart';
import 'admin_engagement_widgets.dart';

class AdminCheckInAnalytics extends StatefulWidget {
  const AdminCheckInAnalytics(
      {super.key,
      required this.query,
      required this.anchorKey,
      this.refreshToken = 0,
      this.redemptionsOnly = false});
  final AdminReportQuery query;
  final GlobalKey anchorKey;
  final int refreshToken;
  final bool redemptionsOnly;
  @override
  State<AdminCheckInAnalytics> createState() => _AdminCheckInAnalyticsState();
}

class _AdminCheckInAnalyticsState extends State<AdminCheckInAnalytics> {
  AdminCheckInReportingCubit? _cubit;
  bool _weekly = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gateway = context.read<AdminReportingGateway>();
    if (gateway is! AdminCheckInReportingGateway) {
      _cubit?.close();
      _cubit = null;
      return;
    }
    if (!identical(_cubit?.gateway, gateway)) {
      _cubit?.close();
      _cubit = AdminCheckInReportingCubit(
          gateway: gateway as AdminCheckInReportingGateway, query: widget.query)
        ..load();
    }
  }

  @override
  void didUpdateWidget(AdminCheckInAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query ||
        widget.refreshToken != oldWidget.refreshToken) {
      _cubit?.load(widget.query);
    }
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cubit == null) {
      return _section(
          null,
          const Text(
              'Check-in analytics is unavailable for this reporting source.'));
    }
    return BlocBuilder<AdminCheckInReportingCubit, AdminCheckInReportingState>(
        bloc: _cubit,
        builder: (context, state) {
          final report = state.report;
          return _section(
              report,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                        tooltip: widget.redemptionsOnly
                            ? 'Refresh redemption analytics'
                            : 'Refresh check-in analytics',
                        onPressed: state.loading ? null : () => _cubit!.load(),
                        icon: const Icon(Icons.refresh_rounded))),
                if (state.loading && report == null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text(widget.redemptionsOnly
                                ? 'Loading redemption analytics...'
                                : 'Loading check-in analytics...'))
                      ]))
                else if (report == null) ...[
                  Text(state.error ?? 'Check-in analytics is unavailable.'),
                  TextButton.icon(
                      onPressed: () => _cubit!.load(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(widget.redemptionsOnly
                          ? 'Retry redemption analytics'
                          : 'Retry check-in analytics')),
                ] else ...[
                  if (state.loading) const LinearProgressIndicator(),
                  if (state.error != null) Text(state.error!),
                  _data(context, report),
                ],
              ]));
        });
  }

  Widget _section(AdminCheckInReport? report, Widget child) => ReportSection(
      anchorKey: widget.anchorKey,
      title: widget.redemptionsOnly
          ? 'Reward Redemptions'
          : 'Gamification Engagement',
      subtitle: widget.redemptionsOnly
          ? 'Voucher issue, collection and expiry - server records'
          : 'Check-ins, recorded mini-games and confirmed Reward Points',
      live: true,
      tagLabel: report == null ||
              (widget.redemptionsOnly && report.extensions == null)
          ? 'Unavailable'
          : widget.redemptionsOnly
              ? 'Voucher records'
              : 'Confirmed records',
      exportFilename: widget.redemptionsOnly
          ? 'gainpath-reward-redemptions.csv'
          : 'gainpath-gamification-engagement.csv',
      exportEnabled: report != null &&
          (!widget.redemptionsOnly || report.extensions != null),
      exportRows: widget.redemptionsOnly
          ? report?.extensions?.redemptionCsv
          : report?.toCsv,
      child: child);
  Widget _data(BuildContext context, AdminCheckInReport r) {
    if (widget.redemptionsOnly) {
      return AdminRedemptionData(extension: r.extensions);
    }
    final text = Theme.of(context).textTheme,
        periods = _weekly ? r.weekly : r.daily;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(
            width: 210, child: StatTile('${r.claims}', 'Confirmed check-ins')),
        SizedBox(
            width: 210,
            child: StatTile('${r.claimingMembers}', 'Unique claiming Members')),
        SizedBox(
            width: 210,
            child: StatTile('${r.pointsAwarded}', 'Check-in Reward Points',
                valueColor: AppColors.primary)),
      ]),
      const SizedBox(height: 12),
      Text(
          'Check-in metrics cover current active Members. App engagement only; gym attendance and wallet balances are excluded.',
          style: text.bodySmall),
      const SizedBox(height: 14),
      if (r.claims == 0)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No confirmed check-ins in this date range.')),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Check-in engagement trend', style: text.titleMedium),
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: const Text('Daily'),
              selected: !_weekly,
              onSelected: (_) => setState(() => _weekly = false)),
          ChoiceChip(
              label: const Text('Weekly'),
              selected: _weekly,
              onSelected: (_) => setState(() => _weekly = true))
        ]),
        if (periods.isNotEmpty)
          SizedBox(
              height: 250,
              child: SfCartesianChart(
                  plotAreaBorderWidth: 0,
                  primaryXAxis: const CategoryAxis(
                      majorGridLines: MajorGridLines(width: 0),
                      labelIntersectAction: AxisLabelIntersectAction.rotate45),
                  primaryYAxis: const NumericAxis(minimum: 0, decimalPlaces: 0),
                  legend: const Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                      overflowMode: LegendItemOverflowMode.wrap),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries<CheckInReportPeriod, String>>[
                    ColumnSeries<CheckInReportPeriod, String>(
                        name: 'Claims',
                        dataSource: periods,
                        xValueMapper: (d, _) => d.date,
                        yValueMapper: (d, _) => d.claims,
                        color: AppColors.primary),
                    ColumnSeries<CheckInReportPeriod, String>(
                        name: 'Unique claimants',
                        dataSource: periods,
                        xValueMapper: (d, _) => d.date,
                        yValueMapper: (d, _) => d.claimingMembers,
                        color: AppColors.accent),
                  ]))
        else
          const NoFilteredData(message: 'No confirmed claim dates to chart.'),
        Text(
            _weekly
                ? 'Weekly claimants are distinct within each Monday-based week. Boundary weeks include only selected dates.'
                : 'One confirmed claim per Member per Malaysia day. Dates without receipts have no confirmed claims.',
            style: text.bodySmall),
        if (periods.isNotEmpty)
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('View trend data'),
              children: [
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Claims'), numeric: true),
                      DataColumn(label: Text('Members'), numeric: true),
                      DataColumn(label: Text('Points'), numeric: true)
                    ], rows: [
                      for (final d in periods)
                        DataRow(cells: [
                          DataCell(Text(d.date)),
                          DataCell(Text('${d.claims}')),
                          DataCell(Text('${d.claimingMembers}')),
                          DataCell(Text('${d.pointsAwarded}'))
                        ])
                    ])),
              ]),
      ])),
      const SizedBox(height: 18),
      AdminGameEngagementData(extension: r.extensions),
      const SizedBox(height: 18),
      Text(
          'Current as of ${r.asOfDate} · streaks ignore the selected date range',
          style: text.titleSmall),
      const SizedBox(height: 6),
      Text(
          'All ${r.coverage['activeMembers']} current canonical active Members are included, including those who never claimed. A last claim yesterday keeps the current streak alive until today ends. Longest streak covers all available claim history.',
          style: text.bodySmall),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, c) {
        final children = [
          _streakPanel(context, 'Current streak', r.currentStreaks,
              r.coverage['activeMembers']!),
          _streakPanel(context, 'Longest streak', r.longestStreaks,
              r.coverage['activeMembers']!)
        ];
        return c.maxWidth >= 760
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: children[0]),
                const SizedBox(width: 14),
                Expanded(child: children[1])
              ])
            : Column(children: [
                children[0],
                const SizedBox(height: 14),
                children[1]
              ]);
      }),
      const SizedBox(height: 12),
      Text(
          '${r.coverage['profiles']} check-in profiles · ${r.coverage['claimsScanned']} all-time receipts reconciled. Current active Member cohort; not a historical population census. Source scan ${r.scanStartedAt.toUtc().toIso8601String()} to ${r.capturedAt.toUtc().toIso8601String()}; bounded reads, not one atomic organization snapshot.',
          style: text.bodySmall),
    ]);
  }

  Widget _streakPanel(BuildContext context, String title,
          Map<String, int> counts, int total) =>
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        for (final e in AdminCheckInReport.streakLabels.entries)
          ProgressRow(e.value, total == 0 ? 0 : counts[e.key]! / total,
              '${counts[e.key]} Members'),
      ]));
}

