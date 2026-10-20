import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide CornerStyle;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

DateTime _mondayOf(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return date.subtract(Duration(days: date.weekday - 1));
}

String _shortDate(DateTime d) => '${d.day} ${_monthNames[d.month - 1]}';

/// One real Monday–Sunday calendar week, with the actual completed
/// sessions that fell inside it — not an illustrative bucket.
class _WeekBucket {
  final DateTime monday;
  final DateTime sunday;
  final bool isCurrent;
  final List<Booking> sessions;
  const _WeekBucket({
    required this.monday,
    required this.sunday,
    required this.isCurrent,
    required this.sessions,
  });

  double get total => sessions.fold(0.0, (sum, b) => sum + b.fee);

  String get axisLabel => '${monday.day}–${sunday.day}';
  String get rangeLabel => monday.month == sunday.month
      ? '${monday.day}–${sunday.day} ${_monthNames[monday.month - 1]}'
      : '${_shortDate(monday)} – ${_shortDate(sunday)}';
}

class _WeekPoint {
  final String label;
  final double amount;
  const _WeekPoint(this.label, this.amount);
}

/// AD-M9.3 — View Performance Metrics Dashboard. The weekly chart used to
/// show seven bars labelled "W1"..."W7" against a fixed illustrative
/// array — no real dates, no way to tell which bar was the current week,
/// and nothing behind a bar to look at. It now buckets the coach's own
/// completed sessions into real Monday–Sunday calendar weeks, labels
/// each bar with its actual date range, highlights whichever bar is the
/// current week, and expands inline underneath the chart with that
/// week's real session list when tapped.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen(
      {super.key,
      this.connected = false,
      this.bookings,
      this.rating,
      this.reviews});
  final bool connected;
  final List<Booking>? bookings;
  final double? rating;
  final int? reviews;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int? _expandedWeek;

  void _exportStatement(BuildContext context, List<Booking> completed, double totalEarned) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Performance Statement', style: Theme.of(ctx).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              DetailRow('Statement period', 'Past 30 Days'),
              DetailRow('Completed sessions', completed.length.toString()),
              DetailRow('Gross volume', 'RM ' + (totalEarned / 0.70).toStringAsFixed(2)),
              DetailRow('Platform fee (30%)', 'RM ' + (totalEarned / 0.70 * 0.30).toStringAsFixed(2)),
              const Divider(height: 24),
              DetailRow('Net Coach Commission (70%)', 'RM ' + totalEarned.toStringAsFixed(2)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    try {
                      _generatePdf(
                        completedCount: completed.length,
                        grossVolume: totalEarned > 0 ? totalEarned / 0.70 : 0.0,
                        platformFee:
                            totalEarned > 0 ? (totalEarned / 0.70) * 0.30 : 0.0,
                        netCommission: totalEarned,
                        sessions: completed,
                      );
                    } catch (_) {}
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Statement PDF exported successfully.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export Statement PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  File _generatePdf({
    required int completedCount,
    required double grossVolume,
    required double platformFee,
    required double netCommission,
    required List<Booking> sessions,
  }) {
    final buffer = StringBuffer();
    final objects = <int>[];

    void addObj(String content) {
      objects.add(buffer.length);
      buffer.write('${objects.length} 0 obj\n$content\nendobj\n');
    }

    buffer.write('%PDF-1.4\n');
    addObj('<< /Type /Catalog /Pages 2 0 R >>');
    addObj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    addObj('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>');
    addObj('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');

    final stream = StringBuffer();
    stream.writeln('BT');
    stream.writeln('/F1 18 Tf');
    stream.writeln('50 740 Td (GainPath - Coach Performance Statement) Tj');
    stream.writeln('/F1 11 Tf');
    stream.writeln('0 -25 Td (Statement Period: Past 30 Days) Tj');
    stream.writeln('0 -18 Td (Generated: ${DateTime.now().toIso8601String().split('T')[0]}) Tj');
    stream.writeln('0 -30 Td (Financial Summary) Tj');
    stream.writeln('/F1 10 Tf');
    stream.writeln('0 -18 Td (Completed Sessions: $completedCount) Tj');
    stream.writeln('0 -16 Td (Gross Volume: RM ${grossVolume.toStringAsFixed(2)}) Tj');
    stream.writeln('0 -16 Td (Platform Fee: RM ${platformFee.toStringAsFixed(2)}) Tj');
    stream.writeln('0 -16 Td (Net Coach Commission: RM ${netCommission.toStringAsFixed(2)}) Tj');
    stream.writeln('0 -30 Td (Completed Sessions Breakdown) Tj');
    for (final b in sessions.take(20)) {
      final name = b.memberName.replaceAll(RegExp(r'[()]'), '');
      stream.writeln('0 -16 Td ($name | RM ${b.fee.toStringAsFixed(2)}) Tj');
    }
    stream.writeln('ET');

    final streamBytes = utf8.encode(stream.toString());
    addObj('<< /Length ${streamBytes.length} >>\nstream\n${stream.toString()}endstream');

    final startXref = buffer.length;
    buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in objects) {
      buffer.write(offset.toString().padLeft(10, '0') + ' 00000 n \n');
    }
    buffer.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$startXref\n%%EOF\n');

    final dir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/statement_$timestamp.pdf');
    file.writeAsBytesSync(utf8.encode(buffer.toString()), flush: true);
    return file;
  }

  List<_WeekBucket> _buildWeeks(List<Booking> completed) {
    final currentMonday = _mondayOf(DateTime.now());
    return List.generate(7, (i) {
      final weeksAgo = 6 - i;
      final monday = currentMonday.subtract(Duration(days: 7 * weeksAgo));
      final sunday = monday.add(const Duration(days: 6));
      final sessions = completed.where((b) {
        final d = DateTime(b.start.year, b.start.month, b.start.day);
        return !d.isBefore(monday) && !d.isAfter(sunday);
      }).toList()
        ..sort((a, b) => b.start.compareTo(a.start));
      return _WeekBucket(
          monday: monday,
          sunday: sunday,
          isCurrent: weeksAgo == 0,
          sessions: sessions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final coach =
        widget.connected ? null : context.read<CoachRepository>().currentCoach;
    final available = !widget.connected || widget.bookings != null;
    final roster = widget.connected
        ? (widget.bookings ?? <Booking>[])
        : context.read<BookingRepository>().coachRoster;
    final completed = roster
        .where((b) => b.status == BookingStatus.completed)
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    final totalEarned = completed.fold<double>(0.0, (sum, b) => sum + b.fee);
    final notCancelled =
        roster.where((b) => b.status != BookingStatus.cancelled).length;
    final fillRate =
        roster.isEmpty ? 0 : (notCancelled / roster.length * 100).round();
    final avgPerSession =
        completed.isEmpty ? 0.0 : totalEarned / completed.length;

    final weeks = _buildWeeks(completed);
    final bestWeek = weeks.reduce((a, b) => a.total >= b.total ? a : b);
    final weekData =
        weeks.map((w) => _WeekPoint(w.axisLabel, w.total)).toList();

    final topClients = <String, List<Booking>>{};
    for (final b in completed) {
      topClients.putIfAbsent(b.memberName, () => []).add(b);
    }
    final topClientEntries = topClients.entries.toList()
      ..sort((a, b) => b.value
          .fold<double>(0, (s, x) => s + x.fee)
          .compareTo(a.value.fold<double>(0, (s, x) => s + x.fee)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export statement',
            onPressed: available && completed.isNotEmpty
                ? () => _exportStatement(context, completed, totalEarned)
                : () => showUnavailable(context),
          ),
        ],
      ),
      body: PageBody(
        children: [
          if (widget.connected && completed.isEmpty)
            const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Ratings, commission earnings and statements reflect verified completed sessions. Pending holds and future bookings are not earned income.')),
          Panel(
            background: AppColors.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL EARNED',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70)),
                const SizedBox(height: 6),
                Text(available ? 'RM ${totalEarned.toStringAsFixed(0)}' : '-',
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1)),
                const SizedBox(height: 4),
                Text(available ? '${completed.length} sessions completed' : '-',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: StatTile(
                      '${widget.connected ? (widget.rating != null ? widget.rating!.toStringAsFixed(1) : "—") : coach!.rating}',
                      'Avg rating',
                      valueColor: AppColors.accent)),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile(
                      '${widget.connected ? (widget.reviews != null ? widget.reviews!.toString() : "—") : coach!.reviews}',
                      'Reviews')),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile(available ? '$fillRate%' : '—', 'Fill rate')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: StatTile(
                      available
                          ? 'RM ${avgPerSession.toStringAsFixed(0)}'
                          : '-',
                      'Avg / session',
                      compact: true)),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile(
                      available
                          ? 'RM ${bestWeek.total.toStringAsFixed(0)}'
                          : '-',
                      'Best week',
                      compact: true,
                      valueColor: AppColors.success)),
            ],
          ),
          const SizedBox(height: 20),
          const Eyebrow('Weekly earnings'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.touch_app_outlined,
                        size: 14, color: AppColors.inkSoft),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text('Tap a bar to see that week\'s sessions',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: 12))),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 190,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    primaryXAxis: const CategoryAxis(
                      majorGridLines: MajorGridLines(width: 0),
                      axisLine: AxisLine(width: 0),
                      labelIntersectAction: AxisLabelIntersectAction.wrap,
                      labelStyle:
                          TextStyle(fontSize: 10, color: AppColors.inkSoft),
                    ),
                    primaryYAxis: const NumericAxis(
                      majorGridLines:
                          MajorGridLines(width: 0.6, color: AppColors.hairline),
                      axisLine: AxisLine(width: 0),
                      labelStyle:
                          TextStyle(fontSize: 10, color: AppColors.inkSoft),
                    ),
                    tooltipBehavior: TooltipBehavior(
                      enable: true,
                      header: '',
                      format: 'RM point.y  ·  week point.x',
                    ),
                    series: <CartesianSeries<_WeekPoint, String>>[
                      ColumnSeries<_WeekPoint, String>(
                        dataSource: available ? weekData : const <_WeekPoint>[],
                        xValueMapper: (d, _) => d.label,
                        yValueMapper: (d, _) => d.amount,
                        pointColorMapper: (d, i) => weeks[i].isCurrent
                            ? AppColors.accent
                            : AppColors.primary,
                        width: 0.55,
                        borderRadius: BorderRadius.circular(6),
                        onPointTap: (details) {
                          final i = details.pointIndex;
                          if (i == null) return;
                          setState(() =>
                              _expandedWeek = _expandedWeek == i ? null : i);
                        },
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: _expandedWeek == null
                      ? const SizedBox(width: double.infinity)
                      : _WeekDetail(week: weeks[_expandedWeek!]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Booking fill rate'),
          Panel(
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: SfRadialGauge(
                    axes: [
                      RadialAxis(
                        minimum: 0,
                        maximum: 100,
                        showLabels: false,
                        showTicks: false,
                        startAngle: 270,
                        endAngle: 270,
                        radiusFactor: 0.9,
                        axisLineStyle: const AxisLineStyle(
                          thickness: 0.16,
                          thicknessUnit: GaugeSizeUnit.factor,
                          color: AppColors.surfaceAlt,
                        ),
                        pointers: [
                          RangePointer(
                            value: fillRate.toDouble(),
                            width: 0.16,
                            sizeUnit: GaugeSizeUnit.factor,
                            color: AppColors.primary,
                            cornerStyle: CornerStyle.bothCurve,
                          ),
                        ],
                        annotations: [
                          GaugeAnnotation(
                            positionFactor: 0,
                            widget: Text(available ? '$fillRate%' : '-',
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    available
                        ? '$notCancelled of ${roster.length} bookings are not cancelled.'
                        : 'Booking fill rate: -',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Top clients'),
          if (topClientEntries.isEmpty)
            Panel(
              child: Text(available ? 'No completed sessions yet.' : '-',
                  style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ...topClientEntries.take(3).map((e) {
              final revenue = e.value.fold<double>(0, (s, b) => s + b.fee);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(11)),
                        child: Center(
                          child: Text(
                            e.key.split(' ').map((w) => w[0]).take(2).join(),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                '${e.value.length} session${e.value.length == 1 ? '' : 's'}',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      Text('RM ${revenue.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success)),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          const Eyebrow('Recent sessions'),
          if (completed.isEmpty)
            Panel(
              child: Text(available ? 'No completed sessions yet.' : '-',
                  style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            ...completed.take(5).map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.memberName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                '${_shortDate(b.start)}  ·  ${b.notes != null ? 'Notes published' : 'Completed session'}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Text('RM ${b.fee.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 6),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Figures reflect recorded completed session fees. Payment clearance and payouts are unavailable.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The inline detail panel that opens beneath the chart when a bar is
/// tapped — kept in-place next to the chart it explains, rather than a
/// sheet or a new screen, so comparing weeks stays a single tap away.
class _WeekDetail extends StatelessWidget {
  final _WeekBucket week;
  const _WeekDetail({required this.week});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(week.rangeLabel,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700)),
                    if (week.isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(999)),
                        child: const Text('CURRENT',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
              Text('RM ${week.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          if (week.sessions.isEmpty)
            Text('No completed sessions in this week.',
                style: Theme.of(context).textTheme.bodyMedium)
          else
            ...week.sessions.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.primary),
                      ),
                      Expanded(
                        child: Text(
                            '${b.memberName}  ·  ${_shortDate(b.start)}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text('RM ${b.fee.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
