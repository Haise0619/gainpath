import 'admin_report_presentation.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/admin_reporting_gateway.dart';
import '../../application/admin_operational_metrics.dart';

String reportMoney(int? minor) =>
    minor == null ? 'MYR —' : 'MYR ${(minor / 100).toStringAsFixed(2)}';
String reportCalendarDate(DateTime value) =>
    value.toUtc().add(adminReportZone).toIso8601String().substring(0, 10);

class OriginalBookingBars extends StatelessWidget {
  const OriginalBookingBars({super.key, required this.days});
  final List<AdminOperationalDay> days;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final minimumWidth =
            days.length * MediaQuery.textScalerOf(context).scale(44);
        final width = minimumWidth > c.maxWidth ? minimumWidth : c.maxWidth;
        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
                width: width,
                child: Column(children: [
                  BarChart(days.map((d) => d.bookingsCreated).toList(),
                      height: 150),
                  if (days.isNotEmpty)
                    Row(children: [
                      for (final day in days)
                        Expanded(
                            child: Text(day.date.substring(5),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: const TextStyle(
                                    fontSize: 9.5, color: AppColors.inkSoft)))
                    ]),
                ])));
      });
}

/// Data binding inside the existing chart panels, using their original chart.
class OriginalReceiptTrend extends StatelessWidget {
  const OriginalReceiptTrend(
      {super.key, required this.snapshot, this.membershipOnly = false});
  final AdminReportingSnapshot snapshot;
  final bool membershipOnly;
  @override
  Widget build(BuildContext context) {
    final days = snapshot.operations!.daily;
    final values = days
        .map((d) => membershipOnly ? d.membershipMinor : d.receiptsMinor)
        .toList();
    if (days.isEmpty) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
              child: Text('No confirmed receipts in this reporting period.')));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (values.length == 1)
        SizedBox(
            height: 130,
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.circle, size: 9, color: AppColors.primary),
              const SizedBox(height: 8),
              Text('${days.single.date} · ${reportMoney(values.single)}')
            ])))
      else
        TrendChart(values),
      const SizedBox(height: 8),
      Text('${days.first.date} – ${days.last.date} · Malaysia dates',
          style: Theme.of(context).textTheme.bodySmall),
      const Text(
          'Confirmed Sandbox receipts · dates with recorded activity. Review/refund cases are excluded.'),
    ]);
  }
}

class OriginalReceiptBreakdown extends StatelessWidget {
  const OriginalReceiptBreakdown({super.key, required this.snapshot});
  final AdminReportingSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final ops = snapshot.operations!, total = snapshot.totalRevenue!.minorUnits;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ProgressRow('Membership', total == 0 ? 0 : ops.membershipMinor / total,
          reportMoney(ops.membershipMinor)),
      ProgressRow('Coaching', total == 0 ? 0 : ops.coachingMinor / total,
          reportMoney(ops.coachingMinor),
          color: AppColors.accent),
      const Divider(height: 22),
      Text(
          'Review-associated clearances: ${reportMoney(ops.reviewMinor)} · ${ops.reviewCount} records'),
      const SizedBox(height: 6),
      Text(
          'Refunded-associated clearances: ${reportMoney(ops.refundedMinor)} · ${ops.refundedCount} records'),
      const SizedBox(height: 8),
      const Text(
          'All amounts use original clearance dates. These are Sandbox receipts, not net revenue, refund cash flow or payouts.'),
    ]);
  }
}

class OriginalReportContext extends StatelessWidget {
  const OriginalReportContext({super.key, required this.snapshot});
  final AdminReportingSnapshot snapshot;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: AdminReportDetails(
          title: 'Reporting period & coverage',
          child: Text(
              '${reportCalendarDate(snapshot.query.range.start)} – ${reportCalendarDate(snapshot.query.range.end.subtract(const Duration(milliseconds: 1)))} · Malaysia (UTC+08:00) · '
              'Current account census; bookings by creation time; receipts by clearance time. '
              'Read ${snapshot.operations!.sourceReadStartedAt.toUtc().add(adminReportZone).toIso8601String().substring(11, 19)}–'
              '${snapshot.capturedAt.toUtc().add(adminReportZone).toIso8601String().substring(11, 19)} UTC+08:00.',
              style: Theme.of(context).textTheme.bodySmall)));
}
