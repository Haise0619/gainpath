import 'admin_reporting_gateway.dart';

class CommerceRow {
  CommerceRow(this.id, this.name, this.values, this.daily);
  final String id, name;
  final Map<String, int> values;
  final List<Map<String, Object>> daily;
  int operator [](String key) => values[key] ?? 0;
}

/// Validated aggregate-only operational extension. Never contains Member rows.
class AdminCommerceReport {
  AdminCommerceReport(this.query, this.asOf, this.coaches, this.current,
      this.plans, this.coaching, this.previousAvailable, this.coverage);
  final AdminReportQuery query;
  final DateTime asOf;
  final List<CommerceRow> coaches;
  final Map<String, int> current, coverage;
  final List<CommerceRow> plans;
  final CommerceRow coaching;
  final bool previousAvailable;
  static Map<String, dynamic> map(Object? v) {
    if (v is! Map || v.keys.any((k) => k is! String)) {
      throw const FormatException('Invalid commerce aggregate');
    }
    return Map<String, dynamic>.from(v);
  }

  static int number(Object? v) {
    if (v is! num ||
        !v.isFinite ||
        v < 0 ||
        v > 9007199254740991 ||
        v != v.roundToDouble()) {
      throw const FormatException('Invalid commerce number');
    }
    return v.toInt();
  }

  static String text(Object? v) {
    if (v is! String || v.isEmpty || v.length > 200 || v.contains('\u0000')) {
      throw const FormatException('Invalid commerce label');
    }
    return v;
  }

  static List<dynamic> list(Object? v) {
    if (v is! List || v.length > 6000) {
      throw const FormatException('Invalid commerce rows');
    }
    return v;
  }

  static CommerceRow row(Object? raw, {required bool coach}) {
    final m = map(raw), values = <String, int>{};
    final keys = coach
        ? [
            'bookings',
            'confirmed',
            'completed',
            'cancelled',
            'expired',
            'pendingHold',
            'refunded',
            'consultations',
            'missingConsultations',
            'reviewCount',
            'ratingSum',
            'scheduledStarts'
          ]
        : [
            'purchases',
            'renewals',
            'confirmedMinor',
            'confirmedCount',
            'reviewMinor',
            'refundedMinor'
          ];
    for (final k in keys) {
      values[k] = number(m[k]);
    }
    if (coach) {
      if (values['bookings'] !=
          [
            'confirmed',
            'completed',
            'cancelled',
            'expired',
            'pendingHold',
            'refunded'
          ].fold<int>(0, (n, k) => n + values[k]!)) {
        throw const FormatException('Coach outcome mismatch');
      }
      if (values['missingConsultations']! > values['completed']!) {
        throw const FormatException('Consultation coverage mismatch');
      }
      if (values['ratingSum']! > values['reviewCount']! * 5 ||
          values['ratingSum']! < values['reviewCount']!) {
        throw const FormatException('Review sample mismatch');
      }
    } else {
      for (final e in map(m['statuses']).entries) {
        values['status:${e.key}'] = number(e.value);
      }
      for (final e in map(m['refundStatuses']).entries) {
        values['refund:${e.key}'] = number(e.value);
      }
      for (final e in map(m['previous']).entries) {
        values['previous:${e.key}'] = number(e.value);
      }
    }
    String? previous;
    final days = <Map<String, Object>>[];
    for (final rawDay in list(m['daily'])) {
      final d = map(rawDay), date = text(d['date']);
      final parsed = DateTime.tryParse('${date}T00:00:00Z');
      if (parsed == null ||
          parsed.toIso8601String().substring(0, 10) != date ||
          (previous != null && date.compareTo(previous) <= 0)) {
        throw const FormatException('Invalid commerce date');
      }
      previous = date;
      days.add({
        'date': date,
        for (final e in d.entries.where((e) => e.key != 'date'))
          e.key: number(e.value)
      });
    }
    return CommerceRow(
        coach ? text(m['coachId']) : text(m['planId']),
        coach ? text(m['name']) : text(m['planId']),
        Map.unmodifiable(values),
        List.unmodifiable(days));
  }

  factory AdminCommerceReport.parse(Object? raw, AdminReportQuery q) {
    final m = map(raw), membership = map(m['membership']);
    if (m['schemaVersion'] != 1 || membership['previousAvailable'] is! bool) {
      throw const FormatException('Unsupported commerce version');
    }
    final coaches = list(m['coaches']).map((v) => row(v, coach: true)).toList();
    final plans =
        list(membership['plans']).map((v) => row(v, coach: false)).toList();
    if (coaches.map((r) => r.id).toSet().length != coaches.length ||
        plans.map((r) => r.id).toSet().length != plans.length) {
      throw const FormatException('Duplicate commerce row');
    }
    final current = map(membership['current']);
    return AdminCommerceReport(
        q,
        DateTime.fromMillisecondsSinceEpoch(number(m['asOfMillis']),
            isUtc: true),
        List.unmodifiable(coaches),
        {
          for (final k in ['free', 'basic', 'premium', 'unknown'])
            k: number(current[k])
        },
        List.unmodifiable(plans),
        row({...map(membership['coaching']), 'planId': 'coaching'},
            coach: false),
        membership['previousAvailable'] as bool,
        {for (final e in map(m['coverage']).entries) e.key: number(e.value)});
  }
  List<List<Object?>> csv({required bool coach, String? filter}) {
    final selected = coach
        ? coaches.where((r) => filter == null || r.id == filter).toList()
        : [
            ...plans.where((r) => filter == null || r.id == filter),
            if (filter == null) coaching
          ];
    Object? safe(Object? v) =>
        v is String && RegExp(r'^[\s]*[=+@\-]').hasMatch(v) ? "'$v" : v;
    final rows = <List<Object?>>[
      [
        'GainPath',
        coach ? 'Coach performance' : 'Membership and Sandbox receipts'
      ],
      ['Timezone', 'Asia/Kuala_Lumpur'],
      ['Start inclusive UTC', query.range.start.toUtc().toIso8601String()],
      ['End exclusive UTC', query.range.end.toUtc().toIso8601String()],
      ['As of UTC', asOf.toIso8601String()],
      ['Selected filter', filter ?? 'All'],
      [
        'Basis',
        coach
            ? 'Booking outcomes: created cohort; consultation/review counts: event dates. Consultation completion rate = (completed outcomes - missing consultation records) / all created bookings; cancellation rate = cancelled / all created bookings.'
            : 'Current tier census ignores dates/plan filter. Confirmed Sandbox receipts exclude refund/reconciliation cases; not net revenue or profit. Approved refund is not transferred. Previous period uses the same duration.'
      ],
      if (!coach) ...[
        ['Current tier', 'Members'],
        for (final e in current.entries) [e.key, e.value]
      ],
      for (final r in selected) ...[
        [],
        ['ID', r.id, 'Label', r.name],
        ['Metric', 'Value'],
        for (final e in r.values.entries) [e.key, e.value],
        if (coach) ...[
          [
            'Consultation completion rate %',
            r['bookings'] == 0
                ? null
                : (r['completed'] - r['missingConsultations']) /
                    r['bookings'] *
                    100
          ],
          [
            'Cancellation rate %',
            r['bookings'] == 0 ? null : r['cancelled'] / r['bookings'] * 100
          ],
          [
            'Average review rating',
            r['reviewCount'] == 0 ? null : r['ratingSum'] / r['reviewCount']
          ],
        ],
        ['Malaysia date', 'Metric', 'Value'],
        for (final d in r.daily)
          for (final e in d.entries.where((e) => e.key != 'date'))
            [d['date'], e.key, e.value]
      ],
      [],
      ['Coverage source', 'Records'],
      for (final e in coverage.entries) [e.key, e.value]
    ];
    return [
      for (final r in rows) [for (final v in r) safe(v)]
    ];
  }
}
