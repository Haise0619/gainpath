import '../identity.dart' show SessionScope;
import 'mini_game_content.dart';

class MiniGameRewardGame {
  const MiniGameRewardGame(
      {this.gameId = MiniGameContent.supportedId,
      this.points = 20,
      this.dailyClaimLimit = 1});
  final String gameId;
  final int points, dailyClaimLimit;
  Map<String, dynamic> toJson() {
    if (gameId != MiniGameContent.supportedId ||
        points < 0 ||
        points > 1000 ||
        dailyClaimLimit < 0 ||
        dailyClaimLimit > 1) {
      throw const FormatException('Invalid mini-game reward limits.');
    }
    return {
      'gameId': gameId,
      'points': points,
      'dailyClaimLimit': dailyClaimLimit
    };
  }

  factory MiniGameRewardGame.fromJson(Map<String, dynamic> d) {
    if (d.length != 3 ||
        d['gameId'] is! String ||
        d['points'] is! int ||
        d['dailyClaimLimit'] is! int) {
      throw const FormatException('Invalid mini-game reward game.');
    }
    final g = MiniGameRewardGame(
        gameId: d['gameId'],
        points: d['points'],
        dailyClaimLimit: d['dailyClaimLimit']);
    g.toJson();
    return g;
  }
}

class MiniGameRewardPolicy {
  MiniGameRewardPolicy(
      {this.revision = 0,
      this.version = 'mini-game-rewards-draft-v1',
      this.dailyPointsCap = 60,
      Iterable<MiniGameRewardGame> games = const [MiniGameRewardGame()],
      this.updatedAtMillis = 0})
      : games = List.unmodifiable(games);
  factory MiniGameRewardPolicy.draft() => MiniGameRewardPolicy();
  final int revision, dailyPointsCap, updatedAtMillis;
  final String version;
  final List<MiniGameRewardGame> games;
  bool get enabled => false;
  String get timezone => 'Asia/Kuala_Lumpur';
  MiniGameRewardPolicy copyWith(
          {int? dailyPointsCap, Iterable<MiniGameRewardGame>? games}) =>
      MiniGameRewardPolicy(
          revision: revision,
          version: version,
          dailyPointsCap: dailyPointsCap ?? this.dailyPointsCap,
          games: games ?? this.games,
          updatedAtMillis: updatedAtMillis);
  Map<String, dynamic> toFields() {
    if (dailyPointsCap < 0 || dailyPointsCap > 10000 || games.length != 1) {
      throw const FormatException('Invalid shared mini-game reward cap.');
    }
    return {
      'dailyPointsCap': dailyPointsCap,
      'games': games.map((g) => g.toJson()).toList()
    };
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'revision': revision,
        'version': version,
        'enabled': false,
        'timezone': timezone,
        ...toFields(),
        'updatedAtMillis': updatedAtMillis
      };
  factory MiniGameRewardPolicy.fromJson(Map<String, dynamic> d) {
    const keys = {
      'schemaVersion',
      'revision',
      'version',
      'enabled',
      'timezone',
      'dailyPointsCap',
      'games',
      'updatedAtMillis'
    };
    final rev = d['revision'], at = d['updatedAtMillis'], rows = d['games'];
    if (d.length != keys.length ||
        !keys.every(d.containsKey) ||
        d['schemaVersion'] != 1 ||
        d['enabled'] != false ||
        d['timezone'] != 'Asia/Kuala_Lumpur' ||
        rev is! int ||
        rev < 0 ||
        rev > 9007199254740991 ||
        at is! int ||
        at < 0 ||
        at > 9007199254740991 ||
        (rev == 0) != (at == 0) ||
        d['version'] !=
            (rev == 0
                ? 'mini-game-rewards-draft-v1'
                : 'mini-game-rewards-v$rev') ||
        d['dailyPointsCap'] is! int ||
        rows is! List ||
        rows.any((r) => r is! Map)) {
      throw const FormatException('Invalid mini-game reward policy.');
    }
    final p = MiniGameRewardPolicy(
        revision: rev,
        version: d['version'],
        updatedAtMillis: at,
        dailyPointsCap: d['dailyPointsCap'],
        games: rows.map((r) =>
            MiniGameRewardGame.fromJson(Map<String, dynamic>.from(r as Map))));
    p.toFields();
    return p;
  }
}

class MiniGameRewardEligibility {
  const MiniGameRewardEligibility(
      {required this.gameId,
      required this.claimsToday,
      required this.eligible,
      required this.reason});
  final String gameId, reason;
  final int claimsToday;
  final bool eligible;
}

class MiniGameRewardStatus {
  MiniGameRewardStatus(
      {required this.scope,
      required this.today,
      required this.policy,
      required this.earnedPoints,
      required this.remainingPoints,
      required this.issuanceActive,
      required Iterable<MiniGameRewardEligibility> games})
      : games = List.unmodifiable(games);
  final SessionScope scope;
  final String today;
  final MiniGameRewardPolicy policy;
  final int earnedPoints, remainingPoints;
  final bool issuanceActive;
  final List<MiniGameRewardEligibility> games;
  String get timezone => 'Asia/Kuala_Lumpur';
  factory MiniGameRewardStatus.fromJson(
      Map<String, dynamic> d, SessionScope scope) {
    const keys = {
      'schemaVersion',
      'organizationId',
      'memberId',
      'timezone',
      'today',
      'policy',
      'earnedPoints',
      'remainingPoints',
      'issuanceActive',
      'games'
    };
    final day = d['today'],
        earned = d['earnedPoints'],
        remaining = d['remainingPoints'],
        rows = d['games'];
    final parsedDay =
        day is String ? DateTime.tryParse('${day}T00:00:00Z') : null;
    if (d.length != keys.length ||
        !keys.every(d.containsKey) ||
        d['schemaVersion'] != 1 ||
        d['organizationId'] != scope.organizationId ||
        d['memberId'] != scope.userId ||
        d['timezone'] != 'Asia/Kuala_Lumpur' ||
        day is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
        parsedDay == null ||
        parsedDay.toIso8601String().substring(0, 10) != day ||
        earned is! int ||
        earned < 0 ||
        earned > 9007199254740991 ||
        remaining is! int ||
        remaining < 0 ||
        d['issuanceActive'] != false ||
        d['policy'] is! Map ||
        rows is! List ||
        rows.length != 1) {
      throw const FormatException('Invalid mini-game reward overview.');
    }
    final policy = MiniGameRewardPolicy.fromJson(
        Map<String, dynamic>.from(d['policy'] as Map));
    if (remaining !=
        (policy.dailyPointsCap - earned).clamp(0, policy.dailyPointsCap)) {
      throw const FormatException('Invalid mini-game reward allowance.');
    }
    final games = <MiniGameRewardEligibility>[];
    for (final raw in rows) {
      if (raw is! Map ||
          raw.length != 4 ||
          raw['gameId'] != MiniGameContent.supportedId ||
          raw['claimsToday'] is! int ||
          raw['claimsToday'] < 0 ||
          raw['claimsToday'] > 9007199254740991 ||
          raw['eligible'] != false ||
          raw['reason'] != 'not-active') {
        throw const FormatException('Invalid mini-game reward eligibility.');
      }
      games.add(MiniGameRewardEligibility(
          gameId: raw['gameId'],
          claimsToday: raw['claimsToday'],
          eligible: false,
          reason: raw['reason']));
    }
    return MiniGameRewardStatus(
        scope: scope,
        today: day,
        policy: policy,
        earnedPoints: earned,
        remainingPoints: remaining,
        issuanceActive: false,
        games: games);
  }
}

abstract interface class MiniGameRewardStatusReader {
  SessionScope get scope;
  bool get current;
  Future<MiniGameRewardStatus> overview();
}

abstract interface class MiniGameRewardConfigurationRepository {
  SessionScope get scope;
  bool get current;
  Future<MiniGameRewardPolicy> loadPolicy();
  Future<MiniGameRewardPolicy> savePolicy(
      {required String requestId,
      required int baseRevision,
      required MiniGameRewardPolicy policy});
}

class MiniGameRewardConflict implements Exception {
  const MiniGameRewardConflict();
}

class MiniGameRewardSessionChanged implements Exception {
  const MiniGameRewardSessionChanged();
}

class MiniGameRewardUnavailable implements Exception {
  const MiniGameRewardUnavailable();
}
