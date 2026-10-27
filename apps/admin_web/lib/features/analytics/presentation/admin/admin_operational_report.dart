import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_reporting_cubit.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/admin_operational_metrics.dart';

class AdminOperationalReport extends StatelessWidget {
  const AdminOperationalReport(
      {super.key,
      required this.state,
      required this.onQuery,
      required this.onRefresh,
      this.exportCsv});
  final AdminReportingState state;
  final ValueChanged<AdminReportQuery> onQuery;
  final VoidCallback onRefresh;
  final void Function(List<List<Object?>> rows)? exportCsv;
  String _money(int value) => 'MYR ${(value / 100).toStringAsFixed(2)}';
  String _date(DateTime d) =>
      d.toUtc().add(adminReportZone).toIso8601String().substring(0, 10);
  @override
  Widget build(BuildContext context) {
    final s = state.snapshot, ops = s?.operations;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Admin operational reports',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          const Text('Organization-wide · Malaysia dates · Sandbox payments'),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final days in [1, 7, 30, 90])
                  OutlinedButton(
                      onPressed: state.isLoading
                          ? null
                          : () => onQuery(
                              operationalDateQuery(DateTime.now(), days: days)),
                      child: Text(days == 1 ? 'Today' : '$days days')),
                OutlinedButton(
                    onPressed: state.isLoading
                        ? null
                        : () => onQuery(
                            operationalDateQuery(DateTime.now(), days: null)),
                    child: const Text('All time')),
                OutlinedButton.icon(
                    icon: const Icon(Icons.date_range_outlined),
                    label: const Text('Custom dates'),
                    onPressed: state.isLoading
                        ? null
                        : () async {
                            final local =
                                DateTime.now().toUtc().add(adminReportZone);
                            final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(1970),
                                lastDate: DateTime(
                                    local.year, local.month, local.day));
                            if (range != null && context.mounted) {
                              onQuery(operationalDateQuery(DateTime.now(),
                                  calendarRange: range));
                            }
                          }),
                IconButton(
                    tooltip: 'Refresh reports',
                    onPressed: state.isLoading ? null : onRefresh,
                    icon: const Icon(Icons.refresh_rounded)),
                if (s != null && ops != null && !state.isLoading)
                  FilledButton.icon(
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download CSV'),
                      onPressed: () {
                        final rows = ops.toCsv(s);
                        if (exportCsv != null) {
                          exportCsv!(rows);
                        } else {
                          downloadCsv('gainpath-operational-report.csv', rows);
                        }
                      }),
              ]),
          const SizedBox(height: 10),
          Text(
              '${_date(state.query.range.start)} to ${_date(state.query.range.end.subtract(const Duration(milliseconds: 1)))} · inclusive calendar dates'),
          if (state.isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const Text('Reading current authorized records…')
          ] else if (s == null || ops == null) ...[
            const SizedBox(height: 16),
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(state.errorMessage ??
                      s?.unavailableReason ??
                      'Operational reports await backend activation.'),
                  const Text(
                      'No cached sample totals or partial financial aggregates are shown.'),
                  TextButton(
                      onPressed: onRefresh, child: const Text('Retry reports'))
                ])),
          ] else ...[
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth >= 1050
                  ? 4
                  : c.maxWidth >= 650
                      ? 3
                      : c.maxWidth >= 420
                          ? 2
                          : 1;
              final width = (c.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                _metric(
                    context,
                    'Confirmed Sandbox receipts',
                    _money(s.totalRevenue!.minorUnits),
                    '${ops.confirmedCount} cleared, confirmed transactions',
                    width),
                _metric(
                    context,
                    'Current active Member accounts',
                    '${s.activeMembersCount}',
                    'Current canonical organization membership',
                    width),
                _metric(
                    context,
                    'Current active Coach accounts',
                    '${s.activeCoachesCount}',
                    'Current canonical organization membership',
                    width),
                _metric(
                    context,
                    'Bookings created in range',
                    '${s.totalBookingsCount}',
                    'All stored current statuses',
                    width),
              ]);
            }),
            const SizedBox(height: 12),
            const Text(
                'Account counts are current, not historical active-user or attendance counts. Booking status is the current status of bookings created in this date range.'),
            const SizedBox(height: 20),
            const Eyebrow('Payment receipts · by original clearance date'),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _detail('Membership receipts', _money(ops.membershipMinor)),
              _detail('Coaching receipts', _money(ops.coachingMinor)),
              _detail('Review-associated clearances',
                  '${_money(ops.reviewMinor)} · ${ops.reviewCount} records'),
              _detail('Refunded-associated clearances',
                  '${_money(ops.refundedMinor)} · ${ops.refundedCount} records'),
            ]),
            const SizedBox(height: 8),
            const Text(
                'Confirmed receipts exclude reconciliation, refund-review and completed-refund cases. These are Sandbox collected amounts, not accounting revenue, profit or Coach payouts. Review/refunded buckets use original clearance dates and do not represent refund cash flow.'),
            const SizedBox(height: 16),
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Confirmed receipt trend',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  if (ops.daily.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                            'No dated booking or receipt activity in this range.'))
                  else
                    SizedBox(
                        height: 260,
                        child: SfCartesianChart(
                            primaryXAxis: CategoryAxis(labelRotation: -45),
                            primaryYAxis: NumericAxis(
                                minimum: 0,
                                title: const AxisTitle(text: 'MYR')),
                            legend: const Legend(
                                isVisible: true,
                                position: LegendPosition.bottom),
                            tooltipBehavior: TooltipBehavior(enable: true),
                            series: <CartesianSeries<AdminOperationalDay,
                                String>>[
                              ColumnSeries(
                                  dataSource: ops.daily,
                                  xValueMapper: (d, _) => d.date,
                                  yValueMapper: (d, _) =>
                                      d.membershipMinor / 100,
                                  name: 'Membership',
                                  color: AppColors.primary,
                                  animationDuration: 0),
                              ColumnSeries(
                                  dataSource: ops.daily,
                                  xValueMapper: (d, _) => d.date,
                                  yValueMapper: (d, _) => d.coachingMinor / 100,
                                  name: 'Coaching',
                                  color: AppColors.accent,
                                  animationDuration: 0),
                            ])),
                ])),
            const SizedBox(height: 20),
            const Eyebrow('Booking activity'),
            Text(
                '${ops.scheduledStarts} confirmed/completed session starts in range · separate from creation counts'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final entry in ops.statuses.entries)
                Chip(
                    label: Text(
                        '${entry.key.replaceAll('_', ' ')}: ${entry.value}'))
            ]),
            if (ops.daily.isNotEmpty)
              SizedBox(
                  height: 240,
                  child: SfCartesianChart(
                      primaryXAxis: CategoryAxis(labelRotation: -45),
                      primaryYAxis: NumericAxis(minimum: 0, decimalPlaces: 0),
                      legend: const Legend(
                          isVisible: true, position: LegendPosition.bottom),
                      series: <CartesianSeries<AdminOperationalDay, String>>[
                        LineSeries(
                            dataSource: ops.daily,
                            xValueMapper: (d, _) => d.date,
                            yValueMapper: (d, _) => d.bookingsCreated,
                            name: 'Bookings created',
                            color: AppColors.primary,
                            animationDuration: 0,
                            markerSettings:
                                const MarkerSettings(isVisible: true)),
                        LineSeries(
                            dataSource: ops.daily,
                            xValueMapper: (d, _) => d.date,
                            yValueMapper: (d, _) => d.scheduledStarts,
                            name: 'Scheduled starts',
                            color: AppColors.info,
                            animationDuration: 0,
                            markerSettings:
                                const MarkerSettings(isVisible: true)),
                      ])),
            const SizedBox(height: 16),
            ExpansionTile(
                title: const Text('Data definitions and current limits'),
                children: [
                  const ListTile(
                      title: Text('Complete bounded source reads'),
                      subtitle: Text(
                          'Up to 2,000 records per collection. Larger or malformed datasets fail instead of displaying partial totals. Reads occur over the interval below, not one atomic cross-collection snapshot.')),
                  ListTile(
                      title: Text(
                          'Read ${ops.sourceCounts['members']} membership records, ${ops.sourceCounts['bookings']} bookings and ${ops.sourceCounts['transactions']} transactions'),
                      subtitle: Text(
                          'Scan started ${ops.sourceReadStartedAt.toUtc().add(adminReportZone)} · completed ${s.capturedAt.toUtc().add(adminReportZone)} · UTC+08:00')),
                  const ListTile(
                      title: Text('Unavailable metrics'),
                      subtitle: Text(
                          'Facility occupancy, posture, retention risk, Coach utilization, reward redemption, net revenue and branch allocation are not connected by this report.')),
                  const ListTile(
                      title: Text('No sensitive detail rows'),
                      subtitle: Text(
                          'The report and CSV contain aggregates only; no Member names, emails, private messages or payment provider credentials.')),
                ]),
          ],
        ]));
  }

  Widget _metric(BuildContext context, String title, String value, String hint,
          double width) =>
      SizedBox(
          width: width,
          child: Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(hint)
              ])));
  Widget _detail(String title, String value) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 6),
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w700))
                  ]))));
}
