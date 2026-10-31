import 'admin_report_presentation.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../application/admin_engagement_extension.dart';

const _pending = Text(
    'Reward and mini-game analytics are awaiting server activation. Existing check-in reporting remains available.');
Widget _stats(Map<String, int> values) =>
    Wrap(spacing: 10, runSpacing: 10, children: [
      for (final e in values.entries)
        SizedBox(width: 210, child: StatTile('${e.value}', e.key))
    ]);
Widget _table(List<String> headings, List<List<String>> rows) =>
    SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: [
          for (final h in headings) DataColumn(label: Text(h))
        ], rows: [
          for (final row in rows)
            DataRow(cells: [for (final cell in row) DataCell(Text(cell))])
        ]));
Widget _trend(List<EngagementRow> rows, Map<String, String> series) => rows
        .isEmpty
    ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No recorded events in this date range.'))
    : SizedBox(
        height: 250,
        child: SfCartesianChart(
            primaryXAxis: const DateTimeAxis(),
            primaryYAxis: const NumericAxis(minimum: 0, decimalPlaces: 0),
            legend: const Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                overflowMode: LegendItemOverflowMode.wrap),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <CartesianSeries<EngagementRow, DateTime>>[
              for (final e in series.entries)
                ColumnSeries<EngagementRow, DateTime>(
                    color: adminReportPalette[
                        series.keys.toList().indexOf(e.key) %
                            adminReportPalette.length],
                    name: e.value,
                    dataSource: rows,
                    xValueMapper: (r, _) => DateTime.parse('${r.id}T00:00:00Z'),
                    yValueMapper: (r, _) => r[e.key])
            ]));

class AdminRedemptionData extends StatelessWidget {
  const AdminRedemptionData({super.key, required this.extension});
  final AdminEngagementExtension? extension;
  @override
  Widget build(BuildContext context) {
    final e = extension;
    if (e == null) return _pending;
    final r = e.redemptions;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stats({
        'Vouchers issued': r['issued']!,
        'Vouchers collected': r['collected']!,
        'Vouchers expired': r['expired']!,
        'Points spent': r['pointsSpent']!
      }),
      const SizedBox(height: 12),
      const AdminReportDetails(
          child: Text(
              'Malaysia event dates: issued and spent points use issue time; collected uses fulfilment time; expired uses the expiry date of currently uncollected vouchers. Counts are separate events, not a conversion rate. Points remain spent on expiry.')),
      const SizedBox(height: 14),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Redemption and collection trend',
            style: Theme.of(context).textTheme.titleMedium),
        _trend(e.redemptionDays, {
          'issued': 'Issued',
          'collected': 'Collected',
          'expired': 'Expired'
        }),
        ExpansionTile(title: const Text('View event data'), children: [
          _table([
            'Malaysia day',
            'Issued',
            'Collected',
            'Expired',
            'Points spent'
          ], [
            for (final d in e.redemptionDays)
              [
                d.id,
                '${d['issued']}',
                '${d['collected']}',
                '${d['expired']}',
                '${d['pointsSpent']}'
              ]
          ])
        ])
      ])),
      const SizedBox(height: 14),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Status of vouchers issued in range',
            style: Theme.of(context).textTheme.titleMedium),
        Text(
            'Current as of ${e.statusAsOf.toUtc().add(const Duration(hours: 8)).toIso8601String().substring(0, 19)} Malaysia time (source scan start); issue-date cohort, not historical status at period end.'),
        for (final s in e.status.entries)
          ProgressRow(
              s.key == 'expiryUnknown' ? 'Expiry unavailable' : s.key,
              r['issued'] == 0 ? 0 : s.value / r['issued']!,
              '${s.value} vouchers')
      ])),
      const SizedBox(height: 14),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Most redeemed rewards',
            style: Theme.of(context).textTheme.titleMedium),
        const Text(
            'Ranked by vouchers issued; collections use their own event dates.'),
        if (e.rewards.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                  'No reward redemptions or collections in this date range.'))
        else
          _table([
            'Reward',
            'Issued',
            'Collected',
            'Points spent'
          ], [
            for (final item in e.rewards)
              [
                item.label,
                '${item['issued']}',
                '${item['collected']}',
                '${item['pointsSpent']}'
              ]
          ])
      ])),
      const SizedBox(height: 10),
      Text(
          '${e.coverage['redemptions']} source vouchers scanned. Legacy vouchers without expiry metadata remain unavailable for expiry classification. No balances, inventory or receipt records are changed.',
          style: Theme.of(context).textTheme.bodySmall)
    ]);
  }
}

class AdminGameEngagementData extends StatelessWidget {
  const AdminGameEngagementData({super.key, required this.extension});
  final AdminEngagementExtension? extension;
  @override
  Widget build(BuildContext context) {
    final e = extension;
    if (e == null) return _pending;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Recorded mini-game participation',
          style: Theme.of(context).textTheme.titleMedium),
      const Text(
          'Organization server records only, including historical Members. Local-only play is not visible. Participation is not physically verified; Game Score is excluded. These reports do not enable earning.'),
      for (final g in e.games)
        Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(AdminEngagementExtension.gameNames[g.id]!,
                      style: Theme.of(context).textTheme.titleMedium),
                  _stats({
                    'Recorded starts': g['started'],
                    'Completed rounds': g['completed'],
                    'Members with starts': g['uniqueMembers'],
                    'Confirmed Reward Points': g['pointsAwarded']
                  }),
                  const SizedBox(height: 8),
                  Text(
                      '${g['abandoned']} abandoned · ${g['open']} unclosed start records · ${g['awards']} confirmed earning receipts'),
                  const Text(
                      'Starts and unique Members use start time; completed rounds use completion time; points use award time. No completion percentage is inferred.'),
                  _trend(e.gameDays[g.id]!, {
                    'started': 'Recorded starts',
                    'completed': 'Completed rounds'
                  }),
                  ExpansionTile(
                      title: const Text('View game event data'),
                      children: [
                        _table([
                          'Malaysia day',
                          'Starts',
                          'Completed',
                          'Awards',
                          'Reward Points'
                        ], [
                          for (final d in e.gameDays[g.id]!)
                            [
                              d.id,
                              '${d['started']}',
                              '${d['completed']}',
                              '${d['awards']}',
                              '${d['pointsAwarded']}'
                            ]
                        ])
                      ])
                ]))),
      const SizedBox(height: 14),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Confirmed earning sources',
            style: Theme.of(context).textTheme.titleMedium),
        const Text(
            'Check-ins cover current active Members; game receipts cover historical organization records. This is not a complete platform earning or wallet total.'),
        _table([
          'Source',
          'Confirmed receipts',
          'Reward Points'
        ], [
          for (final s in e.sources)
            [
              s.id == 'daily_check_in'
                  ? 'Daily check-in'
                  : AdminEngagementExtension.gameNames[s.id] ?? s.id,
              '${s['claims']}',
              '${s['pointsAwarded']}'
            ]
        ])
      ])),
      const SizedBox(height: 14),
      Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Real check-in badge unlocks',
            style: Theme.of(context).textTheme.titleMedium),
        const Text(
            'Unlock timestamps within selected dates, for current active Members.'),
        if (e.badges.every((b) => b['unlocks'] == 0))
          const Text('No badge unlocks recorded in this date range.'),
        _table([
          'Badge',
          'Unlocks'
        ], [
          for (final b in e.badges)
            [AdminEngagementExtension.badgeNames[b.id]!, '${b['unlocks']}']
        ])
      ])),
      Text(
          '${e.coverage['rounds']} recorded round sources · ${e.coverage['awards']} participation receipts scanned. No local-only games are inferred.',
          style: Theme.of(context).textTheme.bodySmall)
    ]);
  }
}
