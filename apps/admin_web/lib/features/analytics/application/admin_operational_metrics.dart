import 'package:flutter/material.dart';
import 'admin_reporting_gateway.dart';

const adminReportZone = Duration(hours: 8);
AdminReportQuery operationalDateQuery(DateTime now,
    {int? days = 30, DateTimeRange? calendarRange}) {
  final local = now.toUtc().add(adminReportZone),
      today = DateTime.utc(local.year, local.month, local.day);
  final start = calendarRange == null
      ? (days == null
          ? DateTime.utc(1970)
          : today.subtract(Duration(days: days - 1)))
      : DateTime.utc(calendarRange.start.year, calendarRange.start.month,
          calendarRange.start.day);
  final last = calendarRange == null
      ? today
      : DateTime.utc(calendarRange.end.year, calendarRange.end.month,
          calendarRange.end.day);
  final from = start.subtract(adminReportZone);
  return AdminReportQuery(
      range: DateTimeRange(
          start: from.millisecondsSinceEpoch < 0
              ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
              : from,
          end: last.add(const Duration(days: 1)).subtract(adminReportZone)));
}

class AdminOperationalMetrics {
  AdminOperationalMetrics(
      {required this.scheduledStarts,
      required Map<String, int> statuses,
      required this.membershipMinor,
      required this.coachingMinor,
      required this.confirmedCount,
      required this.reviewMinor,
      required this.reviewCount,
      required this.refundedMinor,
      required this.refundedCount,
      required this.sourceReadStartedAt,
      required Map<String, int> sourceCounts,
      required List<AdminOperationalDay> daily,
      required List<String> unsupported})
      : statuses = Map.unmodifiable(statuses),
        sourceCounts = Map.unmodifiable(sourceCounts),
        daily = List.unmodifiable(daily),
        unsupported = List.unmodifiable(unsupported);
  final int scheduledStarts,
      membershipMinor,
      coachingMinor,
      confirmedCount,
      reviewMinor,
      reviewCount,
      refundedMinor,
      refundedCount;
  final DateTime sourceReadStartedAt;
  final Map<String, int> statuses, sourceCounts;
  final List<AdminOperationalDay> daily;
  final List<String> unsupported;
  List<List<Object?>> toCsv(AdminReportingSnapshot s) => [
        ['GainPath Admin operational report', 'Sandbox · MYR'],
        ['Timezone', 'Asia/Kuala_Lumpur UTC+08:00'],
        ['Start inclusive UTC', s.query.range.start.toUtc().toIso8601String()],
        ['End exclusive UTC', s.query.range.end.toUtc().toIso8601String()],
        ['Source scan started UTC', sourceReadStartedAt.toIso8601String()],
        ['Captured UTC', s.capturedAt.toUtc().toIso8601String()],
        [
          'Basis',
          'Current account census; bookings by creation time; receipts by server clearance time. Bounded live reads, not historical account census or an atomic cross-collection snapshot.'
        ],
        [
          'Money',
          'MYR minor units; confirmed receipts exclude reconciliation/refund-review/completed refund cases. Not net revenue, profit or payouts.'
        ],
        ['Current active Member accounts', s.activeMembersCount],
        ['Current active Coach accounts', s.activeCoachesCount],
        ['Bookings created', s.totalBookingsCount],
        ['Confirmed/completed scheduled starts', scheduledStarts],
        ['Confirmed receipt count', confirmedCount],
        ['Confirmed receipts minor', s.totalRevenue?.minorUnits],
        ['Membership receipts minor', membershipMinor],
        ['Coaching receipts minor', coachingMinor],
        ['Review-associated clearance count', reviewCount],
        ['Review-associated clearance minor', reviewMinor],
        ['Refunded-associated clearance count', refundedCount],
        ['Refunded-associated clearance minor', refundedMinor],
        [
          'Refund basis',
          'Both review and refunded buckets use original clearance date; they are not refund cash flow.'
        ],
        [],
        ['Booking current status', 'Count of bookings created in range'],
        for (final e in statuses.entries) [e.key, e.value],
        [],
        [
          'Malaysia date',
          'Bookings created',
          'Scheduled starts',
          'Confirmed receipts minor',
          'Membership minor',
          'Coaching minor'
        ],
        for (final d in daily)
          [
            d.date,
            d.bookingsCreated,
            d.scheduledStarts,
            d.receiptsMinor,
            d.membershipMinor,
            d.coachingMinor
          ],
        [],
        ['Complete scan source', 'Documents read'],
        for (final e in sourceCounts.entries) [e.key, e.value],
        [],
        ['Unsupported', unsupported.join(', ')],
      ];
}

class AdminOperationalDay {
  const AdminOperationalDay(
      {required this.date,
      required this.bookingsCreated,
      required this.scheduledStarts,
      required this.receiptsMinor,
      required this.membershipMinor,
      required this.coachingMinor});
  final String date;
  final int bookingsCreated,
      scheduledStarts,
      receiptsMinor,
      membershipMinor,
      coachingMinor;
}
