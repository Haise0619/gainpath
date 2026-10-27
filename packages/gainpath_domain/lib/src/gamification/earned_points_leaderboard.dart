class EarnedPointsRank {
  const EarnedPointsRank(
      {required this.rank,
      required this.displayName,
      required this.points,
      required this.isYou});
  final int? rank;
  final String displayName;
  final int points;
  final bool isYou;
}

class EarnedPointsLeaderboard {
  const EarnedPointsLeaderboard(
      {required this.period,
      required this.entries,
      required this.you,
      required this.totalParticipants,
      required this.resolvedAtMillis,
      this.periodStartMillis,
      this.periodEndMillis});
  final String period;
  final List<EarnedPointsRank> entries;
  final EarnedPointsRank you;
  final int totalParticipants, resolvedAtMillis;
  final int? periodStartMillis, periodEndMillis;

  factory EarnedPointsLeaderboard.fromJson(Map<String, dynamic> d,
      {required String organizationId,
      required String memberId,
      required String period}) {
    bool n(Object? v) => v is int && v >= 0 && v <= 9007199254740991;
    Never fail() =>
        throw const FormatException('Invalid leaderboard response.');
    if (d['schemaVersion'] != 1 ||
        d['organizationId'] != organizationId ||
        d['memberId'] != memberId ||
        !['week', 'all_time'].contains(period) ||
        d['period'] != period ||
        d['timezone'] != 'Asia/Kuala_Lumpur' ||
        !n(d['resolvedAtMillis']) ||
        d['resolvedAtMillis'] == 0 ||
        d['resolvedAtMillis'] > 8639999990000000 ||
        !n(d['totalParticipants']) ||
        d['totalParticipants'] > 200 ||
        d['entries'] is! List) {
      fail();
    }
    final now = d['resolvedAtMillis'] as int,
        total = d['totalParticipants'] as int;
    const day = 86400000, offset = 28800000;
    final ordinal = (now + offset) ~/ day,
        weekday = DateTime.fromMillisecondsSinceEpoch(
                ((now + offset) ~/ day) * day,
                isUtc: true)
            .weekday;
    final start = (ordinal - weekday + 1) * day - offset;
    if (period == 'week'
        ? d['periodStartMillis'] != start ||
            d['periodEndMillis'] != start + 7 * day
        : d['periodStartMillis'] != null || d['periodEndMillis'] != null) {
      fail();
    }
    EarnedPointsRank parse(Object? raw, {bool own = false}) {
      if (raw is! Map) fail();
      final rank = raw['rank'],
          name = raw['displayName'],
          points = raw['points'],
          you = raw['isYou'];
      if (name is! String ||
          name.trim().isEmpty ||
          name.length > 60 ||
          name.contains('@') ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(name) ||
          !n(points) ||
          you is! bool ||
          (own && !you) ||
          (rank == null
              ? !own || points != 0
              : !n(rank) || rank == 0 || rank > total || points == 0)) {
        fail();
      }
      return EarnedPointsRank(
          rank: rank as int?,
          displayName: name,
          points: points as int,
          isYou: you);
    }

    final entries =
        (d['entries'] as List).map((v) => parse(v)).toList(growable: false);
    if (entries.length != (total < 20 ? total : 20)) fail();
    var lastPoints = 9007199254740991, lastRank = 0, ownCount = 0;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final expected = i > 0 && e.points == lastPoints ? lastRank : i + 1;
      if (e.points > lastPoints || e.rank != expected) fail();
      lastPoints = e.points;
      lastRank = e.rank!;
      if (e.isYou) ownCount++;
    }
    final you = parse(d['you'], own: true);
    if (ownCount > 1) fail();
    if (ownCount == 1) {
      final found = entries.singleWhere((e) => e.isYou);
      if (found.rank != you.rank ||
          found.points != you.points ||
          found.displayName != you.displayName) {
        fail();
      }
    } else if (you.rank != null &&
        (entries.length < 20 || you.points > entries.last.points)) {
      fail();
    }
    return EarnedPointsLeaderboard(
        period: period,
        entries: List.unmodifiable(entries),
        you: you,
        totalParticipants: total,
        resolvedAtMillis: now,
        periodStartMillis: d['periodStartMillis'] as int?,
        periodEndMillis: d['periodEndMillis'] as int?);
  }
}
