import 'admin_reporting_gateway.dart';
import 'admin_workout_reporting.dart';
import 'unified_admin_summary.dart';

/// Business presentation over validated aggregates. Never changes receipt,
/// entitlement, provenance or payment lifecycle contracts.
class BusinessDashboardMetrics {
  BusinessDashboardMetrics(this.snapshot, this.workouts) {
    if (snapshot.unified == null ||
        snapshot.operations == null ||
        !snapshot.isAvailable ||
        workouts != null && workouts!.query != snapshot.query) {
      throw const FormatException('Incompatible business report');
    }
    if (membershipMinor + coachingMinor != revenueMinor) {
      throw const FormatException('Business value mismatch');
    }
    final buckets = <String, int>{};
    for (final d in snapshot.operations!.daily) {
      final month = d.date.substring(0, 7);
      buckets[month] =
          (buckets[month] ?? 0) + d.membershipMinor + d.coachingMinor;
    }
    for (final d in summary.monthly) {
      buckets[d.month] = (buckets[d.month] ?? 0) + d.minor;
    }
    monthly = List.unmodifiable((buckets.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => UnifiedRevenueMonth(e.key, e.value)));
    if (monthly.fold<int>(0, (n, r) => n + r.minor) != revenueMinor) {
      throw const FormatException('Business trend mismatch');
    }
  }
  static const revenueDefinition =
      'Recorded membership and coaching value includes non-cash scenario entries; not settled cash, net income or payouts.';
  final AdminReportingSnapshot snapshot;
  final AdminWorkoutReport? workouts;
  late final List<UnifiedRevenueMonth> monthly;
  UnifiedAdminSummary get summary => snapshot.unified!;
  int get revenueMinor => summary.illustrativeMinor;
  int get membershipMinor =>
      snapshot.operations!.membershipMinor + summary.membershipMinor;
  int get coachingMinor =>
      snapshot.operations!.coachingMinor + summary.coachingMinor;
  int? get activeMembers => snapshot.activeMembersCount;
  int? get activeCoaches => snapshot.activeCoachesCount;
  int? get workoutSessions => workouts?.totals.sessions;
  int get bookings =>
      snapshot.totalBookingsCount! + summary.appointments['total']!;
  int get completed =>
      snapshot.operations!.statuses['completed']! +
      summary.appointments['completed']!;
  int get cancelled =>
      snapshot.operations!.statuses['cancelled']! +
      summary.appointments['cancelled']!;
  Map<String, int>? get tiers => snapshot.commerce == null
      ? null
      : {
          for (final key in ['free', 'basic', 'premium', 'unknown'])
            key: snapshot.commerce!.current[key]! +
                (summary.subscriptions[key] ?? 0)
        };
  int? get activeSubscriptions => tiers == null
      ? null
      : snapshot.commerce!.current.entries
              .where((e) => e.key != 'unknown')
              .fold<int>(0, (n, e) => n + e.value) +
          summary.subscriptions['active']!;
  int get expiredSubscriptions => summary.subscriptions['expired']!;
  int? get publishedPrograms => summary.catalogCounts.isEmpty
      ? null
      : (summary.catalogCounts['existingPrograms'] ?? 0) +
          (summary.catalogCounts['fypPrograms'] ?? 0);
  int? get publishedRoutines => summary.catalogCounts.isEmpty
      ? null
      : (summary.catalogCounts['existingTutorials'] ?? 0) +
          (summary.catalogCounts['fypTutorials'] ?? 0);
  List<List<Object?>> csv() => [
        ['GainPath business overview', 'MYR minor units'],
        ['Revenue definition', revenueDefinition],
        [
          'Start inclusive UTC',
          snapshot.query.range.start.toUtc().toIso8601String()
        ],
        [
          'End exclusive UTC',
          snapshot.query.range.end.toUtc().toIso8601String()
        ],
        ['Active Members', activeMembers],
        ['Active Coaches', activeCoaches],
        ['Workout Sessions', workoutSessions],
        ['Booking activity', bookings],
        ['Completed appointments', completed],
        ['Cancelled appointments', cancelled],
        ['Recorded revenue minor', revenueMinor],
        ['Membership revenue minor', membershipMinor],
        ['Coaching revenue minor', coachingMinor],
        ['Active subscriptions', activeSubscriptions],
        ['Expired subscriptions', expiredSubscriptions],
        [
          'Membership basis',
          'Current plan records; active excludes expired and unknown. Current census is independent of activity dates.'
        ],
        if (tiers != null)
          for (final e in tiers!.entries) ['Membership ${e.key}', e.value],
        ['Malaysia month', 'Recorded revenue minor'],
        for (final r in monthly) [r.month, r.minor],
      ];
}
