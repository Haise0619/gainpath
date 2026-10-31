import '../../features/analytics/application/admin_observed_activity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/analytics/application/admin_reporting_gateway.dart';
import '../../features/analytics/application/admin_check_in_reporting.dart';
import '../../features/analytics/application/admin_engagement_extension.dart';

Map<String, dynamic> _map(Object? v) {
  if (v is! Map || v.keys.any((k) => k is! String)) {
    throw const FormatException('Invalid check-in object');
  }
  return Map<String, dynamic>.from(v);
}

int _int(Object? v, [int max = 9007199254740991]) {
  if (v is! num || !v.isFinite || v < 0 || v > max || v != v.roundToDouble()) {
    throw const FormatException('Invalid check-in integer');
  }
  return v.toInt();
}

Map<String, int> _counts(Object? v, Set<String> keys) {
  final m = _map(v);
  if (m.length != keys.length || !m.keys.toSet().containsAll(keys)) {
    throw const FormatException('Invalid check-in counts');
  }
  return m.map((k, v) => MapEntry(k, _int(v)));
}

DateTime _date(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid check-in date');
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    throw const FormatException('Invalid check-in calendar date');
  }
  return parsed;
}

AdminCheckInReport parseAdminCheckInReport(
    Object? raw, SessionScope scope, AdminReportQuery query) {
  final m = _map(raw),
      start = query.range.start.millisecondsSinceEpoch,
      end = query.range.end.millisecondsSinceEpoch;
  if (query.branchId != null ||
      m['schemaVersion'] != 1 ||
      m['organizationId'] != scope.organizationId ||
      m['startAtMillis'] != start ||
      m['endAtMillis'] != end ||
      m['timezone'] != 'Asia/Kuala_Lumpur' ||
      m['policyVersion'] != AdminCheckInReport.policyVersion ||
      m['pointsPerClaim'] != AdminCheckInReport.pointsPerClaim) {
    throw const FormatException('Check-in report scope or policy mismatch');
  }
  final scan = _int(m['sourceReadStartedAtMillis'], 8640000000000000),
      captured = _int(m['capturedAtMillis'], 8640000000000000);
  if (captured < scan) {
    throw const FormatException('Check-in scan time mismatch');
  }
  final coverage = _counts(m['coverage'],
      {'membersScanned', 'activeMembers', 'profiles', 'claimsScanned'});
  if (coverage['membersScanned']! > 2000 ||
      coverage['activeMembers']! > 200 ||
      coverage['activeMembers']! > coverage['membersScanned']! ||
      coverage['profiles']! > coverage['activeMembers']! ||
      coverage['claimsScanned']! > 2000 ||
      coverage['profiles']! > coverage['claimsScanned']!) {
    throw const FormatException('Check-in coverage mismatch');
  }
  final totals =
          _counts(m['totals'], {'claims', 'claimingMembers', 'pointsAwarded'}),
      active = coverage['activeMembers']!,
      claimants = totals['claimingMembers']!;
  if (totals['claims']! > coverage['claimsScanned']! ||
      totals['pointsAwarded'] != totals['claims']! * 50 ||
      claimants > totals['claims']! ||
      claimants > coverage['profiles']! ||
      (totals['claims'] == 0) != (claimants == 0)) {
    throw const FormatException('Check-in totals mismatch');
  }
  final streaks = _map(m['streaks']), asOf = _date(streaks['asOfDate']);
  if (DateTime.fromMillisecondsSinceEpoch(scan, isUtc: true)
          .add(const Duration(hours: 8))
          .toIso8601String()
          .substring(0, 10) !=
      streaks['asOfDate']) {
    throw const FormatException('Check-in streak date mismatch');
  }
  final current = _counts(
          streaks['current'], AdminCheckInReport.streakLabels.keys.toSet()),
      longest = _counts(
          streaks['longest'], AdminCheckInReport.streakLabels.keys.toSet());
  if (current.values.fold<int>(0, (a, b) => a + b) != active ||
      longest.values.fold<int>(0, (a, b) => a + b) != active ||
      longest['zero'] != active - coverage['profiles']! ||
      current['zero']! < longest['zero']!) {
    throw const FormatException('Check-in streak cohort mismatch');
  }
  List<CheckInReportPeriod> periods(Object? raw, bool weekly) {
    if (raw is! List || raw.length > 2000) {
      throw const FormatException('Invalid check-in periods');
    }
    final rows = <CheckInReportPeriod>[];
    String? previous;
    for (final v in raw) {
      final d = _map(v), parsed = _date(d['date']), label = d['date'] as String;
      if ((previous != null && previous.compareTo(label) >= 0) ||
          (weekly && parsed.weekday != DateTime.monday)) {
        throw const FormatException('Check-in period ordering mismatch');
      }
      final at =
          parsed.subtract(const Duration(hours: 8)).millisecondsSinceEpoch;
      if (at >= end ||
          at + (weekly ? 7 : 1) * 86400000 <= start ||
          parsed.isAfter(asOf)) {
        throw const FormatException('Check-in period outside query');
      }
      previous = label;
      final count = _int(d['claims']),
          unique = _int(d['claimingMembers']),
          points = _int(d['pointsAwarded']);
      if (count == 0 ||
          unique < 1 ||
          unique > count ||
          unique > active ||
          unique > claimants ||
          points != count * 50 ||
          (!weekly && unique != count)) {
        throw const FormatException('Check-in period totals mismatch');
      }
      rows.add(CheckInReportPeriod(
          date: label,
          claims: count,
          claimingMembers: unique,
          pointsAwarded: points));
    }
    if (rows.fold<int>(0, (n, r) => n + r.claims) != totals['claims']) {
      throw const FormatException('Check-in period sum mismatch');
    }
    return rows;
  }

  final daily = periods(m['daily'], false), weekly = periods(m['weekly'], true);
  final weeks = <String, List<CheckInReportPeriod>>{};
  for (final d in daily) {
    final parsed = _date(d.date),
        monday = parsed
            .subtract(Duration(days: parsed.weekday - 1))
            .toIso8601String()
            .substring(0, 10);
    weeks.putIfAbsent(monday, () => []).add(d);
  }
  if (weekly.length != weeks.length ||
      weekly.fold<int>(0, (n, w) => n + w.claimingMembers) < claimants) {
    throw const FormatException('Check-in unique week totals mismatch');
  }
  for (final w in weekly) {
    final days = weeks[w.date];
    if (days == null ||
        days.fold<int>(0, (n, d) => n + d.claims) != w.claims ||
        days.any((d) => d.claimingMembers > w.claimingMembers)) {
      throw const FormatException('Check-in daily/week mismatch');
    }
  }
  final extension = m['extensions'] == null
      ? null
      : AdminEngagementExtension.parse(m['extensions'], query, captured, scan);
  if (extension != null) {
    final checkIn =
        extension.sources.firstWhere((s) => s.id == 'daily_check_in');
    if (checkIn['claims'] != totals['claims'] ||
        checkIn['pointsAwarded'] != totals['pointsAwarded']) {
      throw const FormatException('Check-in earning source mismatch');
    }
  }
  return AdminCheckInReport(
      query: query,
      observations: m['observations'] == null
          ? null
          : AdminObservedActivity.parse(m['observations'], query, scan),
      extensions: extension,
      scanStartedAt: DateTime.fromMillisecondsSinceEpoch(scan, isUtc: true),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(captured, isUtc: true),
      asOfDate: streaks['asOfDate'] as String,
      claims: totals['claims']!,
      claimingMembers: claimants,
      pointsAwarded: totals['pointsAwarded']!,
      coverage: coverage,
      daily: daily,
      weekly: weekly,
      currentStreaks: current,
      longestStreaks: longest);
}
