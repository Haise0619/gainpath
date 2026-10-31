import '../../features/analytics/application/admin_commerce_report.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope, Money;
import '../../features/analytics/application/admin_reporting_gateway.dart';
import '../../features/analytics/application/admin_operational_metrics.dart';
import '../../features/analytics/application/admin_workout_reporting.dart';
import 'firebase_admin_workout_report.dart';
import '../../features/analytics/application/admin_check_in_reporting.dart';
import 'firebase_admin_check_in_report.dart';

typedef AdminReportingInvoke = Future<Object?> Function(
    Map<String, Object?> input);

class FirebaseAdminReportingGateway
    implements
        OperationalAdminReportingGateway,
        AdminReportingSessionGuard,
        AdminWorkoutReportingGateway,
        AdminCheckInReportingGateway {
  FirebaseAdminReportingGateway(
      {required this.scope,
      required this.isCurrent,
      String? Function()? currentUid,
      AdminReportingInvoke? invoke,
      AdminReportingInvoke? workoutInvoke,
      AdminReportingInvoke? checkInInvoke})
      : _uid = currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _invoke = invoke ?? _call,
        _workoutInvoke = workoutInvoke ?? _callWorkouts,
        _checkInInvoke = checkInInvoke ?? _callCheckIns;
  final SessionScope scope;
  final bool Function() isCurrent;
  final String? Function() _uid;
  final AdminReportingInvoke _invoke;
  final AdminReportingInvoke _workoutInvoke;
  final AdminReportingInvoke _checkInInvoke;
  static Future<Object?> _callCheckIns(Map<String, Object?> input) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      functions.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '127.0.0.1'),
          5001);
    }
    return (await functions
            .httpsCallable('adminCheckInReportingCommand',
                options:
                    HttpsCallableOptions(timeout: const Duration(seconds: 60)))
            .call<Object?>(input))
        .data;
  }

  final Map<AdminReportQuery, Future<AdminCheckInReport>> _pendingCheckIns = {};
  @override
  Future<AdminCheckInReport> loadCheckIns(AdminReportQuery query) {
    _check();
    final pending = _pendingCheckIns[query];
    if (pending != null) return pending;
    late final Future<AdminCheckInReport> request;
    request = _loadCheckIns(query).whenComplete(() {
      if (identical(_pendingCheckIns[query], request)) {
        _pendingCheckIns.remove(query);
      }
    });
    _pendingCheckIns[query] = request;
    return request;
  }

  Future<AdminCheckInReport> _loadCheckIns(AdminReportQuery query) async {
    _check();
    if (query.branchId != null) {
      throw const AdminCheckInReportException(
          'App check-in analytics is organization-wide. Select all branches.');
    }
    try {
      final input = <String, Object?>{
        'schemaVersion': 3,
        'organizationId': scope.organizationId,
        'startAtMillis': query.range.start.toUtc().millisecondsSinceEpoch,
        'endAtMillis': query.range.end.toUtc().millisecondsSinceEpoch
      };
      Object? raw;
      try {
        raw = await _checkInInvoke(input);
      } on FirebaseFunctionsException catch (e) {
        if (e.code != 'invalid-argument') rethrow;
        _check();
        try {
          raw = await _checkInInvoke({...input, 'schemaVersion': 2});
        } on FirebaseFunctionsException catch (legacy) {
          if (legacy.code != 'invalid-argument') rethrow;
          _check();
          raw = await _checkInInvoke({...input, 'schemaVersion': 1});
        }
      }
      _check();
      return parseAdminCheckInReport(raw, scope, query);
    } on FirebaseFunctionsException catch (e) {
      _check();
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        throw const AdminReportingException(
            'Your reporting access changed. Sign in again.',
            invalidatesSnapshot: true);
      }
      if (e.code == 'failed-precondition') {
        throw const AdminReportingException(
            'Reporting sources need review. Retry; no partial totals were returned.');
      }
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        throw const AdminCheckInReportException(
            'Check-in analytics is awaiting server activation.');
      }
      if (e.code == 'resource-exhausted') {
        throw const AdminCheckInReportException(
            'Check-in analytics exceeds its source scan limit. An authorized source review is required.');
      }
      rethrow;
    }
  }

  static Future<Object?> _callWorkouts(Map<String, Object?> input) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      functions.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '127.0.0.1'),
          5001);
    }
    return (await functions
            .httpsCallable('adminWorkoutReportingCommand',
                options:
                    HttpsCallableOptions(timeout: const Duration(seconds: 60)))
            .call<Object?>(input))
        .data;
  }

  @override
  Future<AdminWorkoutReport> loadWorkouts(AdminReportQuery query) async {
    _check();
    if (query.branchId != null) {
      throw const AdminWorkoutReportException(
          'Workout backups are organization-wide. Select all branches.');
    }
    try {
      final raw = await _workoutInvoke({
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        'startAtMillis': query.range.start.toUtc().millisecondsSinceEpoch,
        'endAtMillis': query.range.end.toUtc().millisecondsSinceEpoch
      });
      _check();
      return parseAdminWorkoutReport(raw, scope, query);
    } on FirebaseFunctionsException catch (e) {
      _check();
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        throw const AdminReportingException(
            'Your reporting access changed. Sign in again.',
            invalidatesSnapshot: true);
      }
      if (e.code == 'failed-precondition') {
        throw const AdminReportingException(
            'Reporting sources need review. Retry; no partial totals were returned.');
      }
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        throw const AdminWorkoutReportException(
            'Workout analytics is awaiting server activation.');
      }
      if (e.code == 'resource-exhausted') {
        throw const AdminWorkoutReportException(
            'Workout analytics exceeds its source scan limit. An authorized source review is required.');
      }
      rethrow;
    }
  }

  static Future<Object?> _call(Map<String, Object?> input) async {
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      functions.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '127.0.0.1'),
          5001);
    }
    return (await functions
            .httpsCallable('adminReportingCommand',
                options:
                    HttpsCallableOptions(timeout: const Duration(seconds: 60)))
            .call<Object?>(input))
        .data;
  }

  @override
  bool get canRetainSnapshot => isCurrent() && _uid() == scope.userId;

  void _check() {
    if (!isCurrent() || _uid() != scope.userId) {
      throw StateError('Reporting account changed');
    }
  }

  @override
  Future<AdminReportingSnapshot> load(AdminReportQuery query) async {
    _check();
    if (query.branchId != null) {
      return AdminReportingSnapshot.unavailable(
          query: query,
          reason:
              'Branch allocation is unavailable; membership is organization-wide. Select all branches.');
    }
    final start = query.range.start.toUtc().millisecondsSinceEpoch,
        end = query.range.end.toUtc().millisecondsSinceEpoch;
    Object? raw;
    try {
      raw = await _invoke({
        'schemaVersion': 2,
        'organizationId': scope.organizationId,
        'startAtMillis': start,
        'endAtMillis': end
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'invalid-argument') {
        _check();
        final legacy = await _invoke({
          'schemaVersion': 1,
          'organizationId': scope.organizationId,
          'startAtMillis': start,
          'endAtMillis': end
        });
        _check();
        return parseAdminOperationalReport(legacy, scope, query);
      }

      _check();
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        throw const AdminReportingException(
            'Your reporting access changed. Sign in again.',
            invalidatesSnapshot: true);
      }
      if (e.code == 'failed-precondition') {
        throw const AdminReportingException(
            'Reporting sources need review. Retry; no partial totals were returned.');
      }
      throw AdminReportingException(switch (e.code) {
        'permission-denied' ||
        'unauthenticated' =>
          'Your reporting access changed. Sign in again.',
        'resource-exhausted' =>
          'The reporting source scan limit was reached. An authorized source review is needed.',
        'failed-precondition' =>
          'Reporting sources need review. Retry; no partial totals were returned.',
        'not-found' ||
        'unimplemented' =>
          'This reporting service is not available yet.',
        _ =>
          'Reports are temporarily unavailable. Check your connection and retry.',
      });
    }
    _check();
    return parseAdminOperationalReport(raw, scope, query);
  }
}

int _int(Object? raw) {
  if (raw is! num ||
      !raw.isFinite ||
      raw < 0 ||
      raw > 9007199254740991 ||
      raw != raw.roundToDouble()) {
    throw const FormatException('Invalid report integer');
  }
  return raw.toInt();
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map || raw.keys.any((k) => k is! String)) {
    throw const FormatException('Invalid report object');
  }
  return Map<String, dynamic>.from(raw);
}

Map<String, int> _counts(Object? raw, Set<String> keys) {
  final m = _map(raw);
  if (m.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(m.keys.toSet()).isNotEmpty) {
    throw const FormatException('Invalid report keys');
  }
  return m.map((k, v) => MapEntry(k, _int(v)));
}

AdminReportingSnapshot parseAdminOperationalReport(
    Object? raw, SessionScope scope, AdminReportQuery query) {
  final m = _map(raw),
      start = query.range.start.toUtc().millisecondsSinceEpoch,
      end = query.range.end.toUtc().millisecondsSinceEpoch;
  if (m['schemaVersion'] != 1 ||
      m['organizationId'] != scope.organizationId ||
      m['startAtMillis'] != start ||
      m['endAtMillis'] != end ||
      m['timezone'] != 'Asia/Kuala_Lumpur' ||
      m['environment'] != 'sandbox') {
    throw const FormatException('Report scope mismatch');
  }
  final captured = _int(m['capturedAtMillis']),
      scan = _int(m['sourceReadStartedAtMillis']);
  if (captured < scan || captured > 8640000000000000) {
    throw const FormatException('Invalid report time');
  }
  final accounts = _counts(m['currentAccounts'], {'members', 'coaches'}),
      bookings = _map(m['bookings']);
  final created = _int(bookings['created']),
      scheduled = _int(bookings['scheduledStarts']);
  final statuses = _counts(bookings['statuses'], {
    'pending_hold',
    'confirmed',
    'cancelled',
    'expired',
    'completed',
    'refunded'
  });
  if (statuses.values.fold<int>(0, (n, v) => n + v) != created) {
    throw const FormatException('Booking totals mismatch');
  }
  final receipts = _counts(m['receipts'], {
    'confirmedMinor',
    'membershipMinor',
    'coachingMinor',
    'confirmedCount',
    'reviewMinor',
    'reviewCount',
    'refundedMinor',
    'refundedCount'
  });
  if (receipts['confirmedMinor'] !=
      receipts['membershipMinor']! + receipts['coachingMinor']!) {
    throw const FormatException('Receipt total mismatch');
  }
  final sources =
      _counts(m['sourceCounts'], {'members', 'bookings', 'transactions'});
  if (sources.values.any((n) => n > 2000) ||
      accounts.values.fold<int>(0, (n, v) => n + v) > sources['members']! ||
      created > sources['bookings']! ||
      scheduled > sources['bookings']! ||
      receipts['confirmedCount']! +
              receipts['reviewCount']! +
              receipts['refundedCount']! >
          sources['transactions']!) {
    throw const FormatException('Incomplete report sources');
  }
  final dailyRaw = m['daily'];
  if (dailyRaw is! List || dailyRaw.length > 6000) {
    throw const FormatException('Invalid report days');
  }
  final days = <AdminOperationalDay>[];
  String? previous;
  for (final rawDay in dailyRaw) {
    final d = _map(rawDay), date = d['date'];
    if (date is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        (previous != null && date.compareTo(previous) <= 0)) {
      throw const FormatException('Invalid date ordering');
    }
    final parsed = DateTime.tryParse('${date}T00:00:00Z');
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != date) {
      throw const FormatException('Invalid report date');
    }
    final dayStart = parsed.subtract(adminReportZone).millisecondsSinceEpoch;
    if (dayStart >= end || dayStart + 86400000 <= start) {
      throw const FormatException('Report date outside query');
    }
    previous = date;
    final r = AdminOperationalDay(
        date: date,
        bookingsCreated: _int(d['bookingsCreated']),
        scheduledStarts: _int(d['scheduledStarts']),
        receiptsMinor: _int(d['receiptsMinor']),
        membershipMinor: _int(d['membershipMinor']),
        coachingMinor: _int(d['coachingMinor']));
    if (r.receiptsMinor != r.membershipMinor + r.coachingMinor) {
      throw const FormatException('Daily receipt mismatch');
    }
    days.add(r);
  }
  int sum(int Function(AdminOperationalDay) pick) =>
      days.fold(0, (n, d) => n + pick(d));
  if (sum((d) => d.bookingsCreated) != created ||
      sum((d) => d.scheduledStarts) != scheduled ||
      sum((d) => d.receiptsMinor) != receipts['confirmedMinor'] ||
      sum((d) => d.membershipMinor) != receipts['membershipMinor'] ||
      sum((d) => d.coachingMinor) != receipts['coachingMinor']) {
    throw const FormatException('Daily totals mismatch');
  }
  final unsupported = m['unsupported'];
  if (unsupported is! List || unsupported.any((v) => v is! String)) {
    throw const FormatException('Unsupported metrics required');
  }
  final ops = AdminOperationalMetrics(
      scheduledStarts: scheduled,
      statuses: statuses,
      membershipMinor: receipts['membershipMinor']!,
      coachingMinor: receipts['coachingMinor']!,
      confirmedCount: receipts['confirmedCount']!,
      reviewMinor: receipts['reviewMinor']!,
      reviewCount: receipts['reviewCount']!,
      refundedMinor: receipts['refundedMinor']!,
      refundedCount: receipts['refundedCount']!,
      sourceReadStartedAt:
          DateTime.fromMillisecondsSinceEpoch(scan, isUtc: true),
      sourceCounts: sources,
      daily: days,
      unsupported: unsupported.cast<String>());
  return AdminReportingSnapshot(
      query: query,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(captured, isUtc: true),
      operations: ops,
      commerce: m['commerce'] == null
          ? null
          : AdminCommerceReport.parse(m['commerce'], query),
      totalRevenue:
          Money(currency: 'MYR', minorUnits: receipts['confirmedMinor']!),
      activeMembersCount: accounts['members'],
      activeCoachesCount: accounts['coaches'],
      totalBookingsCount: created,
      revenueTrend: days
          .map((d) => ReportingPoint(
              date: DateTime.parse('${d.date}T00:00:00Z')
                  .subtract(adminReportZone),
              value: d.receiptsMinor,
              label: d.date))
          .toList(),
      bookingsTimeline: days
          .map((d) => ReportingPoint(
              date: DateTime.parse('${d.date}T00:00:00Z')
                  .subtract(adminReportZone),
              value: d.bookingsCreated,
              label: d.date))
          .toList());
}
