import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class AppCheckInUnavailable implements Exception {
  const AppCheckInUnavailable();
}

class AppCheckInClaim {
  const AppCheckInClaim(
      {required this.date, required this.points, required this.atMillis});
  final String date;
  final int points, atMillis;
}

class AppCheckInBadge {
  const AppCheckInBadge(
      {required this.id,
      required this.title,
      required this.requiredStreak,
      this.unlockedAtMillis});
  final String id, title;
  final int requiredStreak;
  final int? unlockedAtMillis;
}

class AppCheckInDay {
  const AppCheckInDay(this.date, this.claimed);
  final String date;
  final bool claimed;
}

class AppCheckInSnapshot {
  AppCheckInSnapshot(
      {required this.scope,
      required this.policyVersion,
      required this.timezone,
      required this.pointsPerClaim,
      required this.balance,
      required this.today,
      required this.claimedToday,
      required this.currentStreak,
      required this.longestStreak,
      required this.totalClaims,
      required this.serverNowMillis,
      required this.nextResetMillis,
      required Iterable<AppCheckInDay> days,
      required Iterable<AppCheckInClaim> recentClaims,
      required Iterable<AppCheckInBadge> badges})
      : days = List.unmodifiable(days),
        recentClaims = List.unmodifiable(recentClaims),
        badges = List.unmodifiable(badges);
  final SessionScope scope;
  final String policyVersion, timezone, today;
  final int pointsPerClaim,
      balance,
      currentStreak,
      longestStreak,
      totalClaims,
      serverNowMillis,
      nextResetMillis;
  final bool claimedToday;
  final List<AppCheckInDay> days;
  final List<AppCheckInClaim> recentClaims;
  final List<AppCheckInBadge> badges;
  factory AppCheckInSnapshot.fromJson(
      Map<String, dynamic> raw, SessionScope scope) {
    const keys = {
      'schemaVersion',
      'organizationId',
      'memberId',
      'policyVersion',
      'timezone',
      'pointsPerClaim',
      'balance',
      'today',
      'claimedToday',
      'currentStreak',
      'longestStreak',
      'totalClaims',
      'serverNowMillis',
      'nextResetMillis',
      'days',
      'recentClaims',
      'badges'
    };
    if (raw.length != keys.length ||
        !keys.every(raw.containsKey) ||
        raw['schemaVersion'] != 1 ||
        raw['organizationId'] != scope.organizationId ||
        raw['memberId'] != scope.userId ||
        raw['timezone'] != 'Asia/Kuala_Lumpur' ||
        raw['policyVersion'] != 'app-check-in-v1' ||
        raw['claimedToday'] is! bool) {
      throw const FormatException('Invalid check-in owner/policy');
    }
    int number(Object? v) {
      if (v is! int || v < 0 || v > 9007199254740991) {
        throw const FormatException('Invalid check-in integer');
      }
      return v;
    }

    DateTime day(Object? v) {
      if (v is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
        throw const FormatException('Invalid check-in date');
      }
      final d = DateTime.tryParse('${v}T00:00:00Z');
      if (d == null || d.toIso8601String().substring(0, 10) != v) {
        throw const FormatException('Invalid check-in day');
      }
      return d;
    }

    final now = number(raw['serverNowMillis']),
        next = number(raw['nextResetMillis']),
        today = day(raw['today']);
    final server = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true)
        .add(const Duration(hours: 8));
    if (server.toIso8601String().substring(0, 10) != raw['today'] ||
        next !=
            today
                .add(const Duration(days: 1))
                .subtract(const Duration(hours: 8))
                .millisecondsSinceEpoch ||
        next <= now ||
        raw['pointsPerClaim'] != 50) {
      throw const FormatException('Invalid check-in calendar');
    }
    final streak = number(raw['currentStreak']),
        longest = number(raw['longestStreak']),
        count = number(raw['totalClaims']);
    if (streak > longest || longest > count) {
      throw const FormatException('Invalid check-in streak');
    }
    final days = raw['days'],
        claims = raw['recentClaims'],
        badges = raw['badges'];
    if (days is! List ||
        days.length != 7 ||
        claims is! List ||
        claims.length > 50 ||
        badges is! List ||
        badges.length != 3) {
      throw const FormatException('Invalid check-in lists');
    }
    final parsedDays = <AppCheckInDay>[];
    for (var i = 0; i < 7; i++) {
      final d = Map<String, dynamic>.from(days[i] as Map);
      if (d.length != 2 ||
          d['claimed'] is! bool ||
          day(d['date']) != today.subtract(Duration(days: 6 - i))) {
        throw const FormatException('Invalid check-in strip');
      }
      parsedDays.add(AppCheckInDay(d['date'] as String, d['claimed'] as bool));
    }
    final parsedClaims = <AppCheckInClaim>[];
    final dates = <String>{};
    for (final value in claims) {
      final c = Map<String, dynamic>.from(value as Map);
      const fields = {
        'schemaVersion',
        'organizationId',
        'memberId',
        'date',
        'points',
        'claimedAtMillis',
        'policyVersion',
        'source'
      };
      if (c.length != fields.length ||
          !fields.every(c.containsKey) ||
          c['schemaVersion'] != 1 ||
          c['organizationId'] != scope.organizationId ||
          c['memberId'] != scope.userId ||
          c['points'] != 50 ||
          c['policyVersion'] != raw['policyVersion'] ||
          c['source'] != 'app_check_in') {
        throw const FormatException('Invalid claim receipt');
      }
      final d = day(c['date']);
      final time = number(c['claimedAtMillis']);
      final local = DateTime.fromMillisecondsSinceEpoch(time, isUtc: true)
          .add(const Duration(hours: 8));
      if (d.isAfter(today) ||
          time > now ||
          local.toIso8601String().substring(0, 10) != c['date'] ||
          !dates.add(c['date'] as String)) {
        throw const FormatException('Invalid claim chronology');
      }
      parsedClaims.add(AppCheckInClaim(
          date: c['date'] as String, points: 50, atMillis: time));
    }
    if (parsedDays.last.claimed != raw['claimedToday'] ||
        parsedClaims.length != count.clamp(0, 50) ||
        parsedDays.any((d) => d.claimed != dates.contains(d.date))) {
      throw const FormatException('Inconsistent check-in history');
    }
    final parsedBadges = <AppCheckInBadge>[];
    const ids = ['first-check-in', 'check-in-streak-3', 'check-in-streak-7'],
        targets = [1, 3, 7];
    for (var i = 0; i < 3; i++) {
      final b = Map<String, dynamic>.from(badges[i] as Map);
      final at = b['unlockedAtMillis'];
      if (b.length != 4 ||
          b['id'] != ids[i] ||
          b['requiredStreak'] != targets[i] ||
          b['title'] is! String ||
          (b['title'] as String).isEmpty ||
          (at != null && (number(at) > now || number(at) == 0)) ||
          ((at != null) != (longest >= targets[i]))) {
        throw const FormatException('Invalid check-in badge');
      }
      parsedBadges.add(AppCheckInBadge(
          id: ids[i],
          title: b['title'] as String,
          requiredStreak: targets[i],
          unlockedAtMillis: at as int?));
    }
    return AppCheckInSnapshot(
        scope: scope,
        policyVersion: raw['policyVersion'] as String,
        timezone: raw['timezone'] as String,
        pointsPerClaim: 50,
        balance: number(raw['balance']),
        today: raw['today'] as String,
        claimedToday: raw['claimedToday'] as bool,
        currentStreak: streak,
        longestStreak: longest,
        totalClaims: count,
        serverNowMillis: now,
        nextResetMillis: next,
        days: parsedDays,
        recentClaims: parsedClaims,
        badges: parsedBadges);
  }
}

class AppCheckInResult {
  const AppCheckInResult(this.snapshot, {required this.awarded});
  final AppCheckInSnapshot snapshot;
  final bool awarded;
}

abstract interface class AppCheckInRepository {
  SessionScope get scope;
  Future<AppCheckInResult> overview();
  Future<AppCheckInResult> claim();
}

typedef AppCheckInRepositoryFactory = Future<AppCheckInRepository> Function(
    SessionScope scope, SessionScope? Function() activeScope);
