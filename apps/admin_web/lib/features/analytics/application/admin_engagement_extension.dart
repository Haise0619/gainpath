import 'admin_reporting_gateway.dart';

/// Aggregate-only extension: no Member identifiers or game scores.
class EngagementRow {
  EngagementRow(this.id, this.label, Map<String, int> values)
      : values = Map.unmodifiable(values);
  final String id, label;
  final Map<String, int> values;
  int operator [](String key) => values[key]!;
}

class AdminEngagementExtension {
  AdminEngagementExtension._(
      this.query,
      this.redemptions,
      this.status,
      this.redemptionDays,
      this.rewards,
      this.games,
      this.gameDays,
      this.badges,
      this.sources,
      this.coverage,
      this.capturedAt,
      this.statusAsOf);
  final DateTime capturedAt, statusAsOf;
  final AdminReportQuery query;
  final Map<String, int> redemptions, status, coverage;
  final List<EngagementRow> redemptionDays, rewards, games, badges, sources;
  final Map<String, List<EngagementRow>> gameDays;
  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map || value.keys.any((k) => k is! String)) {
      throw const FormatException('Invalid engagement aggregate');
    }
    return Map<String, dynamic>.from(value);
  }

  static Map<String, int> _counts(
          Map<String, dynamic> raw, List<String> keys) =>
      Map.unmodifiable({for (final k in keys) k: _number(raw[k])});
  static int _number(Object? v) {
    if (v is! num ||
        !v.isFinite ||
        v < 0 ||
        v > 9007199254740991 ||
        v != v.roundToDouble()) {
      throw const FormatException('Invalid engagement count');
    }
    return v.toInt();
  }

  static String _text(Object? v) {
    if (v is! String || v.isEmpty || v.length > 150 || v.contains('\u0000')) {
      throw const FormatException('Invalid aggregate label');
    }
    return v;
  }

  static const redemptionKeys = [
    'issued',
    'collected',
    'expired',
    'pointsSpent'
  ];
  static const gameKeys = [
    'started',
    'completed',
    'abandoned',
    'open',
    'uniqueMembers',
    'awards',
    'pointsAwarded'
  ];
  static const gameDayKeys = [
    'started',
    'completed',
    'awards',
    'pointsAwarded'
  ];
  static const gameNames = {
    'move-catch-v1': 'Move & Catch',
    'reach-tap-v1': 'Reach & Tap'
  };
  static const badgeNames = {
    'first-check-in': 'First check-in',
    'check-in-streak-3': 'Three-day streak',
    'check-in-streak-7': 'Seven-day streak'
  };
  factory AdminEngagementExtension.parse(
      Object? value, AdminReportQuery query, int captured, int scan) {
    final raw = _map(value);
    if (raw['schemaVersion'] != 1) {
      throw const FormatException('Unsupported engagement version');
    }
    final coverage =
        _counts(_map(raw['sourceCounts']), ['redemptions', 'rounds', 'awards']);
    if (coverage.values.any((n) => n > 2000)) {
      throw const FormatException('Source cap exceeded');
    }
    List<EngagementRow> rows(Object? value, String identity, List<String> keys,
        {String? title, bool dates = false}) {
      if (value is! List || value.length > 2000) {
        throw const FormatException('Invalid aggregate rows');
      }
      final ids = <String>{};
      String? previous;
      return List.unmodifiable(value.map((v) {
        final m = _map(v), id = _text(m[identity]);
        if (!ids.add(id)) {
          throw const FormatException('Duplicate aggregate row');
        }
        if (dates) {
          final d = DateTime.tryParse('$id' 'T00:00:00Z');
          final from = query.range.start
              .toUtc()
              .add(const Duration(hours: 8))
              .toIso8601String()
              .substring(0, 10);
          final until = query.range.end
              .toUtc()
              .subtract(const Duration(milliseconds: 1))
              .add(const Duration(hours: 8))
              .toIso8601String()
              .substring(0, 10);
          if (d == null ||
              d.toIso8601String().substring(0, 10) != id ||
              id.compareTo(from) < 0 ||
              id.compareTo(until) > 0 ||
              id.compareTo(
                      DateTime.fromMillisecondsSinceEpoch(captured, isUtc: true)
                          .add(const Duration(hours: 8))
                          .toIso8601String()
                          .substring(0, 10)) >
                  0 ||
              (previous != null && id.compareTo(previous!) <= 0)) {
            throw const FormatException('Invalid trend date');
          }
          previous = id;
        }
        return EngagementRow(
            id, title == null ? id : _text(m[title]), _counts(m, keys));
      }));
    }

    final r = _map(raw['redemptions']),
        totals = _counts(r, redemptionKeys),
        status = _counts(_map(r['issuedStatus']),
            ['outstanding', 'collected', 'expired', 'expiryUnknown']);
    final days = rows(r['daily'], 'date', redemptionKeys, dates: true);
    final rewards = rows(
        r['rewards'], 'itemId', ['issued', 'collected', 'pointsSpent'],
        title: 'title');
    for (final key in redemptionKeys) {
      if (days.fold<int>(0, (n, d) => n + d[key]) != totals[key]) {
        throw const FormatException('Redemption trend mismatch');
      }
    }
    if (status.values.fold<int>(0, (n, v) => n + v) != totals['issued'] ||
        totals['issued']! > coverage['redemptions']! ||
        rewards.fold<int>(0, (n, r) => n + r['issued']) != totals['issued'] ||
        rewards.fold<int>(0, (n, r) => n + r['pointsSpent']) !=
            totals['pointsSpent'] ||
        rewards.fold<int>(0, (n, r) => n + r['collected']) !=
            totals['collected']) {
      throw const FormatException('Redemption totals mismatch');
    }
    final games = rows(raw['games'], 'gameId', gameKeys),
        gameDays = <String, List<EngagementRow>>{};
    if (games.length != 2 || games.any((g) => !gameNames.containsKey(g.id))) {
      throw const FormatException('Unsupported game aggregate');
    }
    for (final v in raw['games'] as List) {
      final m = _map(v), id = m['gameId'] as String;
      gameDays[id] = rows(m['daily'], 'date', gameDayKeys, dates: true);
      final g = games.firstWhere((g) => g.id == id);
      for (final key in gameDayKeys) {
        if (gameDays[id]!.fold<int>(0, (n, d) => n + d[key]) != g[key]) {
          throw const FormatException('Game trend mismatch');
        }
      }
      if (g['uniqueMembers'] > g['started'] ||
          g['awards'] > coverage['awards']! ||
          g['started'] > coverage['rounds']! ||
          g['completed'] > coverage['rounds']! ||
          g['abandoned'] + g['open'] > g['started']) {
        throw const FormatException('Game coverage mismatch');
      }
    }
    final badges = rows(raw['badges'], 'badgeId', ['unlocks']);
    if (badges.any((b) => !badgeNames.containsKey(b.id))) {
      throw const FormatException('Unsupported badge');
    }
    final sources =
        rows(raw['earningSources'], 'source', ['claims', 'pointsAwarded']);
    if (sources.length != 3 ||
        sources.any(
            (s) => s.id != 'daily_check_in' && !gameNames.containsKey(s.id))) {
      throw const FormatException('Unsupported earning source');
    }
    for (final g in games) {
      final source = sources.firstWhere((s) => s.id == g.id);
      if (source['claims'] != g['awards'] ||
          source['pointsAwarded'] != g['pointsAwarded']) {
        throw const FormatException('Earning source mismatch');
      }
    }
    return AdminEngagementExtension._(
        query,
        totals,
        status,
        days,
        rewards,
        games,
        Map.unmodifiable(gameDays),
        badges,
        sources,
        coverage,
        DateTime.fromMillisecondsSinceEpoch(captured, isUtc: true),
        DateTime.fromMillisecondsSinceEpoch(scan, isUtc: true));
  }
  List<List<Object?>> _scope(String report) => [
        [report],
        ['Captured UTC', capturedAt.toUtc().toIso8601String()],
        [
          'Status as of source scan start UTC',
          statusAsOf.toUtc().toIso8601String()
        ],
        ['Timezone', 'Asia/Kuala_Lumpur UTC+08:00'],
        ['Start inclusive UTC', query.range.start.toUtc().toIso8601String()],
        ['End exclusive UTC', query.range.end.toUtc().toIso8601String()],
      ];
  List<List<Object?>> redemptionCsv() => _safe([
        ..._scope('GainPath reward redemption analytics'),
        [
          'Basis',
          'Organization-wide historical voucher ledger, including inactive Members. Issued/points spent by issue time; collection by fulfilment time; expiry by expiry time. Issued-cohort statuses as of source scan start. Legacy missing expiry remains unknown.'
        ],
        ['Metric', 'Count / points'],
        for (final e in redemptions.entries) [e.key, e.value],
        ['Issued-cohort status', 'Count'],
        for (final e in status.entries) [e.key, e.value],
        ['Malaysia day', ...redemptionKeys],
        for (final d in redemptionDays)
          [d.id, for (final k in redemptionKeys) d[k]],
        ['Reward ID', 'Reward', 'Issued', 'Collected', 'Points spent'],
        for (final r in rewards)
          [r.id, r.label, r['issued'], r['collected'], r['pointsSpent']],
      ]);
  List<List<Object?>> engagementCsv() => _safe([
        [
          'Recorded game activity',
          'Local-only play is not visible; Game Score excluded. Recorded participation is not physically verified.'
        ],
        ['Game', ...gameKeys],
        for (final g in games)
          [gameNames[g.id], for (final k in gameKeys) g[k]],
        ['Game', 'Malaysia day', ...gameDayKeys],
        for (final g in games)
          for (final d in gameDays[g.id]!)
            [gameNames[g.id], d.id, for (final k in gameDayKeys) d[k]],
        ['Earning source', 'Confirmed awards', 'Reward Points'],
        for (final s in sources) [s.id, s['claims'], s['pointsAwarded']],
        ['Badge', 'Unlocks in selected range'],
        for (final b in badges) [badgeNames[b.id], b['unlocks']],
        ['Scanned sources', 'Count'],
        for (final e in coverage.entries) [e.key, e.value],
      ]);
  static List<List<Object?>> _safe(List<List<Object?>> rows) => [
        for (final row in rows)
          [
            for (final v in row)
              if (v is String) _cell(v) else v
          ]
      ];
  static String _cell(String v) {
    final s = v.replaceAll(RegExp(r'[\r\n]'), ' ');
    return RegExp(r'^\s*[=+@\-]').hasMatch(s) ? "'$s" : s;
  }
}
