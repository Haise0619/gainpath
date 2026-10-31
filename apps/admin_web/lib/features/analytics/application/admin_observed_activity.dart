import 'admin_reporting_gateway.dart';

class ObservedDay {
  ObservedDay(this.date, this.counts);
  final String date;
  final Map<String, int> counts;
  int operator [](String key) => counts[key]!;
}

class AdminObservedActivity {
  AdminObservedActivity(this.query, this.asOf, this.cohort, this.sources,
      this.daily, this.weekly, this.recency, this.returning);
  final AdminReportQuery query;
  final DateTime asOf;
  final int cohort;
  final Map<String, int> sources, recency;
  final List<ObservedDay> daily, weekly;
  final Map<String, dynamic> returning;
  static const sourceLabels = {
    'checkIns': 'Check-in claims',
    'bookings': 'Bookings created',
    'games': 'Recorded game starts',
    'workoutBackups': 'Backed-up camera captures'
  };
  static const recencyLabels = {
    'within7Days': 'Observed in last 7 calendar days',
    'days8To30': 'Last observed 8–30 days ago',
    'over30Days': 'Last observed 30+ calendar days ago',
    'noObservedActivity': 'No observed activity / unknown'
  };
  static Map<String, dynamic> map(Object? v) {
    if (v is! Map || v.keys.any((k) => k is! String)) {
      throw const FormatException('Invalid observed activity');
    }
    return Map<String, dynamic>.from(v);
  }

  static int number(Object? v) {
    if (v is! num ||
        !v.isFinite ||
        v < 0 ||
        v > 9007199254740991 ||
        v != v.roundToDouble()) {
      throw const FormatException('Invalid observed count');
    }
    return v.toInt();
  }

  static Map<String, int> counts(Object? v, Iterable<String> keys) {
    final m = map(v);
    if (m.length != keys.length || !m.keys.toSet().containsAll(keys)) {
      throw const FormatException('Invalid observed keys');
    }
    return m.map((k, v) => MapEntry(k, number(v)));
  }

  static AdminObservedActivity parse(
      Object? raw, AdminReportQuery q, int scan) {
    final m = map(raw),
        cohort = number(m['cohortMembers']),
        asOf = number(m['asOfMillis']);
    if (m['schemaVersion'] != 1 ||
        cohort > 200 ||
        asOf !=
            (q.range.end.millisecondsSinceEpoch - 1 < scan
                ? q.range.end.millisecondsSinceEpoch - 1
                : scan)) {
      throw const FormatException('Observed scope mismatch');
    }
    final span = q.range.end.difference(q.range.start).inMilliseconds;
    final expectedAvailable = q.range.start.millisecondsSinceEpoch >= span &&
        q.range.end.millisecondsSinceEpoch <= scan;
    final sources = counts(m['sourceCounts'], sourceLabels.keys),
        recency = counts(m['recency'], recencyLabels.keys),
        r = map(m['returning']);
    if (recency.values.fold<int>(0, (a, b) => a + b) != cohort ||
        r['available'] is! bool ||
        r['available'] != expectedAvailable) {
      throw const FormatException('Observed cohort mismatch');
    }
    for (final key in [
      'previousMembers',
      'currentMembers',
      'returningMembers'
    ]) {
      if (number(r[key]) > cohort) {
        throw const FormatException('Return cohort mismatch');
      }
    }
    final previous = number(r['previousMembers']),
        current = number(r['currentMembers']),
        both = number(r['returningMembers']);
    if (both > previous || both > current) {
      throw const FormatException('Return cohort mismatch');
    }
    final rate = r['ratePercent'];
    if (r['available'] == true && previous > 0) {
      if (rate is! num ||
          !rate.isFinite ||
          (rate - both / previous * 100).abs() > 0.00001) {
        throw const FormatException('Invalid return rate');
      }
    } else if (rate != null) {
      throw const FormatException('Unavailable return rate');
    }
    List<ObservedDay> days(Object? raw, bool weekly) {
      if (raw is! List || raw.length > 10000) {
        throw const FormatException('Invalid observation periods');
      }
      String prior = '';
      return raw.map((v) {
        final d = map(v), label = d['date'];
        if (label is! String ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(label) ||
            label.compareTo(prior) <= 0) {
          throw const FormatException('Invalid observation date');
        }
        final at = DateTime.tryParse('${label}T00:00:00Z');
        if (at == null ||
            at.toIso8601String().substring(0, 10) != label ||
            (weekly && at.weekday != 1)) {
          throw const FormatException('Invalid observation calendar');
        }
        final localStart = q.range.start.toUtc().add(const Duration(hours: 8));
        final localEnd = DateTime.fromMillisecondsSinceEpoch(asOf, isUtc: true)
            .add(const Duration(hours: 8));
        var first =
            DateTime.utc(localStart.year, localStart.month, localStart.day);
        var last = DateTime.utc(localEnd.year, localEnd.month, localEnd.day);
        if (weekly) {
          first = first.subtract(Duration(days: first.weekday - 1));
          last = last.subtract(Duration(days: last.weekday - 1));
        }
        if (at.isBefore(first) || at.isAfter(last)) {
          throw const FormatException('Observed period out of range');
        }
        prior = label;
        final values = counts(
            Map.fromEntries(d.entries.where((e) => e.key != 'date')),
            [...sourceLabels.keys, 'uniqueMembers']);
        if (values['uniqueMembers']! > cohort ||
            values['uniqueMembers']! >
                sourceLabels.keys.fold<int>(0, (n, k) => n + values[k]!)) {
          throw const FormatException('Invalid observed Members');
        }
        return ObservedDay(label, values);
      }).toList();
    }

    final daily = days(m['daily'], false), weekly = days(m['weekly'], true);
    for (final key in sourceLabels.keys) {
      if (daily.fold<int>(0, (n, d) => n + d[key]) != sources[key] ||
          weekly.fold<int>(0, (n, d) => n + d[key]) != sources[key]) {
        throw const FormatException('Observed totals mismatch');
      }
    }
    return AdminObservedActivity(
        q,
        DateTime.fromMillisecondsSinceEpoch(asOf, isUtc: true),
        cohort,
        sources,
        daily,
        weekly,
        recency,
        r);
  }

  List<List<Object?>> csv(
          {required bool retention, required bool weeklyView}) =>
      [
        [
          retention
              ? 'GainPath recorded engagement recency'
              : 'GainPath observable activity',
          'Current canonical active Member cohort'
        ],
        ['Timezone', 'Asia/Kuala_Lumpur'],
        ['Start inclusive UTC', query.range.start.toUtc().toIso8601String()],
        ['End exclusive UTC', query.range.end.toUtc().toIso8601String()],
        ['Observation cutoff UTC', asOf.toIso8601String()],
        ['Cohort Members', cohort],
        [
          'Coverage',
          'Recorded events only; not all app usage, logins, gym attendance or proven inactivity. Local-only play and device-only workouts excluded.'
        ],
        if (retention) ...[
          ['Recency', 'Members'],
          for (final e in recency.entries) [recencyLabels[e.key], e.value],
          ['Equal-period comparison available', returning['available']],
          ['Previous observed Members', returning['previousMembers']],
          ['Current observed Members', returning['currentMembers']],
          ['Returning Members', returning['returningMembers']],
          ['Return rate %', returning['ratePercent']],
          [
            'Return definition',
            'Members observed in both closed equal-duration periods / Members observed in preceding period; no dropout prediction.'
          ],
        ] else ...[
          [
            weeklyView ? 'Malaysia week starting Monday' : 'Malaysia date',
            ...sourceLabels.values,
            'Unique observed Members'
          ],
          for (final d in weeklyView ? weekly : daily)
            [d.date, ...sourceLabels.keys.map((k) => d[k]), d['uniqueMembers']],
        ]
      ];
}
