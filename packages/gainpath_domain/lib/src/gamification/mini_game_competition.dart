import '../identity.dart' show SessionScope;

const miniGameCompetitionPolicyVersion = 'game-competition-v1';
const miniGameCompetitionTrustLabel =
    'Gameplay results · not physically verified';
const competitiveGameIds = {'move-catch-v1', 'reach-tap-v1'};

class MiniGameCompetitionPreference {
  const MiniGameCompetitionPreference(
      {required this.scope,
      required this.enabled,
      required this.revision,
      required this.changedAtMillis});
  final SessionScope scope;
  final bool enabled;
  final int revision, changedAtMillis;
  factory MiniGameCompetitionPreference.fromJson(
      Map<String, dynamic> d, SessionScope scope) {
    if (d.length != 7 ||
        d['schemaVersion'] != 1 ||
        d['organizationId'] != scope.organizationId ||
        d['memberId'] != scope.userId ||
        d['policyVersion'] != miniGameCompetitionPolicyVersion ||
        d['enabled'] is! bool ||
        !_integer(d['revision'], 0) ||
        !_integer(d['changedAtMillis'], 0)) {
      throw const FormatException('Invalid competition preference.');
    }
    return MiniGameCompetitionPreference(
        scope: scope,
        enabled: d['enabled'],
        revision: d['revision'],
        changedAtMillis: d['changedAtMillis']);
  }
}

class MiniGameScoreEvent {
  const MiniGameScoreEvent(
      {required this.sequence, required this.activeMillis, required this.type});
  final int sequence, activeMillis;
  final String type;
  Map<String, dynamic> toJson() =>
      {'sequence': sequence, 'activeMillis': activeMillis, 'type': type};
}

class MiniGameAcceptedScore {
  const MiniGameAcceptedScore(
      {required this.scope,
      required this.gameId,
      required this.attemptId,
      required this.score,
      required this.acceptedAtMillis});
  final SessionScope scope;
  final String gameId, attemptId;
  final int score, acceptedAtMillis;
  factory MiniGameAcceptedScore.fromJson(
      Map<String, dynamic> d, SessionScope scope) {
    if (d.length != 9 ||
        d['schemaVersion'] != 1 ||
        d['organizationId'] != scope.organizationId ||
        d['memberId'] != scope.userId ||
        !competitiveGameIds.contains(d['gameId']) ||
        !_hex(d['attemptId']) ||
        !_integer(d['score'], 0, 4000) ||
        !_integer(d['acceptedAtMillis'], 1) ||
        d['physicalVerified'] != false ||
        d['pointsAwarded'] != 0) {
      throw const FormatException('Invalid accepted game score.');
    }
    return MiniGameAcceptedScore(
        scope: scope,
        gameId: d['gameId'],
        attemptId: d['attemptId'],
        score: d['score'],
        acceptedAtMillis: d['acceptedAtMillis']);
  }
}

class MiniGameScoreRank {
  const MiniGameScoreRank(
      {required this.rank,
      required this.displayName,
      required this.score,
      required this.isYou});
  final int? rank, score;
  final String displayName;
  final bool isYou;
  factory MiniGameScoreRank.fromJson(Map<String, dynamic> d) {
    if (d.length != 4 ||
        (d['rank'] != null && !_integer(d['rank'], 1)) ||
        (d['score'] != null && !_integer(d['score'], 0, 4000)) ||
        (d['rank'] == null) != (d['score'] == null) ||
        d['displayName'] is! String ||
        (d['displayName'] as String).isEmpty ||
        (d['displayName'] as String).length > 60 ||
        d['isYou'] is! bool) {
      throw const FormatException('Invalid game rank.');
    }
    return MiniGameScoreRank(
        rank: d['rank'],
        displayName: d['displayName'],
        score: d['score'],
        isYou: d['isYou']);
  }
}

class MiniGameScoreLeaderboard {
  const MiniGameScoreLeaderboard(
      {required this.scope,
      required this.gameId,
      required this.period,
      required this.periodKey,
      required this.entries,
      required this.you,
      required this.totalParticipants,
      required this.resolvedAtMillis});
  final SessionScope scope;
  final String gameId, period, periodKey;
  final List<MiniGameScoreRank> entries;
  final MiniGameScoreRank you;
  final int totalParticipants, resolvedAtMillis;
  factory MiniGameScoreLeaderboard.fromJson(
      Map<String, dynamic> d, SessionScope scope) {
    if (d.length != 12 ||
        d['schemaVersion'] != 1 ||
        d['organizationId'] != scope.organizationId ||
        d['memberId'] != scope.userId ||
        !competitiveGameIds.contains(d['gameId']) ||
        !{'week', 'all-time'}.contains(d['period']) ||
        d['periodKey'] is! String ||
        d['scoringVersion'] != 1 ||
        d['trustLabel'] != miniGameCompetitionTrustLabel ||
        !_integer(d['totalParticipants'], 0, 5000) ||
        !_integer(d['resolvedAtMillis'], 1) ||
        d['entries'] is! List ||
        (d['entries'] as List).length > 20 ||
        d['you'] is! Map) {
      throw const FormatException('Invalid game standings.');
    }
    final rows = (d['entries'] as List)
        .map((e) =>
            MiniGameScoreRank.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
    final you = MiniGameScoreRank.fromJson(Map<String, dynamic>.from(d['you']));
    if (!you.isYou ||
        rows.any((e) => e.rank == null) ||
        rows.length > d['totalParticipants']) {
      throw const FormatException('Invalid personal rank.');
    }
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].rank! > i + 1 ||
          (i > 0 &&
              (rows[i].score! > rows[i - 1].score! ||
                  (rows[i].score == rows[i - 1].score &&
                      rows[i].rank != rows[i - 1].rank) ||
                  (rows[i].score != rows[i - 1].score &&
                      rows[i].rank != i + 1)))) {
        throw const FormatException('Unordered game standings.');
      }
    }
    return MiniGameScoreLeaderboard(
        scope: scope,
        gameId: d['gameId'],
        period: d['period'],
        periodKey: d['periodKey'],
        entries: List.unmodifiable(rows),
        you: you,
        totalParticipants: d['totalParticipants'],
        resolvedAtMillis: d['resolvedAtMillis']);
  }
}

abstract interface class MiniGameCompetitionRepository {
  SessionScope get scope;
  bool get current;
  Future<MiniGameCompetitionPreference> preference();
  Future<MiniGameCompetitionPreference> setPreference({required bool enabled});
  Future<MiniGameScoreLeaderboard> leaderboard(
      {required String gameId, required String period});
  Future<MiniGameAcceptedScore> submit(
      {required String gameId,
      required String attemptId,
      required String challengeToken,
      required List<MiniGameScoreEvent> events});
}

class MiniGameCompetitionSessionChanged implements Exception {
  const MiniGameCompetitionSessionChanged();
}

bool _integer(dynamic v, int min, [int max = 8640000000000000]) =>
    v is int && v >= min && v <= max;
bool _hex(dynamic v) => v is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(v);
