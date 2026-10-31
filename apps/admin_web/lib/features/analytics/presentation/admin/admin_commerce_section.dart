import 'admin_report_presentation.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_commerce_report.dart';

class AdminCommerceSection extends StatefulWidget {
  const AdminCommerceSection(
      {super.key,
      required this.anchorKey,
      required this.report,
      required this.coach});
  final GlobalKey anchorKey;
  final AdminCommerceReport report;
  final bool coach;
  @override
  State<AdminCommerceSection> createState() => _AdminCommerceSectionState();
}

class _AdminCommerceSectionState extends State<AdminCommerceSection> {
  String? _filter;
  int _sort = 0;
  bool _ascending = true;
  String _money(int n) => 'MYR ${(n / 100).toStringAsFixed(2)}';
  String _rate(int n, int d) =>
      d == 0 ? '—' : '${(n / d * 100).toStringAsFixed(1)}%';
  @override
  Widget build(BuildContext context) {
    final r = widget.report, coach = widget.coach;
    final source = coach ? r.coaches : r.plans;
    final filter = source.any((v) => v.id == _filter) ? _filter : null;
    final rows = source.where((v) => filter == null || v.id == filter).toList();
    if (!coach && filter == null) rows.add(r.coaching);
    final columns = coach
        ? [
            'Coach',
            'Bookings',
            'Completed outcomes',
            'Consultations',
            'Cancelled',
            'Consultation completion rate',
            'Cancellation rate',
            'Rating',
            'Reviews'
          ]
        : [
            'Plan / stream',
            'Purchases',
            'Renewals',
            'Confirmed receipts',
            'Receipt count',
            'Review-associated',
            'Refunded-associated'
          ];
    Object value(CommerceRow row, int i) => coach
        ? switch (i) {
            0 => row.name,
            1 => row['bookings'],
            2 => row['completed'],
            3 => row['consultations'],
            4 => row['cancelled'],
            5 => row['bookings'] == 0
                ? -1
                : (row['completed'] - row['missingConsultations']) /
                    row['bookings'],
            6 => row['bookings'] == 0 ? -1 : row['cancelled'] / row['bookings'],
            7 => row['reviewCount'] == 0
                ? -1
                : row['ratingSum'] / row['reviewCount'],
            _ => row['reviewCount']
          }
        : switch (i) {
            0 => row.name,
            1 => row['purchases'],
            2 => row['renewals'],
            3 => row['confirmedMinor'],
            4 => row['confirmedCount'],
            5 => row['reviewMinor'],
            _ => row['refundedMinor']
          };
    rows.sort((a, b) {
      final x = value(a, _sort), y = value(b, _sort);
      final c = x is num && y is num
          ? x.compareTo(y)
          : x.toString().compareTo(y.toString());
      return _ascending ? c : -c;
    });
    int total(String key) => rows.fold(0, (n, v) => n + v[key]);
    Widget stat(String label, String value) =>
        SizedBox(width: 200, child: StatTile(value, label));
    final dates = <String, Map<String, Object>>{};
    for (final row in rows) {
      for (final day in row.daily) {
        final d = day['date'] as String;
        final target = dates.putIfAbsent(d, () => {'date': d});
        for (final e in day.entries.where((e) => e.key != 'date')) {
          target[e.key] = (target[e.key] as int? ?? 0) + (e.value as int);
        }
      }
    }
    final days = dates.values.toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    final series = coach ? ['bookings', 'consultations'] : ['confirmedMinor'];
    return ReportSection(
        anchorKey: widget.anchorKey,
        title: coach ? 'Coach Performance Comparison' : 'Membership & Revenue',
        subtitle: coach
            ? 'Recorded bookings, published consultations and review samples'
            : 'Current membership snapshot · historical Sandbox transactions',
        live: true,
        tagLabel: coach ? 'Recorded' : 'Sandbox',
        exportFilename:
            coach ? 'coach_performance.csv' : 'membership_sandbox_receipts.csv',
        exportRows: () => r.csv(coach: coach, filter: filter),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: filter,
              decoration: InputDecoration(
                  labelText: coach ? 'Coach' : 'Membership plan',
                  helperMaxLines: 4,
                  helperText: coach
                      ? 'All recorded Coaches, including historical records'
                      : 'Plan filter applies historical transactions; current tier census stays organization-wide'),
              items: [
                DropdownMenuItem<String>(
                    value: null,
                    child: Text(coach ? 'All Coaches' : 'All streams')),
                ...source.map(
                    (v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
              ],
              onChanged: (v) => setState(() => _filter = v)),
          const SizedBox(height: 14),
          if (!coach) ...[
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final e in r.current.entries)
                stat('Current ${e.key} Members', '${e.value}')
            ]),
            const SizedBox(height: 10),
            const Text(
                'Current canonical active Member cohort, independent of the selected dates. Unknown means entitlement evidence could not be resolved.'),
            const SizedBox(height: 16),
          ],
          Wrap(
              spacing: 10,
              runSpacing: 10,
              children: coach
                  ? [
                      stat('Bookings created', '${total('bookings')}'),
                      stat('Published consultations',
                          '${total('consultations')}'),
                      stat('Review samples', '${total('reviewCount')}')
                    ]
                  : [
                      stat('Confirmed Sandbox receipts',
                          _money(total('confirmedMinor'))),
                      stat('New purchases', '${total('purchases')}'),
                      stat('Renewals', '${total('renewals')}')
                    ]),
          const SizedBox(height: 12),
          AdminReportDetails(
              child: Text(coach
                  ? 'Outcomes are current statuses of bookings created in the selected Malaysia period. Consultation completion rate = completed outcomes with published consultation / all created bookings; cancellation rate = cancelled / all created bookings. Pending, expired and refunded remain in the denominator. Consultations and reviews use their own event dates; bookings do not prove consultations.'
                  : 'Payment/refund status counts use transaction creation dates. Confirmed receipts use original server clearance dates and exclude review/refund cases. These are Billplz Sandbox gross receipts, not net revenue, profit or payout. Refund approval does not establish a transferred refund.')),
          if (rows.isEmpty)
            const Padding(
                padding: EdgeInsets.all(18),
                child: Text('No matching records in this reporting window.')),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                    sortColumnIndex: _sort,
                    sortAscending: _ascending,
                    columns: [
                      for (var i = 0; i < columns.length; i++)
                        DataColumn(
                            label: Text(columns[i]),
                            numeric: i > 0,
                            onSort: (i, a) => setState(() {
                                  _sort = i;
                                  _ascending = a;
                                }))
                    ],
                    rows: [
                      for (final row in rows)
                        DataRow(cells: [
                          for (var i = 0; i < columns.length; i++)
                            DataCell(Text(coach
                                ? switch (i) {
                                    5 => _rate(
                                        row['completed'] -
                                            row['missingConsultations'],
                                        row['bookings']),
                                    6 =>
                                      _rate(row['cancelled'], row['bookings']),
                                    7 => row['reviewCount'] == 0
                                        ? 'No reviews'
                                        : (row['ratingSum'] /
                                                row['reviewCount'])
                                            .toStringAsFixed(2),
                                    _ => value(row, i).toString()
                                  }
                                : i >= 3 && i != 4
                                    ? _money(value(row, i) as int)
                                    : value(row, i).toString()))
                        ])
                    ])),
            const SizedBox(height: 14),
            if (days.isNotEmpty)
              SizedBox(
                  height: 240,
                  child: SfCartesianChart(
                      primaryXAxis: const DateTimeAxis(),
                      primaryYAxis: NumericAxis(
                          minimum: 0,
                          title: AxisTitle(
                              text: coach ? 'Recorded events' : 'MYR')),
                      legend: Legend(
                          isVisible: coach,
                          position: LegendPosition.bottom,
                          overflowMode: LegendItemOverflowMode.wrap),
                      tooltipBehavior: TooltipBehavior(enable: true),
                      series: <CartesianSeries<Map<String, Object>, DateTime>>[
                        for (final key in series)
                          ColumnSeries<Map<String, Object>, DateTime>(
                              color: adminReportPalette[series.indexOf(key) %
                                  adminReportPalette.length],
                              name: key == 'confirmedMinor'
                                  ? 'Confirmed receipts (MYR)'
                                  : key,
                              dataSource: days,
                              xValueMapper: (d, _) =>
                                  DateTime.parse('${d['date']}T00:00:00Z'),
                              yValueMapper: (d, _) =>
                                  (d[key] as int? ?? 0) /
                                  (key == 'confirmedMinor' ? 100 : 1))
                      ])),
            ExpansionTile(
                title: Text(coach
                    ? 'Booking outcomes and coverage'
                    : 'Payment statuses, comparison and coverage'),
                children: [
                  for (final row in rows)
                    ListTile(
                        title: Text(row.name),
                        subtitle: Text(coach
                            ? 'Scheduled starts ${row['scheduledStarts']} (confirmed/completed, including upcoming) · Confirmed ${row['confirmed']} · pending ${row['pendingHold']} · expired ${row['expired']} · refunded ${row['refunded']} · completed without consultation ${row['missingConsultations']}'
                            : '${row.values.entries.where((e) => e.key.startsWith('status:') || e.key.startsWith('refund:')).map((e) => '${e.key.replaceFirst('status:', 'Payment ').replaceFirst('refund:', 'Refund ')}: ${e.value}').join(' · ')}\n${r.previousAvailable ? 'Previous equal-duration confirmed receipts: ${_money(row['previous:confirmedMinor'])}; change ${_money(row['confirmedMinor'] - row['previous:confirmedMinor'])}' : 'Previous-period comparison unavailable.'}')),
                  for (final e in r.coverage.entries)
                    ListTile(
                        dense: true,
                        title: Text(e.key),
                        trailing: Text('${e.value}')),
                ])
          ],
          const SizedBox(height: 10),
          Text(
              'As of ${r.asOf.toUtc().toIso8601String()} · bounded reads, not an atomic cross-collection snapshot.',
              style: Theme.of(context).textTheme.bodySmall),
        ]));
  }
}
