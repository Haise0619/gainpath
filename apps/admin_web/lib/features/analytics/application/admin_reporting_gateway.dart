import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show Money;
import 'admin_operational_metrics.dart';

/// Query for administrative reporting with time window and optional branch.
@immutable
class AdminReportQuery {
  final DateTimeRange range;
  final String? branchId;

  const AdminReportQuery({required this.range, this.branchId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminReportQuery &&
          runtimeType == other.runtimeType &&
          range == other.range &&
          branchId == other.branchId;

  @override
  int get hashCode => Object.hash(range, branchId);
}

/// A single data point for reporting charts.
@immutable
class ReportingPoint {
  final DateTime date;
  final num value;
  final String label;

  const ReportingPoint({
    required this.date,
    required this.value,
    required this.label,
  });
}

/// Activity entry for administrative feed.
@immutable
class AdminActivityRecord {
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  const AdminActivityRecord({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}

/// Snapshot of administrative metrics and reporting data.
/// Unknown or unsupported values are `null`, NEVER coerced to zero.
@immutable
class AdminReportingSnapshot {
  final AdminOperationalMetrics? operations;
  final AdminReportQuery query;
  final DateTime capturedAt;
  final bool isAvailable;
  final String? unavailableReason;

  // Supported or nullable metrics
  final Money? totalRevenue;
  final int? activeMembersCount;
  final int? totalBookingsCount;
  final double? avgPostureAccuracy;
  final int? activeCoachesCount;

  // Chart series (null if unsupported or unavailable)
  final List<ReportingPoint>? revenueTrend;

  /// Counts of sessions grouped by hour, never a monetary series.
  final List<ReportingPoint>? hourlySessions;
  final List<AdminActivityRecord>? recentActivity;
  final List<ReportingPoint>? postureTrends;
  final List<ReportingPoint>? bookingsTimeline;

  const AdminReportingSnapshot({
    this.operations,
    required this.query,
    required this.capturedAt,
    this.isAvailable = true,
    this.unavailableReason,
    this.totalRevenue,
    this.activeMembersCount,
    this.totalBookingsCount,
    this.avgPostureAccuracy,
    this.activeCoachesCount,
    this.revenueTrend,
    this.hourlySessions,
    this.recentActivity,
    this.postureTrends,
    this.bookingsTimeline,
  });

  /// Factory for an explicitly unavailable snapshot.
  factory AdminReportingSnapshot.unavailable({
    required AdminReportQuery query,
    String reason =
        'This reporting metric has no live backend service connected.',
  }) =>
      AdminReportingSnapshot(
        query: query,
        capturedAt: DateTime.now(),
        isAvailable: false,
        unavailableReason: reason,
      );

  bool hasMetric(String key) {
    if (!isAvailable) return false;
    switch (key) {
      case 'revenue':
        return totalRevenue != null;
      case 'members':
        return activeMembersCount != null;
      case 'bookings':
        return totalBookingsCount != null;
      case 'posture':
        return avgPostureAccuracy != null;
      case 'coaches':
        return activeCoachesCount != null;
      default:
        return false;
    }
  }
}

/// Port for loading administrative reporting data.
abstract class AdminReportingGateway {
  Future<AdminReportingSnapshot> load(AdminReportQuery query);
}

/// Marks the connected operational dataset without coupling UI to Firebase.
abstract interface class OperationalAdminReportingGateway
    implements AdminReportingGateway {}

/// Default gateway representing an unconnected/unavailable reporting service.
class UnavailableAdminReportingGateway implements AdminReportingGateway {
  const UnavailableAdminReportingGateway();

  @override
  Future<AdminReportingSnapshot> load(AdminReportQuery query) async {
    return AdminReportingSnapshot.unavailable(query: query);
  }
}
